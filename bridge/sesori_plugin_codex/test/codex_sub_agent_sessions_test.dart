import "dart:async";

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
import "package:codex_plugin/src/repositories/mappers/codex_session_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_session_record.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Session;
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("CodexSessionMapper", () {
    test("normalizes persisted child display metadata", () {
      CodexSessionRecord record({
        required String id,
        required String? cwd,
        required String? threadName,
        required String? agentNickname,
      }) => CodexSessionRecord(
        id: id,
        rolloutPath: "/rollouts/$id.jsonl",
        cwd: cwd,
        threadName: threadName,
        createdAt: null,
        updatedAt: null,
        cliVersion: null,
        modelProvider: null,
        model: null,
        agentNickname: agentNickname,
        parentId: "root-1",
      );
      const mapper = CodexSessionMapper();

      final normalized = mapper.mapPersistedThread(
        record: record(
          id: "child-1",
          cwd: " /repo/./app/ ",
          threadName: "  ",
          agentNickname: " Raman ",
        ),
      );
      final blank = mapper.mapPersistedThread(
        record: record(
          id: "child-2",
          cwd: "  ",
          threadName: " ",
          agentNickname: " ",
        ),
      );

      expect(normalized.name, "Raman");
      expect(normalized.agentNickname, "Raman");
      expect(normalized.directory, "/repo/app");
      expect(blank.name, isNull);
      expect(blank.directory, isNull);
    });
  });

  group("CodexCatalogRepository sub-agent rollouts", () {
    test("reads sub-agent parentage and nickname from session metadata", () async {
      final repository = CodexCatalogRepository(rolloutApi: _HeaderRolloutApi());

      final records = {for (final record in repository.listSessionRecords()) record.id: record};

      expect(records["01a06259-6e4f-77f2-8bc7-000000000001"]?.parentId, isNull);
      expect(records["01a06259-6e4f-77f2-8bc7-000000000002"]?.parentId, "01a06259-6e4f-77f2-8bc7-000000000001");
      expect(records["01a06259-6e4f-77f2-8bc7-000000000002"]?.agentNickname, "Raman");
      expect(
        records["01a06259-6e4f-77f2-8bc7-000000000003"]?.parentId,
        isNull,
        reason: "a plain fork is not a sub-agent",
      );
      final children = await repository.getChildSessions(
        sessionId: "01a06259-6e4f-77f2-8bc7-000000000001",
      );
      expect(children.single.title, "Raman");
    });

    test("lists roots only, keeps children discoverable, and resolves children by parent", () async {
      final repository = _StubCatalogRepository(
        records: [
          _record(id: "root-1", cwd: "/repo/app", parentId: null),
          _record(id: "child-1", cwd: "/repo/app", parentId: "root-1"),
          _record(id: "child-2", cwd: "/repo/app", parentId: "root-1"),
          _record(id: "other-child", cwd: "/repo/app", parentId: "root-2"),
        ],
      );

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

  test("CodexThreadRepository keeps ordinary live forks as roots", () {
    final api = CodexAppServerApi(client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"));
    final repository = CodexThreadRepository(appServerApi: api);

    final fork = repository.decodeStartedNotificationParams(
      params: const {
        "thread": {
          "id": "fork-1",
          "parentThreadId": "root-1",
          "threadSource": "fork",
        },
      },
    );
    final subAgent = repository.decodeStartedNotificationParams(
      params: const {
        "thread": {
          "id": "child-1",
          "parentThreadId": "root-1",
          "threadSource": "subAgent",
        },
      },
    );

    expect(fork?.parentId, isNull);
    expect(subAgent?.parentId, "root-1");
  });

  group("CodexMessageRepository.trimForkedParentHistory", () {
    CodexRolloutLineDto meta({required String id, required CodexRolloutThreadSource? source}) =>
        CodexRolloutLineDto.sessionMetadata(
          timestamp: null,
          payload: CodexRolloutSessionMetadataPayloadDto(
            id: id,
            cwd: "/repo/app",
            timestamp: null,
            modelProvider: null,
            cliVersion: null,
            parentThreadId: null,
            threadSource: source,
            agentNickname: null,
            agentPath: null,
          ),
        );
    CodexRolloutLineDto taskStarted({required String turnId}) => CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.taskStarted(turnId: turnId),
    );
    CodexRolloutLineDto taskComplete({required String turnId}) => CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.taskComplete(turnId: turnId, error: null),
    );
    const userMessage = CodexRolloutLineDto.eventMessage(
      timestamp: null,
      payload: CodexRolloutEventDto.userMessage(message: "prompt"),
    );

    test("drops the copied parent prefix up to the child's own first turn", () {
      final lines = [
        meta(id: "child-1", source: CodexRolloutThreadSource.subagent),
        meta(id: "root-1", source: null),
        taskStarted(turnId: "parent-turn-1"),
        userMessage,
        taskComplete(turnId: "parent-turn-1"),
        taskStarted(turnId: "parent-turn-2"),
        userMessage,
        taskStarted(turnId: "child-turn-1"),
        userMessage,
        taskComplete(turnId: "child-turn-1"),
      ];

      final trimmed = CodexMessageRepository.trimForkedParentHistory(lines: lines);

      expect(trimmed, [lines[0], ...lines.sublist(7)]);
    });

    test("leaves roots, plain forks, malformed headers, and unresolved copies untouched", () {
      final own = [
        meta(id: "root-1", source: null),
        taskStarted(turnId: "turn-1"),
        userMessage,
        taskComplete(turnId: "turn-1"),
      ];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: own), same(own));

      final plainFork = [
        meta(id: "fork-1", source: null),
        meta(id: "root-1", source: null),
        taskStarted(turnId: "parent-turn-1"),
        userMessage,
        taskStarted(turnId: "fork-turn-1"),
      ];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: plainFork), same(plainFork));

      final malformed = [
        userMessage,
        meta(id: "child-1", source: CodexRolloutThreadSource.subagent),
        meta(id: "root-1", source: null),
        taskStarted(turnId: "parent-turn-1"),
        taskStarted(turnId: "child-turn-1"),
      ];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: malformed), same(malformed));

      final unresolved = [
        meta(id: "child-1", source: CodexRolloutThreadSource.subagent),
        meta(id: "root-1", source: null),
        taskStarted(turnId: "parent-turn-1"),
        userMessage,
      ];
      expect(CodexMessageRepository.trimForkedParentHistory(lines: unresolved), same(unresolved));
    });
  });

  group("CodexSessionService sub-agent threads", () {
    test("resolves, records, and maps a child with the nickname preferred", () async {
      final threadRepository = _ReadingThreadRepository(
        error: null,
        read: const CodexThreadRecord(
          id: "child-1",
          name: "generic thread name",
          directory: "/repo/app",
          createdAt: 10,
          updatedAt: 20,
          model: "gpt-5.6",
          modelProvider: "openai",
          parentId: null,
          agentNickname: "Raman",
        ),
      );
      final service = _newService(
        threadRepository: threadRepository,
        catalogRepository: null,
        subAgentTracker: null,
      );

      final announcement = await service.handleSubAgentStarted(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/parent",
        agentPath: "/root/sleeper",
        status: const PluginSessionStatus.idle(),
      );

      expect(threadRepository.readThreadIds, ["child-1"]);
      final child = announcement!.child;
      expect(child.parentId, "root-1");
      expect(child.name, "Raman");
      expect(child.directory, "/repo/parent");
      expect(child.model, "gpt-5.6");
      expect(child.createdAt, 10);
      expect(announcement.status, isA<PluginSessionStatusBusy>());
      final created = announcement.events.whereType<BridgeSseSessionCreated>().single;
      final session = Session.fromJson(created.info);
      expect(session.parentID, "root-1");
      expect(session.title, "Raman");
      final announcedStatus = announcement.events.last as BridgeSseSessionStatus;
      expect(announcedStatus.status["type"], "busy");
      expect(
        await service.handleSubAgentStarted(
          childThreadId: "child-1",
          parentThreadId: "root-1",
          parentDirectory: "/repo/parent",
          agentPath: "/root/sleeper",
          status: const PluginSessionStatus.busy(),
        ),
        isNull,
      );
      expect(threadRepository.readThreadIds, ["child-1"]);
    });

    test("falls back to the activity item after any thread-read failure", () async {
      final service = _newService(
        threadRepository: _ReadingThreadRepository(
          read: null,
          error: TimeoutException("thread/read timed out"),
        ),
        catalogRepository: null,
        subAgentTracker: null,
      );

      final announcement = await service.handleSubAgentStarted(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/parent",
        agentPath: "/root/sleeper",
        status: const PluginSessionStatus.idle(),
      );

      final child = announcement!.child;
      expect(child.parentId, "root-1");
      expect(child.name, "/root/sleeper");
      expect(child.directory, "/repo/parent");
      expect(child.agentNickname, isNull);
      expect(announcement.status, isA<PluginSessionStatusBusy>());
    });

    test("suppresses in-flight and delayed announcements for a deleted child", () async {
      final threadRepository = _GatedThreadRepository();
      final service = _newService(
        threadRepository: threadRepository,
        catalogRepository: _StubCatalogRepository(records: const []),
        subAgentTracker: null,
      );
      final announcement = service.handleSubAgentStarted(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/app",
        agentPath: "worker",
        status: const PluginSessionStatus.idle(),
      );
      await threadRepository.readStarted.future;

      await service.deleteSessionSubtree(sessionIds: const ["child-1"]);
      threadRepository.complete(
        record: _liveChild(id: "child-1", parentId: "root-1"),
      );

      expect(await announcement, isNull);
      expect(
        await service.handleSubAgentStarted(
          childThreadId: "child-1",
          parentThreadId: "root-1",
          parentDirectory: "/repo/app",
          agentPath: "worker",
          status: const PluginSessionStatus.busy(),
        ),
        isNull,
      );
    });

    test("suppresses an in-flight announcement from a detached connection", () async {
      final threadRepository = _GatedThreadRepository();
      final service = _newService(
        threadRepository: threadRepository,
        catalogRepository: null,
        subAgentTracker: null,
      );
      final announcement = service.handleSubAgentStarted(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/app",
        agentPath: "worker",
        status: const PluginSessionStatus.idle(),
      );
      await threadRepository.readStarted.future;

      service.detachAppServerRepositories();
      threadRepository.complete(
        record: _liveChild(id: "child-1", parentId: "root-1"),
      );

      expect(await announcement, isNull);
    });

    test("merges persisted children with service-owned live children", () async {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "child-1", parentId: "root-1"),
      );
      tracker.record(
        child: _liveChild(id: "child-2", parentId: "root-1"),
      );
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null, error: null),
        catalogRepository: _StubCatalogRepository(
          records: [
            _record(id: "root-1", cwd: "/repo/app", parentId: null),
            _record(id: "child-1", cwd: "/repo/app", parentId: "root-1"),
          ],
        ),
        subAgentTracker: tracker,
      );

      final children = await service.getChildSessions(sessionId: "root-1");

      expect(children.map((session) => session.id), ["child-1", "child-2"]);
      expect(children.last.parentID, "root-1");
      expect(children.last.directory, "/repo/app");
      expect(children.last.title, "Hooke");
    });

    test("hydrates persisted ancestry and still announces its first live activity", () async {
      final service = _newService(
        threadRepository: _ReadingThreadRepository(
          read: _liveChild(id: "child-1", parentId: "root-1"),
          error: null,
        ),
        catalogRepository: _StubCatalogRepository(
          records: [
            _record(id: "grandchild-1", cwd: "/repo/app", parentId: "child-1"),
            _record(id: "child-1", cwd: "/repo/app", parentId: "root-1"),
            _record(id: "root-1", cwd: "/repo/app", parentId: null),
          ],
        ),
        subAgentTracker: null,
      );

      await service.hydratePersistedChildAncestry();

      expect(service.pendingInputScope(sessionId: "grandchild-1").displaySessionId, "root-1");
      expect(service.pendingInputScope(sessionId: "root-1").sourceSessionIds, [
        "root-1",
        "child-1",
        "grandchild-1",
      ]);

      final announcement = await service.handleSubAgentStarted(
        childThreadId: "child-1",
        parentThreadId: "root-1",
        parentDirectory: "/repo/app",
        agentPath: "worker",
        status: const PluginSessionStatus.idle(),
      );
      expect(announcement, isNotNull);
      expect(announcement!.status, isA<PluginSessionStatusBusy>());
      expect(
        await service.handleSubAgentStarted(
          childThreadId: "child-1",
          parentThreadId: "root-1",
          parentDirectory: "/repo/app",
          agentPath: "worker",
          status: const PluginSessionStatus.busy(),
        ),
        isNull,
      );
    });

    test("owns effective status, deferred idle, and descendant pending input", () {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "child-1", parentId: "root-1"),
      );
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null, error: null),
        catalogRepository: null,
        subAgentTracker: tracker,
      );
      service.observeSessionStatus(
        sessionId: "child-1",
        status: const PluginSessionStatus.busy(),
      );
      const ownStatuses = <String, PluginSessionStatus>{
        "child-1": PluginSessionStatus.busy(),
      };

      final effectiveStatuses = service.effectiveSessionStatuses(ownStatuses: ownStatuses);
      expect(effectiveStatuses["root-1"], isA<PluginSessionStatusBusy>());
      expect(effectiveStatuses["child-1"], isA<PluginSessionStatusBusy>());
      final summary = service.getActiveSessionsSummary(
        ownStatuses: ownStatuses,
        pendingInputSessionIds: const {"child-1"},
        projectIdBySession: const {"root-1": "/repo/app"},
      );
      final active = summary.single.activeSessions.single;
      expect(active.id, "root-1");
      expect(active.mainAgentRunning, isFalse);
      expect(active.awaitingInput, isTrue);
      expect(active.childSessionIds, ["child-1"]);
      final rootInputScope = service.pendingInputScope(sessionId: "root-1");
      expect(rootInputScope.displaySessionId, "root-1");
      expect(rootInputScope.sourceSessionIds, ["root-1", "child-1"]);
      final childInputScope = service.pendingInputScope(sessionId: "child-1");
      expect(childInputScope.displaySessionId, "root-1");
      expect(childInputScope.sourceSessionIds, ["child-1"]);

      final deferred = service.coordinateSessionEvents(
        sessionId: "root-1",
        sessionIsIdle: true,
        activityChanged: true,
        sessionClosed: false,
        events: [
          BridgeSseSessionStatus(
            sessionID: "root-1",
            status: const PluginSessionStatus.idle().toJson(),
          ),
          const BridgeSseSessionIdle(sessionID: "root-1"),
        ],
      );
      expect(deferred, [isA<BridgeSseProjectUpdated>()]);
      expect(service.deferredRootIds, {"root-1"});

      service.observeSessionStatus(
        sessionId: "child-1",
        status: const PluginSessionStatus.idle(),
      );
      final released = service.coordinateSessionEvents(
        sessionId: "child-1",
        sessionIsIdle: true,
        activityChanged: true,
        sessionClosed: false,
        events: [const BridgeSseSessionIdle(sessionID: "child-1")],
      );
      expect(released.map((event) => event.runtimeType), [
        BridgeSseSessionIdle,
        BridgeSseSessionStatus,
        BridgeSseSessionIdle,
        BridgeSseProjectUpdated,
      ]);
      expect(service.deferredRootIds, isEmpty);
    });

    test("includes a hydrated pending child when no live statuses exist", () {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "child-1", parentId: "root-1"),
      );
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null, error: null),
        catalogRepository: null,
        subAgentTracker: tracker,
      );

      final summary = service.getActiveSessionsSummary(
        ownStatuses: const {},
        pendingInputSessionIds: const {"child-1"},
        projectIdBySession: const {"root-1": "/repo/app"},
      );

      final active = summary.single.activeSessions.single;
      expect(active.id, "root-1");
      expect(active.mainAgentRunning, isFalse);
      expect(active.awaitingInput, isTrue);
      expect(active.childSessionIds, isEmpty);
    });

    test("idles an active child before releasing its root when the thread closes", () {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "child-1", parentId: "root-1"),
      );
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null, error: null),
        catalogRepository: null,
        subAgentTracker: tracker,
      );
      service.observeSessionStatus(
        sessionId: "child-1",
        status: const PluginSessionStatus.busy(),
      );
      service.coordinateSessionEvents(
        sessionId: "root-1",
        sessionIsIdle: true,
        activityChanged: true,
        sessionClosed: false,
        events: [const BridgeSseSessionIdle(sessionID: "root-1")],
      );
      service.observeSessionStatus(
        sessionId: "child-1",
        status: const PluginSessionStatus.idle(),
      );

      final closed = service.coordinateSessionEvents(
        sessionId: "child-1",
        sessionIsIdle: false,
        activityChanged: true,
        sessionClosed: true,
        events: const [],
      );

      expect(closed.map((event) => event.runtimeType), [
        BridgeSseSessionStatus,
        BridgeSseSessionStatus,
        BridgeSseSessionIdle,
        BridgeSseProjectUpdated,
      ]);
      expect((closed.first as BridgeSseSessionStatus).sessionID, "child-1");
      expect((closed[1] as BridgeSseSessionStatus).sessionID, "root-1");
      expect(service.deferredRootIds, isEmpty);
    });

    test("deletes persisted and live descendants child-first", () async {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "live-child", parentId: "root-1"),
      );
      tracker.record(
        child: _liveChild(id: "live-grandchild", parentId: "live-child"),
      );
      final catalog = _StubCatalogRepository(
        records: [
          _record(id: "root-1", cwd: "/repo/app", parentId: null),
          _record(id: "persisted-child", cwd: "/repo/app", parentId: "root-1"),
          _record(id: "persisted-grandchild", cwd: "/repo/app", parentId: "persisted-child"),
        ],
      );
      final service = _newService(
        threadRepository: _ReadingThreadRepository(read: null, error: null),
        catalogRepository: catalog,
        subAgentTracker: tracker,
      );

      final subtree = await service.getSessionSubtreeIds(sessionId: "root-1");
      expect(subtree.toSet(), {
        "root-1",
        "persisted-child",
        "persisted-grandchild",
        "live-child",
        "live-grandchild",
      });
      expect(await service.deleteSessionSubtree(sessionIds: subtree), isEmpty);
      expect(catalog.deletedSessionIds.toSet(), subtree.toSet());
      expect(catalog.deletedSessionIds.last, "root-1");
      expect(tracker.descendantsOf(parentId: "root-1"), isEmpty);
    });
  });

  group("CodexSubAgentTracker", () {
    test("rolls nested children up to the root and recursively forgets an intermediate child", () {
      final tracker = CodexSubAgentTracker();
      expect(
        tracker.record(
          child: _liveChild(id: "child-1", parentId: "root-1"),
        ),
        isTrue,
      );
      expect(
        tracker.record(
          child: _liveChild(id: "child-1", parentId: "root-1"),
        ),
        isFalse,
      );
      expect(
        tracker.record(
          child: _liveChild(id: "grandchild-1", parentId: "child-1"),
        ),
        isTrue,
      );

      expect(tracker.rootOf(sessionId: "grandchild-1"), "root-1");
      expect(tracker.childrenOf(parentId: "root-1").map((child) => child.id), ["child-1"]);
      expect(tracker.childrenOf(parentId: "child-1").map((child) => child.id), ["grandchild-1"]);
      expect(tracker.descendantsOf(parentId: "root-1").map((child) => child.id), ["child-1", "grandchild-1"]);
      expect(tracker.isChild(sessionId: "root-1"), isFalse);

      tracker.setChildActive(childId: "root-1", active: true);
      tracker.setChildActive(childId: "grandchild-1", active: true);
      expect(tracker.busyChildIds(rootId: "root-1"), ["grandchild-1"]);

      tracker.forget(sessionId: "child-1");
      expect(tracker.busyChildIds(rootId: "root-1"), isEmpty);
      expect(tracker.childrenOf(parentId: "root-1"), isEmpty);
      expect(tracker.isChild(sessionId: "child-1"), isFalse);
      expect(tracker.isChild(sessionId: "grandchild-1"), isFalse);
    });

    test("defers a root's idle until its last busy descendant settles", () {
      final tracker = CodexSubAgentTracker();
      tracker.record(
        child: _liveChild(id: "child-1", parentId: "root-1"),
      );
      tracker.record(
        child: _liveChild(id: "child-2", parentId: "root-1"),
      );
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

CodexSessionRecord _record({required String id, required String? cwd, required String? parentId}) => CodexSessionRecord(
  id: id,
  rolloutPath: "/rollouts/$id.jsonl",
  cwd: cwd,
  threadName: null,
  createdAt: DateTime.utc(2026, 9, 2),
  updatedAt: DateTime.utc(2026, 9, 2),
  cliVersion: "0.148.0",
  modelProvider: "openai",
  model: null,
  agentNickname: null,
  parentId: parentId,
);

CodexSessionService _newService({
  required CodexThreadRepository threadRepository,
  required CodexCatalogRepository? catalogRepository,
  required CodexSubAgentTracker? subAgentTracker,
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
    subAgentTracker: subAgentTracker ?? CodexSubAgentTracker(),
    sessionMapper: const CodexSessionMapper(),
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

class _ReadingThreadRepository({required final CodexThreadRecord? read, required final Object? error})
    extends CodexThreadRepository {
  this
    : super(
        appServerApi: CodexAppServerApi(client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0")),
      );

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

class _GatedThreadRepository() extends CodexThreadRepository {
  this
    : super(
        appServerApi: CodexAppServerApi(client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0")),
      );

  final Completer<void> readStarted = Completer<void>();
  final Completer<CodexThreadRecord> _response = Completer<CodexThreadRecord>();

  @override
  Future<CodexThreadRecord> readThread({required String threadId}) {
    if (!readStarted.isCompleted) readStarted.complete();
    return _response.future;
  }

  void complete({required CodexThreadRecord record}) => _response.complete(record);
}

class _StubCatalogRepository({required final List<CodexSessionRecord> records}) extends CodexCatalogRepository {
  this : super(rolloutApi: CodexRolloutApi(environment: const {}));

  final List<String> deletedSessionIds = [];

  @override
  Future<List<CodexSessionRecord>> listSessionRecordsInIsolate() async => records;

  @override
  bool deleteSession({required String sessionId}) {
    deletedSessionIds.add(sessionId);
    return true;
  }
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
