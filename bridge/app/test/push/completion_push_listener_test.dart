import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
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

    test("handleSseEvent updates tracker/notifier state and forwards immediate sends", () {
      final harness = _newHarness();

      harness.listener.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", title: "Session A"),
        ),
      );
      harness.listener.handleSseEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "Prompt", question: "Continue?")],
        ),
      );

      expect(harness.tracker.getSessionTitle("session-a"), equals("Session A"));
      expect(harness.dispatcher.immediateEvents, hasLength(2));
    });

    test("markSessionAborted updates abort suppression state", () {
      final harness = _newHarness();

      harness.listener.handleSseEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      harness.listener.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      harness.listener.markSessionAborted("child");

      expect(harness.notifier.abortedRootCount, equals(1));
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
    listener.handleSseEvent(
      SesoriSseEvent.sessionCreated(info: _session(id: rootSessionId)),
    );
    listener.handleSseEvent(
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
    listener.handleSseEvent(event);
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
    tracker: tracker,
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
  final List<SesoriSseEvent> immediateEvents = [];

  @override
  void dispatchCompletionForRoot({required String rootSessionId}) {
    dispatchedRootSessionIds.add(rootSessionId);
  }

  @override
  void dispatchImmediateIfApplicable(SesoriSseEvent event) {
    immediateEvents.add(event);
  }

  @override
  Future<void> dispose() async {}
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
