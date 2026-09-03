import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/models/codex_rollout_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_config_reader.dart";
import "package:codex_plugin/src/codex_metadata_repository.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_model_repository.dart";
import "package:codex_plugin/src/repositories/codex_skill_repository.dart";
import "package:codex_plugin/src/repositories/codex_sub_agent_tracker.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("CodexCatalogRepository sub-agent rollouts", () {
    test("reads parentage from session_meta only for subagent rollouts", () {
      final repository = CodexCatalogRepository(rolloutApi: _HeaderRolloutApi());

      final records = {for (final record in repository.listSessionRecords()) record.id: record};

      expect(records["01a06259-6e4f-77f2-8bc7-000000000001"]?.parentId, isNull);
      expect(records["01a06259-6e4f-77f2-8bc7-000000000002"]?.parentId, "01a06259-6e4f-77f2-8bc7-000000000001");
      expect(records["01a06259-6e4f-77f2-8bc7-000000000003"]?.parentId, isNull, reason: "a plain fork is not a sub-agent");
    });

    test("lists roots only, keeps children discoverable, and resolves children by parent", () async {
      final repository = _StubCatalogRepository([
        _record(id: "root-1", cwd: "/repo/app", parentId: null),
        _record(id: "child-1", cwd: "/repo/app", parentId: "root-1"),
        _record(id: "child-2", cwd: "/repo/app", parentId: "root-1"),
        _record(id: "other-child", cwd: "/repo/app", parentId: "root-2"),
      ]);

      final page = await repository.getSessions(projectId: "/repo/app", start: null, limit: null);
      expect(page.map((session) => session.id), ["root-1"]);

      final all = await repository.listAllSessions(knownDirectories: const {});
      expect(all.map((session) => session.id), ["root-1", "child-1", "child-2", "other-child"]);
      expect(all.firstWhere((session) => session.id == "child-1").parentID, "root-1");

      final children = await repository.getChildSessions(sessionId: "root-1");
      expect(children.map((session) => session.id), ["child-1", "child-2"]);
      expect(children.every((session) => session.parentID == "root-1"), isTrue);
    });
  });

  group("CodexMessageRepository.trimForkedParentHistory", () {
    CodexRolloutLineDto meta(String id) => CodexRolloutLineDto.sessionMetadata(
      timestamp: null,
      payload: CodexRolloutSessionMetadataPayloadDto(
        id: id,
        cwd: "/repo/app",
        timestamp: null,
        modelProvider: null,
        cliVersion: null,
        parentThreadId: null,
        threadSource: null,
        agentNickname: null,
        agentPath: null,
      ),
    );
    CodexRolloutLineDto taskStarted(String turnId) => CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.taskStarted(turnId: turnId),
    );
    CodexRolloutLineDto taskComplete(String turnId) => CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.taskComplete(turnId: turnId, error: null),
    );
    const userMessage = CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.userMessage(message: "prompt"),
    );

    test("drops the copied parent prefix up to the child's own first turn", () {
      final lines = [
        meta("child-1"),
        meta("root-1"),
        taskStarted("parent-turn-1"),
        userMessage,
        taskComplete("parent-turn-1"),
        taskStarted("parent-turn-2"),
        userMessage,
        taskStarted("child-turn-1"),
        userMessage,
        taskComplete("child-turn-1"),
      ];

      final trimmed = CodexMessageRepository.trimForkedParentHistory(lines: lines);

      expect(trimmed, [lines[0], ...lines.sublist(7)]);
    });

    test("leaves rollouts without a copied prefix untouched", () {
      final own = [meta("root-1"), taskStarted("turn-1"), userMessage, taskComplete("turn-1")];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: own), same(own));

      final unresolved = [meta("child-1"), meta("root-1"), taskStarted("parent-turn-1"), userMessage];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: unresolved), same(unresolved));
    });
  });

  group("CodexSessionService sub-agent threads", () {
    test("resolves a child from thread/read with the parent's directory and nickname title", () async {
      final threadRepository = _ReadingThreadRepository(
        read: const CodexThreadRecord(
          id: "child-1",
          name: null,
          directory: "/repo/app",
          createdAt: 10,
          updatedAt: 20,
          model: "gpt-5.6",
          modelProvider: "openai",
          parentId: "root-1",
          agentNickname: "Raman",
        ),
      );
      final service = _newService(threadRepository: threadRepository);

      final child = await service.resolveSubAgentThread(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/parent",
        agentPath: "/root/sleeper",
      );

      expect(threadRepository.readThreadIds, ["child-1"]);
      expect(child.parentId, "root-1");
      expect(child.name, "Raman");
      expect(child.directory, "/repo/parent");
      expect(child.model, "gpt-5.6");
      expect(child.createdAt, 10);
    });

    test("falls back to the activity item when thread/read fails", () async {
      final service = _newService(
        threadRepository: _ReadingThreadRepository(
          read: null,
          error: const CodexThreadRequestException(operation: "thread/read", message: "boom"),
        ),
      );

      final child = await service.resolveSubAgentThread(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/parent",
        agentPath: "/root/sleeper",
      );

      expect(child.parentId, "root-1");
      expect(child.name, "/root/sleeper");
      expect(child.directory, "/repo/parent");
      expect(child.agentNickname, isNull);
    });

    test("merges persisted children with live children not yet on disk", () async {
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null),
        catalogRepository: _StubCatalogRepository([
          _record(id: "root-1", cwd: "/repo/app", parentId: null),
          _record(id: "child-1", cwd: "/repo/app", parentId: "root-1"),
        ]),
      );
      final tracker = CodexSubAgentTracker();
      tracker.record(child: _liveChild(id: "child-1", parentId: "root-1"));
      tracker.record(child: _liveChild(id: "child-2", parentId: "root-1"));

      final children = await service.getChildSessions(
        sessionId: "root-1",
        liveChildren: tracker.childrenOf(parentId: "root-1"),
      );

      expect(children.map((session) => session.id), ["child-1", "child-2"]);
      expect(children.last.parentID, "root-1");
      expect(children.last.directory, "/repo/app");
      expect(children.last.title, "Hooke");
    });
  });

  group("CodexSubAgentTracker", () {
    test("rolls nested children up to the root and forgets them with it", () {
      final tracker = CodexSubAgentTracker();
      expect(tracker.record(child: _liveChild(id: "child-1", parentId: "root-1")), isTrue);
      expect(tracker.record(child: _liveChild(id: "child-1", parentId: "root-1")), isFalse);
      expect(tracker.record(child: _liveChild(id: "grandchild-1", parentId: "child-1")), isTrue);

      expect(tracker.rootOf(sessionId: "grandchild-1"), "root-1");
      expect(tracker.childrenOf(parentId: "root-1").map((child) => child.id), ["child-1"]);
      expect(tracker.childrenOf(parentId: "child-1").map((child) => child.id), ["grandchild-1"]);
      expect(tracker.isChild(sessionId: "root-1"), isFalse);

      tracker.setChildActive(childId: "root-1", active: true);
      tracker.setChildActive(childId: "grandchild-1", active: true);
      expect(tracker.busyChildIds(rootId: "root-1"), ["grandchild-1"]);

      tracker.forget(sessionId: "root-1");
      expect(tracker.busyChildIds(rootId: "root-1"), isEmpty);
      expect(tracker.isChild(sessionId: "grandchild-1"), isFalse);
    });

    test("defers a root's idle until its last busy descendant settles", () {
      final tracker = CodexSubAgentTracker();
      tracker.record(child: _liveChild(id: "child-1", parentId: "root-1"));
      tracker.record(child: _liveChild(id: "child-2", parentId: "root-1"));
      tracker.setChildActive(childId: "child-1", active: true);
      tracker.setChildActive(childId: "child-2", active: true);

      tracker.deferRootIdle(rootId: "root-1");
      expect(tracker.deferredRootIds, {"root-1"});
      tracker.setChildActive(childId: "child-1", active: false);
      expect(tracker.releaseRootIdleIfSettled(childId: "child-1"), isNull);
      tracker.setChildActive(childId: "child-2", active: false);
      expect(tracker.releaseRootIdleIfSettled(childId: "child-2"), "root-1");
      expect(tracker.releaseRootIdleIfSettled(childId: "child-2"), isNull);
      expect(tracker.deferredRootIds, isEmpty);

      tracker.deferRootIdle(rootId: "root-1");
      tracker.cancelDeferredRootIdle(rootId: "root-1");
      expect(tracker.deferredRootIds, isEmpty);
    });
  });
}

