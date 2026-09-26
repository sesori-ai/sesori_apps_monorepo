import "package:opencode_plugin/src/v2/models/openapi/form_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_request.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_info.g.dart";
import "package:opencode_plugin/src/v2/models/v2_agent_names.dart";
import "package:opencode_plugin/src/v2/models/v2_event.g.dart";
import "package:opencode_plugin/src/v2/models/v2_message_filter.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_activity_tracker.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_repository.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:opencode_plugin/src/v2/services/opencode_v2_service.dart";
import "package:opencode_plugin/src/v2/sse/v2_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

import "support/v2_fixtures.dart";

const project = "/fixture/project";
const worktree = "/fixture/worktree";
const names = V2AgentNames(namesById: {"build": "Build"});
const models = V2ModelMapper(pluginId: "fixture-plugin");
const messages = V2MessageMapper();
final root = models.mapSessionMetadata(session: SessionInfo.fromJson(v2SessionFixture), projectId: project);
final child = root.copyWith(id: "child", parentID: root.id, directory: worktree);
final permission = PermissionRequest.fromJson(const <String, dynamic>{
  "id": "permission",
  "sessionID": "child",
  "action": "shell",
  "resources": <String>["pwd"],
});
final form = FormInfo.fromJson(const <String, dynamic>{
  "id": "form",
  "sessionID": "child",
  "fields": <Object>[
    <String, dynamic>{"type": "boolean", "key": "flag"},
  ],
});
final assistant = messages.mapMessage(
  sessionId: "child",
  agentNames: names,
  message: SessionMessageInfo.fromJson(const <String, dynamic>{
    "id": "m",
    "type": "assistant",
    "agent": "build",
    "model": <String, String>{"id": "m", "providerID": "p"},
    "time": <String, int>{"created": 1, "completed": 2},
    "content": <Object>[
      <String, dynamic>{"type": "text", "text": "Unrelated snapshot text"},
      <String, dynamic>{
        "type": "tool",
        "id": "tool",
        "name": "shell",
        "time": <String, int>{"created": 1},
        "state": <String, dynamic>{
          "status": "completed",
          "input": <String, String>{"command": "pwd"},
          "content": <Object>[
            <String, String>{"type": "text", "text": "Fixture output"},
          ],
        },
      },
    ],
  }),
)!;

V2EventEnvelope frame({required String type, required Map<String, dynamic> data}) => V2EventEnvelope.fromJson(
  <String, dynamic>{
    "id": "evt_fixture",
    "created": 42,
    "type": type,
    "data": data,
    "location": <String, String>{"directory": "/fixture/envelope"},
  },
);

