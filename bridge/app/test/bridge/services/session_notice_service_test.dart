import "dart:async";

import "package:sesori_bridge/src/repositories/models/normalized_bridge_event.dart";
import "package:sesori_bridge/src/repositories/models/session_notice.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/session_quietness.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/trackers/prompt_stamp.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/services/session_notice_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show parseSessionNotice;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginBusyPromptHandling;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _notice = SessionNotice(
  summary: "You allowed pausing “Nightly”.",
  guidance: "The change is saved.",
  pageRequestId: null,
);

void main() {
  late _Sessions sessions;
  late _Prompts prompts;
  late _Events events;
  late _Plugins plugins;
  late _Tasks tasks;
  late SessionNoticeService service;

  setUp(() {
    sessions = _Sessions();
    prompts = _Prompts();
    events = _Events();
    plugins = _Plugins();
    tasks = _Tasks();
    final operations = SessionOperationDispatcher(sessionRepository: sessions);
    addTearDown(operations.dispose);
    service = SessionNoticeService(
      sessions: sessions,
      operations: operations,
      prompts: prompts,
      events: events,
      plugins: plugins,
      tasks: tasks,
    );
  });

  test("a quiet session gets the notice at once, as a bridge notice prompt", () async {
    await service.deliver(sessionId: "s1", notice: _notice);

    final sent = prompts.sent.single;
    expect(sent.mark, isA<PromptStampNotice>());
    expect(sent.text, contains("You allowed pausing “Nightly”."));
    expect(sent.text, contains("The change is saved."));
    expect(parseSessionNotice(text: sent.text)?.pageRequestId, isNull);
  });

  test("a page notice carries its page reference into the frame", () async {
    await service.deliver(
      sessionId: "s1",
      notice: const SessionNotice(summary: "You answered “Palette”.", guidance: "Fixture", pageRequestId: "sesori-page-1"),
    );

    expect(
      parseSessionNotice(text: prompts.sent.single.text),
      (summary: "You answered “Palette”.", pageRequestId: "sesori-page-1"),
    );
  });

  test("a steering harness takes the notice into the running turn", () async {
    sessions.quietness = SessionQuietness.working;

    await service.deliver(sessionId: "s1", notice: _notice);

    expect(prompts.sent, hasLength(1));
  });

  test("a harness that stops its turn gets the notice once the session is quiet", () async {
    plugins.handling = PluginBusyPromptHandling.stopTurn;
    sessions.quietness = SessionQuietness.working;
    var done = false;
    final delivery = service.deliver(sessionId: "s1", notice: _notice).then((_) => done = true);
    await pumpEventQueue();
    expect(prompts.sent, isEmpty);

    // A new turn started before the lane re-checked: it waits for that one.
    events.idle(sessionId: "s1");
    await pumpEventQueue();
    expect(prompts.sent, isEmpty);
    expect(done, isFalse);

    sessions.quietness = SessionQuietness.quiet;
    events.idle(sessionId: "other");
    await pumpEventQueue();
    expect(prompts.sent, isEmpty);

    events.idle(sessionId: "s1");
    await delivery;
    expect(prompts.sent, hasLength(1));
  });

  test("a source error while the notice waits neither escapes nor drops it", () async {
    plugins.handling = PluginBusyPromptHandling.stopTurn;
    sessions.quietness = SessionQuietness.working;
    final delivery = service.deliver(sessionId: "s1", notice: _notice);
    await pumpEventQueue();

    events.fail();
    await pumpEventQueue();
    sessions.quietness = SessionQuietness.quiet;
    events.idle(sessionId: "s1");
    await delivery;
    expect(prompts.sent, hasLength(1));
  });

  test("a scheduled run's session hears the notice only after its turn, even on a steering harness", () async {
    tasks.runSessionIds = {"s1"};
    sessions.quietness = SessionQuietness.working;
    final delivery = service.deliver(sessionId: "s1", notice: _notice);
    await pumpEventQueue();
    expect(prompts.sent, isEmpty);

    sessions.quietness = SessionQuietness.quiet;
    events.idle(sessionId: "s1");
    await delivery;
    expect(prompts.sent, hasLength(1));
  });

  test("a session waiting on the user gets the notice after it is answered", () async {
    sessions.quietness = SessionQuietness.awaitingUser;
    final delivery = service.deliver(sessionId: "s1", notice: _notice);
    await pumpEventQueue();
    expect(prompts.sent, isEmpty);

    sessions.quietness = SessionQuietness.quiet;
    events.idle(sessionId: "s1");
    await delivery;
    expect(prompts.sent, hasLength(1));
  });

  test("an archived or deleted session gets nothing", () async {
    sessions.archived = true;
    await service.deliver(sessionId: "s1", notice: _notice);
    sessions.archived = false;
    await service.deliver(sessionId: "missing", notice: _notice);

    expect(prompts.sent, isEmpty);
  });

  test("a session archived while the notice waits gets nothing", () async {
    sessions.quietness = SessionQuietness.awaitingUser;
    final delivery = service.deliver(sessionId: "s1", notice: _notice);
    await pumpEventQueue();

    sessions.archived = true;
    events.idle(sessionId: "s1");
    await delivery;
    expect(prompts.sent, isEmpty);
  });

  test("a waiting notice is dropped without throwing when the bridge shuts down", () async {
    sessions.quietness = SessionQuietness.awaitingUser;
    final delivery = service.deliver(sessionId: "s1", notice: _notice);
    await pumpEventQueue();

    await events.close();
    await delivery;
    expect(prompts.sent, isEmpty);
  });
}