CodexThreadRecord _liveChild({required String id, required String parentId}) => CodexThreadRecord(
  id: id,
  name: "Hooke",
  directory: "/repo/app",
  createdAt: null,
  updatedAt: null,
  model: null,
  modelProvider: null,
  parentId: parentId,
  agentNickname: "Hooke",
);

CodexSessionRecord _record({required String id, required String? cwd, required String? parentId}) =>
    CodexSessionRecord(
      id: id,
      rolloutPath: "/rollouts/$id.jsonl",
      cwd: cwd,
      threadName: null,
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
      cliVersion: "0.148.0",
      modelProvider: "openai",
      model: null,
      parentId: parentId,
    );

CodexSessionService _newService({
  required CodexThreadRepository threadRepository,
  CodexCatalogRepository? catalogRepository,
}) {
  final rolloutApi = CodexRolloutApi(environment: const {});
  final service = CodexSessionService(
    catalogRepository: catalogRepository ?? CodexCatalogRepository(rolloutApi: rolloutApi),
    messageRepository: CodexMessageRepository(
      rolloutApi: rolloutApi,
      rolloutToolMapper: const CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper()),
      userContentMapper: const CodexUserContentMapper(),
    ),
    metadataRepository: CodexMetadataRepository(configReader: CodexConfigReader(environment: const {})),
    toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
    launchDirectory: "/repo/launch",
  );
  final api = CodexAppServerApi(client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"));
  service.attachAppServerRepositories(
    threadRepository: threadRepository,
    modelRepository: CodexModelRepository(appServerApi: api),
    skillRepository: CodexSkillRepository(appServerApi: api),
  );
  return service;
}