void main() {
  late OpenCodeV2ActivityTracker tracker;
  late FakeRepository repository;
  late OpenCodeV2Service service;
  setUp(() {
    tracker = OpenCodeV2ActivityTracker();
    repository = FakeRepository();
    service = OpenCodeV2Service(
      repository: repository,
      tracker: tracker,
      mapper: const V2EventMapper(modelMapper: models, messageMapper: messages),
    );
  });

  void seed() => tracker.seed(sessions: [root, child], activeSessionIds: {}, permissions: [], forms: []);

  group("standalone tracker", () {
    test("requires a complete baseline, then follows native execution and retry transitions", () {
      expect(tracker.workState, PluginWorkState.unknown);
      seed();
      expect(tracker.workState, PluginWorkState.idle);
      final started = frame(type: "session.execution.started", data: {"sessionID": "child"}).data;
      expect(tracker.apply(event: started), isTrue);
      expect(tracker.apply(event: started), isFalse);
      expect(tracker.workState, PluginWorkState.busy);
      tracker.apply(
        event: frame(
          type: "session.retry.scheduled",
          data: {
            "sessionID": "child",
            "assistantMessageID": "m",
            "attempt": 2,
            "at": 90,
            "error": {"type": "fixture", "message": "Retry fixture"},
          },
        ).data,
      );
      expect(tracker.status(sessionId: "child"), isA<PluginSessionStatusRetry>());
      tracker.apply(event: started);
      expect(tracker.status(sessionId: "child"), const PluginSessionStatus.busy());
      for (final reason in ["shutdown", "future-reason"]) {
        tracker.apply(
          event: frame(type: "session.execution.interrupted", data: {"sessionID": "child", "reason": reason}).data,
        );
        expect(tracker.workState, PluginWorkState.busy);
      }
      tracker.apply(
        event: frame(type: "session.execution.interrupted", data: {"sessionID": "child", "reason": "user"}).data,
      );
      expect(tracker.workState, PluginWorkState.idle);
    });

    test("retains native pending constraints and clears replies without inventing activity", () {
      seed();
      tracker.apply(
        event: frame(type: "permission.asked", data: permission.toJson()).data,
      );
      final created = frame(type: "form.created", data: {"form": form.toJson()}).data as V2FormCreated;
      tracker.apply(event: created);
      expect(tracker.forms.single, same(created.form));
      expect(tracker.permissions.single.resources, ["pwd"]);
      expect(tracker.status(sessionId: "child"), isNull);
      expect(tracker.rootSessionId(sessionId: "child"), root.id);
      expect(tracker.rootSessionId(sessionId: "missing"), isNull);
      expect(tracker.workState, PluginWorkState.busy);
      tracker.apply(
        event: frame(
          type: "permission.replied",
          data: {
            "sessionID": "child",
            "requestID": "permission",
            "reply": "once",
          },
        ).data,
      );
      expect(tracker.workState, PluginWorkState.busy);
      tracker.apply(
        event: frame(
          type: "form.replied",
          data: {
            "sessionID": "child",
            "id": "form",
            "answer": <String, dynamic>{},
          },
        ).data,
      );
      expect(tracker.workState, PluginWorkState.idle);
      tracker.apply(event: created);
      tracker.apply(
        event: frame(type: "form.cancelled", data: {"sessionID": "child", "id": "form"}).data,
      );
      expect(tracker.forms, isEmpty);
    });

    test("deletion removes only the named session's state; reset also revokes baseline trust", () {
      tracker.seed(sessions: [root, child], activeSessionIds: {"child"}, permissions: [permission], forms: [form]);
      tracker.apply(
        event: frame(type: "session.deleted", data: {"sessionID": "child"}).data,
      );
      expect(tracker.session(sessionId: root.id), root);
      expect(tracker.session(sessionId: "child"), isNull);
      expect(tracker.workingSessionIds, isEmpty);
      expect(tracker.workState, PluginWorkState.idle);
      tracker.reset();
      expect(tracker.session(sessionId: root.id), isNull);
      expect(tracker.workState, PluginWorkState.unknown);
    });
  });

  test("cold start and reconnect use global activity and unique session directories", () async {
    repository.sessions.add(child.copyWith(id: "sibling"));
    repository.active = {"child"};
    repository.permissions = [permission];
    await service.coldStart();
    expect(
      repository.calls,
      containsAll([
        "metadata",
        "active",
        "permissions:$project",
        "permissions:$worktree",
        "forms:$project",
        "forms:$worktree",
      ]),
    );
    expect(repository.calls.where((call) => call == "permissions:$worktree"), hasLength(1));
    final summary = service.buildSummary().single;
    expect(summary.id, project);
    expect(
      summary.activeSessions.single,
      PluginActiveSession(
        id: root.id,
        mainAgentRunning: false,
        awaitingInput: true,
        isRetrying: false,
        childSessionIds: ["child"],
      ),
    );
    repository.active = {};
    repository.permissions = [];
    await service.coldStart();
    expect(service.workState, PluginWorkState.idle);
    expect(service.buildSummary(), isEmpty);
  });

  test("failed refresh retains useful state but cannot claim a trusted baseline", () async {
    repository.active = {"child"};
    await service.coldStart();
    final previous = service.buildSummary();
    final failure = StateError("Fixture pending-input failure");
    repository.pendingFailure = failure;
    repository.active = {};
    await expectLater(service.coldStart(), throwsA(same(failure)));
    expect(service.workState, PluginWorkState.unknown);
    expect(service.buildSummary(), previous);
    repository.pendingFailure = null;
    await service.coldStart();
    expect(service.workState, PluginWorkState.idle);
    service.reset();
    expect(service.workState, PluginWorkState.unknown);
  });

  test("input-only children surface under an idle root with their native ownership", () async {
    await service.coldStart();
    final events = await service.handleEvent(
      envelope: frame(type: "form.created", data: {"form": form.toJson()}),
    );
    final asked = events.whereType<BridgeSseQuestionAsked>().single;
    expect(asked.sessionID, "child");
    expect(asked.displaySessionId, root.id);
    expect(service.buildSummary().single.activeSessions.single.awaitingInput, isTrue);
    expect(service.buildSummary().single.activeSessions.single.mainAgentRunning, isFalse);
    expect(events.whereType<BridgeSseProjectUpdated>(), hasLength(1));
    await service.handleEvent(
      envelope: frame(type: "form.cancelled", data: {"sessionID": "child", "id": "form"}),
    );
    expect(service.buildSummary(), isEmpty);
  });

  test("session lifecycle enriches created/renamed rows and deletes from retained metadata", () async {
    await service.coldStart();
    final fresh = child.copyWith(id: "fresh");
    repository.sessions.add(fresh);
    final created = await service.handleEvent(
      envelope: frame(
        type: "session.created",
        data: {
          "sessionID": "fresh",
          "projectID": "native",
          "location": {"directory": worktree},
          "slug": "fresh",
          "version": "2.0.16",
        },
      ),
    );
    expect(created.whereType<BridgeSseSessionCreated>().single.info["projectID"], project);
    repository.sessions[2] = fresh.copyWith(title: "Renamed");
    await service.handleEvent(
      envelope: frame(type: "session.renamed", data: {"sessionID": "fresh", "title": "Renamed"}),
    );
    repository.calls.clear();
    repository.sessions.removeLast();
    final deleted = await service.handleEvent(
      envelope: frame(type: "session.deleted", data: {"sessionID": "fresh"}),
    );
    expect(deleted.whereType<BridgeSseSessionDeleted>().single.info["title"], "Renamed");
    expect(repository.calls, isEmpty);
    expect(tracker.session(sessionId: "fresh"), isNull);
  });

  test("known text deltas need no I/O; assistant headers use the session's actual directory", () async {
    await service.coldStart();
    repository.calls.clear();
    final delta = await service.handleEvent(
      envelope: frame(
        type: "session.text.delta",
        data: {
          "sessionID": "child",
          "assistantMessageID": "m",
          "ordinal": 2,
          "delta": "Fixture",
        },
      ),
    );
    expect((delta.single as BridgeSseMessagePartDelta).partID, "m:2");
    expect(repository.calls, isEmpty);
    final started = await service.handleEvent(
      envelope: frame(
        type: "session.step.started",
        data: {
          "sessionID": "child",
          "assistantMessageID": "m",
          "agent": "build",
          "started": 10,
          "model": {"id": "m", "providerID": "p"},
        },
      ),
    );
    expect((started.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant).agent, "Build");
    expect(repository.calls, ["agents:$worktree"]);
    expect(service.buildSummary().single.activeSessions.single.childSessionIds, ["child"]);
  });

  test("metadata failures do not suppress a native permission request", () async {
    repository.sessions = [];
    await service.coldStart();
    repository.metadataFailure = StateError("Fixture metadata failure");
    final events = await service.handleEvent(
      envelope: frame(type: "permission.asked", data: permission.toJson()),
    );
    expect(events.whereType<BridgeSsePermissionAsked>().single.displaySessionId, isNull);
    expect(tracker.permissions.single.id, "permission");
    expect(service.workState, PluginWorkState.busy);
  });

  test("tool and assistant snapshot hydration never replays unrelated text", () async {
    await service.coldStart();
    repository.calls.clear();
    repository.message = assistant;
    final tool = await service.handleEvent(
      envelope: frame(
        type: "session.tool.progress",
        data: {
          "sessionID": "child",
          "assistantMessageID": "m",
          "id": "tool",
          "metadata": <String, dynamic>{},
        },
      ),
    );
    expect((tool.single as BridgeSseMessagePartUpdated).part.id, "tool");
    final ended = await service.handleEvent(
      envelope: frame(
        type: "session.step.failed",
        data: {
          "sessionID": "child",
          "assistantMessageID": "m",
          "error": {"type": "fixture", "message": "Fixture failure"},
        },
      ),
    );
    expect(ended.whereType<BridgeSseMessagePartUpdated>(), isEmpty);
    expect(ended.whereType<BridgeSseMessageUpdated>().single.info.id, "m");
    expect(ended.whereType<BridgeSseMessagePartRemoved>().single.partID, "m:retry");
    expect(repository.calls, ["message:child/m:$worktree", "message:child/m:$worktree"]);
  });

  test("execution and compaction terminal events request only their newest message type", () async {
    repository.active = {"child"};
    repository.latest[V2MessageFilter.assistant] = assistant;
    repository.latest[V2MessageFilter.compaction] = messages.mapMessage(
      sessionId: "child",
      agentNames: names,
      message: SessionMessageInfo.fromJson(const <String, dynamic>{
        "id": "msg_compaction",
        "type": "compaction",
        "status": "completed",
        "reason": "manual",
        "summary": "Fixture summary",
        "recent": "",
        "time": <String, int>{"created": 1},
      }),
    )!;
    await service.coldStart();
    repository.calls.clear();
    final settled = await service.handleEvent(
      envelope: frame(type: "session.execution.succeeded", data: {"sessionID": "child"}),
    );
    expect(settled.whereType<BridgeSseMessageUpdated>().single.info.id, "m");
    expect(service.workState, PluginWorkState.idle);
    final compacted = await service.handleEvent(
      envelope: frame(
        type: "session.compaction.ended",
        data: {
          "sessionID": "child",
          "text": "Fixture summary",
          "recent": "",
        },
      ),
    );
    expect(compacted.whereType<BridgeSseMessagePartUpdated>().single.part.id, "msg_compaction:0");
    expect(compacted.whereType<BridgeSseSessionCompacted>(), hasLength(1));
    expect(repository.calls, ["latest:assistant:$worktree", "latest:compaction:$worktree"]);
  });

  test("inbox delivery uses its message identity and absent control rows remain absent", () async {
    await service.coldStart();
    repository.calls.clear();
    final delivery = frame(type: "session.inbox.delivered", data: {"sessionID": "child", "inboxID": "msg_input"});
    expect(await service.handleEvent(envelope: delivery), isEmpty);
    repository.message = messages.mapMessage(
      sessionId: "child",
      agentNames: names,
      message: SessionMessageInfo.fromJson(const <String, dynamic>{
        "id": "msg_input",
        "type": "user",
        "text": "Fixture",
        "time": <String, int>{"created": 1},
      }),
    );
    final events = await service.handleEvent(envelope: delivery);
    expect(events.whereType<BridgeSseMessageUpdated>().single.info.id, "msg_input");
    expect(repository.calls, ["message:child/msg_input:$worktree", "message:child/msg_input:$worktree"]);
  });

  test("notice projection uses display names without fetching names for synthetic text", () async {
    await service.coldStart();
    repository.calls.clear();
    final notice = await service.handleEvent(
      envelope: frame(type: "session.agent.selected", data: {"sessionID": "child", "agent": "build"}),
    );
    expect(notice.whereType<BridgeSseMessagePartUpdated>().single.part.agentName, "Build");
    final synthetic = await service.handleEvent(
      envelope: frame(
        type: "session.synthetic",
        data: {
          "sessionID": "child",
          "text": "Internal fixture",
          "description": "Visible fixture",
        },
      ),
    );
    expect(synthetic.whereType<BridgeSseMessagePartUpdated>().single.part.text, "Visible fixture");
    expect(repository.calls, ["agents:$worktree"]);
  });

  test("a failed snapshot read preserves native settlement and later event processing", () async {
    repository.active = {"child"};
    await service.coldStart();
    repository.messageFailure = StateError("Fixture snapshot failure");
    final settled = await service.handleEvent(
      envelope: frame(type: "session.execution.succeeded", data: {"sessionID": "child"}),
    );
    expect(settled.whereType<BridgeSseSessionStatus>().single.status, const PluginSessionStatus.idle());
    expect(service.workState, PluginWorkState.idle);
    expect(
      await service.handleEvent(
        envelope: frame(type: "server.connected", data: {}),
      ),
      [const BridgeSseServerConnected()],
    );
  });
}

