import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("CompletionPushListener", () {
    test("does not subscribe before start", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.emitCompletion(rootSessionId: "session-a");

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.dispatcher.dispatchedRootSessionIds, isEmpty);
      });
    });

    test("forwards completion roots to the dispatcher after start", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.listener.start();
        harness.emitCompletion(rootSessionId: "session-a");

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.dispatcher.dispatchedRootSessionIds, equals(["session-a"]));
      });
    });

    test("start is idempotent", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.listener.start();
        harness.listener.start();
        harness.emitCompletion(rootSessionId: "session-a");

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.dispatcher.dispatchedRootSessionIds, equals(["session-a"]));
      });
    });

    test("dispose is safe before start", () async {
      final harness = _newHarness();

      await harness.listener.dispose();
      await harness.listener.dispose();

      expect(harness.dispatcher.dispatchedRootSessionIds, isEmpty);
    });

    test("dispose stops forwarding future completion roots", () async {
      await FakeAsync().run((async) async {
        final harness = _newHarness();

        harness.listener.start();
        harness.emitCompletion(rootSessionId: "session-a");

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.dispatcher.dispatchedRootSessionIds, equals(["session-a"]));

        await harness.listener.dispose();
        harness.emitCompletion(rootSessionId: "session-b");

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.dispatcher.dispatchedRootSessionIds, equals(["session-a"]));
      });
    });
  });
}

class _Harness {
  final PushSessionStateTracker tracker;
  final CompletionNotifier notifier;
  final CompletionPushListener listener;
  final _FakePushDispatcher dispatcher;

  _Harness({
    required this.tracker,
    required this.notifier,
    required this.listener,
    required this.dispatcher,
  });

  void emitCompletion({required String rootSessionId}) {
    tracker.handleEvent(
      SesoriSseEvent.sessionCreated(info: _session(id: rootSessionId)),
    );
    tracker.handleEvent(
      SesoriSseEvent.sessionUpdated(
        info: _session(id: rootSessionId, title: "Session $rootSessionId"),
      ),
    );
    _dispatch(
      SesoriSseEvent.sessionStatus(
        sessionID: rootSessionId,
        status: const SessionStatus.busy(),
      ),
    );
    _dispatch(
      SesoriSseEvent.sessionStatus(
        sessionID: rootSessionId,
        status: const SessionStatus.idle(),
      ),
    );
  }

  void _dispatch(SesoriSseEvent event) {
    tracker.handleEvent(event);
    notifier.handleEvent(event);
  }
}

_Harness _newHarness() {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final notifier = CompletionNotifier(
    tracker: tracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final dispatcher = _FakePushDispatcher();
  final listener = CompletionPushListener(
    completionNotifier: notifier,
    dispatcher: dispatcher,
  );
  return _Harness(
    tracker: tracker,
    notifier: notifier,
    listener: listener,
    dispatcher: dispatcher,
  );
}

class _FakePushDispatcher implements PushDispatcher {
  final List<String> dispatchedRootSessionIds = [];

  @override
  PushMaintenanceTelemetrySnapshot? get lastMaintenanceTelemetry => null;

  @override
  void dispatchCompletionForRoot({required String rootSessionId}) {
    dispatchedRootSessionIds.add(rootSessionId);
  }

  @override
  Future<void> dispose() async {}

  @override
  void handleSseEvent(SesoriSseEvent event) {}

  @override
  void markSessionAborted(String sessionId) {}

  @override
  void reset() {}

  @override
  void runMaintenancePass() {}
}

Session _session({
  required String id,
  String projectID = "project-a",
  String directory = "/tmp/project",
  String? parentID,
  String? title,
}) {
  return Session(
    id: id,
    projectID: projectID,
    directory: directory,
    parentID: parentID,
    title: title,
    time: null,
    summary: null,
    pullRequest: null,
  );
}