class _ReadingThreadRepository({required final CodexThreadRecord? read, final Object? error})
    extends CodexThreadRepository {
  this : super(appServerApi: CodexAppServerApi(client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0")));

  final List<String> readThreadIds = [];

  @override
  Future<CodexThreadRecord> readThread({required String threadId}) async {
    readThreadIds.add(threadId);
    final failure = error;
    if (failure != null) throw failure;
    final record = read;
    if (record == null) throw StateError("no read fixture");
    return record;
  }
}

class _StubCatalogRepository(final List<CodexSessionRecord> records) extends CodexCatalogRepository {
  this : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  Future<List<CodexSessionRecord>> listSessionRecordsInIsolate() async => records;
}

/// Three rollouts: a root, a `fork_turns` sub-agent child (with the copied
/// parent `session_meta` behind its own), and a plain fork of the root.
class _HeaderRolloutApi() extends CodexRolloutApi {
  this : super(environment: const {});

  static const _root = "/sessions/rollout-2026-09-02T16-40-23-01a06259-6e4f-77f2-8bc7-000000000001.jsonl";
  static const _child = "/sessions/rollout-2026-09-02T16-40-28-01a06259-6e4f-77f2-8bc7-000000000002.jsonl";
  static const _fork = "/sessions/rollout-2026-09-02T16-41-00-01a06259-6e4f-77f2-8bc7-000000000003.jsonl";

  @override
  List<String> listRolloutPaths() => const [_root, _child, _fork];

  @override
  List<CodexSessionIndexEntryDto> readSessionIndex() => const [];

  @override
  List<CodexRolloutLineDto> readHeader({required String rolloutPath}) {
    final meta = switch (rolloutPath) {
      _root => const CodexRolloutSessionMetadataPayloadDto(
        id: "01a06259-6e4f-77f2-8bc7-000000000001",
        cwd: "/repo/app",
        timestamp: "2026-09-02T16:40:23Z",
        modelProvider: "openai",
        cliVersion: "0.148.0",
        parentThreadId: null,
        threadSource: null,
        agentNickname: null,
        agentPath: null,
      ),
      _child => const CodexRolloutSessionMetadataPayloadDto(
        id: "01a06259-6e4f-77f2-8bc7-000000000002",
        cwd: "/repo/app",
        timestamp: "2026-09-02T16:40:28Z",
        modelProvider: "openai",
        cliVersion: "0.148.0",
        parentThreadId: "01a06259-6e4f-77f2-8bc7-000000000001",
        threadSource: CodexRolloutThreadSource.subagent,
        agentNickname: "Raman",
        agentPath: "/root/sleep_then_done",
      ),
      _ => const CodexRolloutSessionMetadataPayloadDto(
        id: "01a06259-6e4f-77f2-8bc7-000000000003",
        cwd: "/repo/app",
        timestamp: "2026-09-02T16:41:00Z",
        modelProvider: "openai",
        cliVersion: "0.148.0",
        parentThreadId: "01a06259-6e4f-77f2-8bc7-000000000001",
        threadSource: null,
        agentNickname: null,
        agentPath: null,
      ),
    };
    return [
      CodexRolloutLineDto.sessionMetadata(timestamp: meta.timestamp, payload: meta),
      if (rolloutPath != _root)
        const CodexRolloutLineDto.sessionMetadata(
          timestamp: "2026-09-02T16:40:23Z",
          payload: CodexRolloutSessionMetadataPayloadDto(
            id: "01a06259-6e4f-77f2-8bc7-000000000001",
            cwd: "/repo/app",
            timestamp: "2026-09-02T16:40:23Z",
            modelProvider: "openai",
            cliVersion: "0.148.0",
            parentThreadId: null,
            threadSource: null,
            agentNickname: null,
            agentPath: null,
          ),
        ),
    ];
  }
}
