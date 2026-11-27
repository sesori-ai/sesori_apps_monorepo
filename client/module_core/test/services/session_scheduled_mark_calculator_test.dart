import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const calculator = SessionScheduledMarkCalculator();
  const task = SessionScheduledTaskMark(taskId: "t-1", name: "Nightly triage", kind: ScheduledTaskKind.recurring);

  SessionScheduledMark markOf({required SessionArming arming, required SessionScheduledTaskMark? task}) =>
      calculator.mark(
        session: testSession(id: "s-1").copyWith(arming: arming, scheduledTask: task),
      );

  test("an armed session names what wakes it and when, task or not", () {
    for (final mark in [task, null]) {
      expect(
        markOf(
          arming: const SessionArming.armed(name: "Check CI", nextAt: 9000),
          task: mark,
        ),
        const SessionScheduledMark.armed(name: "Check CI", nextAt: 9000),
      );
    }
  });

  test("a task's session that nothing wakes again says where it came from", () {
    expect(
      markOf(arming: const SessionArming.notArmed(), task: task),
      const SessionScheduledMark.fromTask(name: "Nightly triage"),
    );
  });

  test("an older bridge keeps the plain task mark", () {
    expect(
      markOf(arming: const SessionArming.unreported(), task: task),
      const SessionScheduledMark.legacyTask(task: task),
    );
  });

  group("watched pull requests", () {
    SessionPullRequestWatch watch({required int number, required PullRequestWatchStatus status}) =>
        SessionPullRequestWatch(
          repository: "octo/repo",
          number: number,
          title: "PR $number",
          url: "https://github.com/octo/repo/pull/$number",
          autoMerge: false,
          status: status,
        );

    SessionScheduledMark watchingMark({
      required SessionArming arming,
      required List<SessionPullRequestWatch> watches,
    }) => calculator.mark(
      session: testSession(id: "s-1").copyWith(arming: arming, scheduledTask: task, pullRequestWatches: watches),
    );

    test("lead with the most urgent PR, To merge first, and count the others", () {
      final waiting = watch(number: 3, status: const PullRequestWatchStatus.waiting());
      final ready = watch(number: 9, status: const PullRequestWatchStatus.ready());
      final agentOnIt = watch(
        number: 12,
        status: const PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.ciFailing]),
      );
      final toMerge = watch(
        number: 14,
        status: const PullRequestWatchStatus.needsYou(reasons: [PullRequestWatchNeed.readyWithoutAutoMerge]),
      );
      final merged = watch(number: 1, status: const PullRequestWatchStatus.merged(mergedAt: 5));

      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [waiting, merged, agentOnIt, toMerge, ready]),
        SessionScheduledMark.watchingPullRequests(lead: toMerge, others: 4),
      );
      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [waiting, merged, agentOnIt, ready]),
        SessionScheduledMark.watchingPullRequests(lead: agentOnIt, others: 3),
      );
      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [merged, ready, waiting]),
        SessionScheduledMark.watchingPullRequests(lead: waiting, others: 2),
      );
      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [merged, ready]),
        SessionScheduledMark.watchingPullRequests(lead: ready, others: 1),
      );
    });

    test("ties go to the lower number", () {
      final later = watch(number: 20, status: const PullRequestWatchStatus.waiting());
      final earlier = watch(number: 4, status: const PullRequestWatchStatus.waiting());

      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [later, earlier]),
        SessionScheduledMark.watchingPullRequests(lead: earlier, others: 1),
      );
    });

    test("a timed wake-up wins over watches, and watches win over the task mark", () {
      final waiting = watch(number: 3, status: const PullRequestWatchStatus.waiting());

      expect(
        watchingMark(
          arming: const SessionArming.armed(name: "Check CI", nextAt: 9000),
          watches: [waiting],
        ),
        const SessionScheduledMark.armed(name: "Check CI", nextAt: 9000),
      );
      expect(
        watchingMark(arming: const SessionArming.notArmed(), watches: [waiting]),
        SessionScheduledMark.watchingPullRequests(lead: waiting, others: 0),
      );
    });
  });

  test("a session the user started, that nothing wakes, has no mark", () {
    for (final arming in const [SessionArming.notArmed(), SessionArming.unreported()]) {
      expect(markOf(arming: arming, task: null), const SessionScheduledMark.none());
    }
  });
}