class FakeRepository() implements OpenCodeV2Repository {
  List<shared.Session> sessions = [root, child];
  Set<String> active = {};
  List<PermissionRequest> permissions = [];
  List<FormInfo> forms = [];
  final calls = <String>[];
  final latest = <V2MessageFilter, PluginMessageWithParts>{};
  PluginMessageWithParts? message;
  Object? pendingFailure;
  Object? metadataFailure;
  Object? messageFailure;

  @override
  Future<List<shared.Session>> getSessionMetadata() async {
    calls.add("metadata");
    return sessions;
  }

  @override
  Future<shared.Session> getSessionDetails({required String sessionId}) async {
    calls.add("session:$sessionId");
    if (metadataFailure case final failure?) throw failure;
    return sessions.firstWhere((session) => session.id == sessionId);
  }

  @override
  Future<Set<String>> getActiveSessionIds() async {
    calls.add("active");
    return active;
  }

  @override
  Future<List<PermissionRequest>> getPendingPermissions({required String directory}) async {
    calls.add("permissions:$directory");
    return permissions
        .where((request) => sessions.any((s) => s.id == request.sessionID && s.directory == directory))
        .toList();
  }

  @override
  Future<List<FormInfo>> getPendingForms({required String directory}) async {
    calls.add("forms:$directory");
    if (pendingFailure case final failure?) throw failure;
    return forms.where((form) => sessions.any((s) => s.id == form.sessionID && s.directory == directory)).toList();
  }

  @override
  Future<V2AgentNames> getAgentNames({required String directory}) async {
    calls.add("agents:$directory");
    return names;
  }

  @override
  Future<PluginMessageWithParts?> getMessage({
    required String sessionId,
    required String messageId,
    required String directory,
  }) async {
    calls.add("message:$sessionId/$messageId:$directory");
    if (messageFailure case final failure?) throw failure;
    return message;
  }

  @override
  Future<PluginMessageWithParts?> getLatestMessage({
    required String sessionId,
    required V2MessageFilter filter,
    required String directory,
  }) async {
    calls.add("latest:${filter.name}:$directory");
    if (messageFailure case final failure?) throw failure;
    return latest[filter];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