final class _Sessions() implements SessionRepository {
  SessionQuietness quietness = SessionQuietness.quiet;
  bool archived = false;

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => sessionId != "s1"
      ? null
      : Session(
          id: sessionId,
          pluginId: "claude",
          projectID: "/fixture",
          directory: "/fixture",
          parentID: null,
          title: null,
          time: SessionTime(created: 1, updated: 2, archived: archived ? 3 : null),
          promptDefaults: null,
          branchName: null,
          lastUserActivityAt: null,
          autoContinuation: null,
          approvalOverride: null,
          pinOrder: null,
          scheduledTask: null,
          interruption: null,
          forkedFrom: null,
        );

  @override
  Future<SessionQuietness> getSessionQuietness({required String sessionId}) async => quietness;

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: "claude");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Prompts() implements SessionPromptService {
  final List<({String text, BridgePromptMark? mark})> sent = [];

  @override
  Future<void> sendWithDefaults({
    required String sessionId,
    required SessionPromptDefaults? defaults,
    required Future<void> Function(PromptSettings settings) send,
  }) => send(SessionPromptService.settingsFrom(defaults: defaults));

  @override
  Future<void> sendPromptAlreadyReserved({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required CommandSource? commandSource,
    required BridgePromptMark? mark,
    required String? runContext,
  }) async => sent.add((
    text: [
      for (final part in parts)
        if (part case PromptPartText(:final text)) text,
    ].join(),
    mark: mark,
  ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Events() implements SessionEventDispatcher {
  final StreamController<NormalizedSourcedBridgeEvent> _controller = StreamController.broadcast();

  void fail() => _controller.addError(StateError("a source failed"));

  void idle({required String sessionId}) => _controller.add((
    pluginId: "claude",
    generation: 1,
    event: NormalizedStatusEvent(sessionId: sessionId, status: const SessionStatus.idle()),
    allowDuringStop: false,
    terminalHandoffConsumed: null,
  ));

  Future<void> close() => _controller.close();

  @override
  Stream<NormalizedSourcedBridgeEvent> get events => _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Plugins() implements PluginLifecycleService {
  PluginBusyPromptHandling handling = PluginBusyPromptHandling.steer;

  @override
  PluginBusyPromptHandling? busyPromptHandling({required String pluginId}) => handling;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Tasks() implements ScheduledTaskRepository {
  Set<String> runSessionIds = {};

  @override
  Future<Map<String, SessionScheduledTaskMark>> marksOfSessions({required Set<String> sessionIds}) async => {
    for (final sessionId in sessionIds.intersection(runSessionIds))
      sessionId: const SessionScheduledTaskMark(taskId: "task-1", name: "Nightly", kind: ScheduledTaskKind.recurring),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
