import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("CompletionNotifier", () {
    test("idle after busy emits completion after debounce", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 499));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["session-a"]));
      });
    });

    test("question asked during debounce cancels callback", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        harness.dispatch(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "session-a",
            questions: [QuestionInfo(header: "Prompt", question: "Continue?")],
          ),
        );

        async.elapse(const Duration(milliseconds: 800));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("permission asked during debounce cancels callback", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        harness.dispatch(
          const SesoriSseEvent.permissionAsked(
            requestID: "perm-1",
            sessionID: "session-a",
            tool: "bash",
            description: "Run command",
          ),
        );

        async.elapse(const Duration(milliseconds: 800));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("busy during debounce cancels pending callback", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );

        async.elapse(const Duration(milliseconds: 800));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("session deleted during debounce cancels pending callback", () {
      fakeAsync((async) {
        final harness = _newHarness();
        final session = _session(id: "session-a");

        harness.dispatch(SesoriSseEvent.sessionCreated(info: session));
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        harness.dispatch(SesoriSseEvent.sessionDeleted(info: session));

        async.elapse(const Duration(milliseconds: 800));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("question replied cancels any pending completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "session-a",
            questions: [QuestionInfo(header: "Prompt", question: "Proceed?")],
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "session-a"),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("question rejected cancels any pending completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "session-a",
            questions: [QuestionInfo(header: "Prompt", question: "Proceed?")],
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.questionRejected(requestID: "q-1", sessionID: "session-a"),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("permission replied cancels any pending completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.permissionAsked(
            requestID: "perm-1",
            sessionID: "session-a",
            tool: "bash",
            description: "Run command",
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.permissionReplied(requestID: "perm-1", sessionID: "s1", reply: "allow"),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("parent+child completion fires only when whole group is idle", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(SesoriSseEvent.sessionCreated(info: _session(id: "parent")));
        harness.dispatch(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "parent"),
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["parent"]));
      });
    });

    test("rapid busy-idle-busy-idle emits one callback", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["session-a"]));
      });
    });

    test("duplicate idle without new busy does not emit duplicate callback", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["session-a"]));

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.completedRoots, equals(["session-a"]));
      });
    });

    test("pruned-root cleanup cancels pending debounce timers", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        harness.notifier.cleanupPrunedRootSubtree(
          rootSessionId: "session-a",
          prunedSessionIds: const ["session-a"],
        );

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("pruned-root cleanup clears retained root state for reused IDs", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["session-a"]));

        harness.notifier.markSessionAborted("session-a");
        harness.notifier.cleanupPrunedRootSubtree(
          rootSessionId: "session-a",
          prunedSessionIds: const ["session-a"],
        );

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.completedRoots, equals(["session-a", "session-a"]));
      });
    });

    test("pruned-root cleanup removes pruned permission mappings idempotently", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
        harness.dispatch(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.permissionAsked(
            requestID: "perm-old",
            sessionID: "child",
            tool: "bash",
            description: "Run command",
          ),
        );

        harness.tracker.pruneRootSubtree(rootSessionId: "root");
        harness.notifier.cleanupPrunedRootSubtree(
          rootSessionId: "root",
          prunedSessionIds: const ["root", "child"],
        );
        harness.notifier.cleanupPrunedRootSubtree(
          rootSessionId: "root",
          prunedSessionIds: const ["root", "child"],
        );

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.notifier.handleEvent(
          const SesoriSseEvent.permissionReplied(
            requestID: "perm-old",
            sessionID: "root",
            reply: "allow",
          ),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["root"]));
      });
    });

    test("reset clears timers and internal state", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        harness.notifier.reset();

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("dispose cancels timers", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        harness.notifier.dispose();

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(harness.completedRoots, isEmpty);
      });
    });

    test("projects summary during debounce redirects child completion to root", () {
      fakeAsync((async) {
        final harness = _newHarness();

        // Status events arrive without sessionCreated (e.g., after bridge restart).
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        // At this point, "child" has a debounce timer thinking it is a root.

        // projects.summary arrives within debounce window and establishes link.
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.projectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "project-a",
                activeSessions: [
                  ActiveSession(id: "root", mainAgentRunning: false, childSessionIds: ["child"]),
                ],
              ),
            ],
          ),
        );

        // Allow both the original debounce and the rescheduled one to fire.
        async.elapse(const Duration(milliseconds: 1000));
        async.flushMicrotasks();

        // Should emit "root", not "child".
        expect(harness.completedRoots, equals(["root"]));
      });
    });

    test("late summary after debounce fires does not prevent child notification", () {
      fakeAsync((async) {
        final harness = _newHarness();

        // Status events arrive without parent links.
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );

        // Debounce fires BEFORE summary arrives — child notifies as root.
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, contains("child"));

        // Summary arrives too late to prevent the child notification.
        harness.dispatch(
          const SesoriSseEvent.projectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "project-a",
                activeSessions: [
                  ActiveSession(id: "root", mainAgentRunning: false, childSessionIds: ["child"]),
                ],
              ),
            ],
          ),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        // Known tradeoff: both "root" and "child" emitted because the link
        // was established after the child's debounce already fired.
        expect(harness.completedRoots, containsAll(["root", "child"]));
      });
    });

    test("multiple children redirecting to same root produce single notification", () {
      fakeAsync((async) {
        final harness = _newHarness();

        // Three sessions known only via status events.
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child-1", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child-2", status: SessionStatus.busy()),
        );

        // All go idle — each schedules its own debounce as "root".
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child-1", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child-2", status: SessionStatus.idle()),
        );

        // Summary establishes links before debounce fires.
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.projectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "project-a",
                activeSessions: [
                  ActiveSession(id: "root", mainAgentRunning: false, childSessionIds: ["child-1", "child-2"]),
                ],
              ),
            ],
          ),
        );

        // Allow all debounce timers + rescheduled timers to fire.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Only one notification for the true root.
        expect(harness.completedRoots, equals(["root"]));
      });
    });

    test("multi-level chain via summary redirects grandchild to root", () {
      fakeAsync((async) {
        final harness = _newHarness();

        // Three-level hierarchy known only via status events.
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.busy()),
        );

        // All go idle.
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.idle()),
        );

        // Summary establishes both levels during debounce.
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.dispatch(
          const SesoriSseEvent.projectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "project-a",
                activeSessions: [
                  ActiveSession(id: "root", mainAgentRunning: false, childSessionIds: ["child"]),
                  ActiveSession(id: "child", mainAgentRunning: false, childSessionIds: ["grandchild"]),
                ],
              ),
            ],
          ),
        );

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Only the top root emits, not child or grandchild.
        expect(harness.completedRoots, equals(["root"]));
      });
    });

    test("completion stream emits root session ID for child events", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatch(SesoriSseEvent.sessionCreated(info: _session(id: "parent")));
        harness.dispatch(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "parent"),
          ),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.idle()),
        );
        harness.dispatch(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.completedRoots, equals(["parent"]));
      });
    });
  });
}

class _Harness {
  final PushSessionStateTracker tracker;
  final CompletionNotifier notifier;
  final List<String> completedRoots;

  _Harness({
    required this.tracker,
    required this.notifier,
    required this.completedRoots,
  });

  void dispatch(SesoriSseEvent event) {
    tracker.handleEvent(event);
    notifier.handleEvent(event);
  }
}

_Harness _newHarness() {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final completedRoots = <String>[];
  final notifier = CompletionNotifier(
    tracker: tracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  notifier.completions.listen(completedRoots.add);
  return _Harness(tracker: tracker, notifier: notifier, completedRoots: completedRoots);
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
