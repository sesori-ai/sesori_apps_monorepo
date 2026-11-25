import "package:clock/clock.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:sesori_tool_pr_monitor/src/api/gh_cli_exception.dart";
import "package:sesori_tool_pr_monitor/src/listeners/pull_request_poll_listener.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_watch_repository.dart";
import "package:sesori_tool_pr_monitor/src/services/models/pull_request_watch_results.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_watch_service.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";
import "../support/watch_fakes.dart";

class _Harness() {
  DateTime now = DateTime.utc(2026, 11, 25, 12);
  final MemoryStore store = MemoryStore();
  late final FakeHost host = FakeHost(records: store)
    ..addSession(sessionId: "s1")
    ..addSession(sessionId: "s2");
  final FakeSnapshots snapshots = FakeSnapshots();
  late PullRequestWatchService service = build();

  /// A fresh service over the same store, as after a bridge restart.
  PullRequestWatchService build() => PullRequestWatchService(
    snapshots: snapshots,
    actions: FakeActions(),
    watches: PullRequestWatchRepository(store: store),
    host: host,
    activity: activity,
    readiness: readiness,
    reports: reports,
    clock: Clock(() => now),
  );

  Future<void> watch({required String sessionId}) async {
    expect(await service.watch(sessionId: sessionId, target: target), isA<PullRequestWatchStarted>());
  }

  /// Moves time on by [after] and runs one poll tick.
  Future<void> poll({Duration after = const Duration(seconds: 61)}) async {
    now = now.add(after);
    await service.pollDue();
    await pumpEventQueue();
  }

  List<String> get sentTo => [for (final notice in host.sent) notice.sessionId];
}

final PullRequestSnapshot _withComment = emptySnapshot.copyWith(
  issueComments: [comment(id: "c1", author: "reviewer", at: "2026-11-25T12:00:30Z")],
  issueCommentsTotal: 1,
);

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
    h.snapshots.enqueue(emptySnapshot);
  });

  test("two sessions on one PR share each poll, and both get the report after the quiet window", () async {
    await h.watch(sessionId: "s1");
    await h.watch(sessionId: "s2");
    final watchFetches = h.snapshots.fetches.length;

    h.snapshots.enqueue(_withComment);
    await h.poll();
    expect(h.host.sent, isEmpty, reason: "the quiet window holds the report");
    await h.poll(after: const Duration(minutes: 2));

    expect(h.snapshots.fetches.length - watchFetches, 2, reason: "one fetch per poll, not per watch");
    expect(h.sentTo, ["s1", "s2"]);
    expect(h.host.sent.first.summary, "PR monitor: sesori/example#42 — 1 new comment");
    expect(h.host.sent.first.guidance, contains("1 new relevant since last flush"));
    expect(h.host.sent.first.timing, SesoriToolNoticeTiming.derived);

    await h.poll(after: const Duration(minutes: 3));
    expect(h.host.sent, hasLength(2), reason: "both baselines now cover the comment");
  });

  test("a session that fetched its own report is not sent the same activity", () async {
    await h.watch(sessionId: "s1");
    await h.watch(sessionId: "s2");
    h.snapshots.enqueue(_withComment);

    final fetched = await h.service.report(sessionId: "s1", target: target);
    expect((fetched as PullRequestReportFresh).report, contains("1 new relevant since last flush"));
    await h.poll(after: const Duration(minutes: 3));

    expect(h.sentTo, ["s2"]);
  });

  test("running CI holds a due report for 30 minutes, then it goes out with the forced CI line", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(
      _withComment.copyWith(
        checks: [check(name: "build", outcome: PullRequestCheckOutcome.pending)],
      ),
    );
    await h.poll();
    await h.poll(after: const Duration(minutes: 2));
    expect(h.host.sent, isEmpty);
    expect(h.service.statusOf(sessionId: "s1").watches.single.ciHold, isTrue);

    await h.poll(after: const Duration(minutes: 30));
    expect(h.host.sent.single.guidance, contains("- CI: running for 30m+ (in_progress: build)"));
  });

  test("a new CI failure and a merge report at once; the merge ends the watch", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(
      emptySnapshot.copyWith(
        checks: [check(name: "lint", outcome: PullRequestCheckOutcome.failure)],
      ),
    );
    await h.poll();
    expect(h.host.sent.single.summary, "PR monitor: sesori/example#42 — CI failing");

    h.snapshots.enqueue(emptySnapshot.copyWith(state: PullRequestState.merged));
    await h.poll();
    expect(h.host.sent.last.guidance, contains("- Monitor stopped: PR merged"));
    expect(h.store.sessionRecords["s1"], isEmpty);
    expect(h.service.statusOf(sessionId: "s1").watches, isEmpty);
  });

  test("a report whose watch ended while it waited is not sent, and a dropped one is sent again", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(_withComment);
    await h.poll();
    h.host.hold = true;
    await h.poll(after: const Duration(minutes: 2));
    expect(await h.service.unwatch(sessionId: "s1", target: target), isTrue);
    h.host.release();
    await pumpEventQueue();
    expect(h.host.outcomes, [SesoriToolNoticeOutcome.claimLost]);
    expect(h.store.sessionRecords["s1"], isEmpty);

    h.host.hold = false;
    await h.watch(sessionId: "s2");
    h.snapshots.enqueue(
      emptySnapshot.copyWith(
        issueComments: [comment(id: "c2", author: "r", at: "2026-11-25T13:00:00Z")],
      ),
    );
    await h.poll();
    h.host.forcedOutcome = SesoriToolNoticeOutcome.dropped;
    await h.poll(after: const Duration(minutes: 2));
    h.host.forcedOutcome = null;
    await h.poll();
    expect(h.sentTo, ["s2"]);
  });

  test("activity while a report waits for its session goes into the next report", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(_withComment);
    await h.poll();
    h.host.hold = true;
    await h.poll(after: const Duration(minutes: 2));
    h.snapshots.enqueue(
      _withComment.copyWith(
        issueComments: [
          ..._withComment.issueComments,
          comment(id: "c2", author: "r", at: "2026-11-25T12:04:00Z"),
        ],
        issueCommentsTotal: 2,
      ),
    );
    await h.poll();
    await h.poll(after: const Duration(minutes: 2));
    expect(h.host.outcomes, isEmpty, reason: "at most one delivery waits per watch");

    h.host.hold = false;
    h.host.release();
    await h.poll();
    expect(h.host.sent.map((notice) => notice.summary), [
      "PR monitor: sesori/example#42 — 1 new comment",
      "PR monitor: sesori/example#42 — 1 new comment",
    ]);
  });

  test("after a restart a merge reports at once and says it resumed", () async {
    await h.watch(sessionId: "s1");
    h.service = h.build();
    await h.service.resume();
    h.snapshots.enqueue(emptySnapshot.copyWith(state: PullRequestState.merged));
    await h.poll();

    final report = h.host.sent.single.guidance;
    expect(report, contains("- Resumed after the bridge restarted; this covers changes since the last report."));
    expect(report, contains("— MERGED"));
    expect(h.store.sessionRecords["s1"], isEmpty);
  });

  test("after a restart an unchanged PR stays quiet and a new comment reports after the quiet window", () async {
    await h.watch(sessionId: "s1");
    h.service = h.build();
    await h.service.resume();
    expect(h.service.statusOf(sessionId: "s1").watches, hasLength(1));
    await h.poll();
    await h.poll(after: const Duration(minutes: 3));
    expect(h.host.sent, isEmpty);

    h.service = h.build();
    await h.service.resume();
    h.snapshots.enqueue(_withComment);
    await h.poll();
    expect(h.host.sent, isEmpty);
    await h.poll(after: const Duration(minutes: 2));
    expect(h.host.sent.single.guidance, contains("1 new relevant since last flush"));
    expect(h.host.sent.single.guidance, contains("- Resumed after the bridge restarted"));
    expect(h.host.sent.single.guidance, contains("- Startup/restart assessment:"));
  });

  test("archived and deleted sessions lose their watches", () async {
    await h.watch(sessionId: "s1");
    await h.watch(sessionId: "s2");
    h.host.knownSessions["s1"] = const SesoriToolSession(
      rootSessionId: "s1",
      workingDirectory: "/repo",
      archived: true,
    );
    h.host.knownSessions.remove("s2");
    final fetches = h.snapshots.fetches.length;
    await h.poll();

    expect(h.store.sessionRecords["s1"], isEmpty);
    expect(h.service.statusOf(sessionId: "s2").watches, isEmpty);
    expect(h.snapshots.fetches, hasLength(fetches), reason: "a PR nobody watches is not polled");
  });

  test("ten consecutive poll failures stop the watch and tell the session", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(const GhCliCommandFailedException(exitCode: 1, httpStatus: 502, detail: "HTTP 502"));
    for (var poll = 0; poll < 9; poll++) {
      await h.poll();
    }
    expect(h.host.sent, isEmpty);
    expect(h.service.statusOf(sessionId: "s1").watches.single.consecutiveFailures, 9);

    await h.poll();
    expect(h.host.sent.single.summary, "PR monitor: sesori/example#42 — monitor stopped");
    expect(h.host.sent.single.guidance, contains("Monitor stopped: 10 consecutive poll failures."));
    expect(h.store.sessionRecords["s1"], isEmpty);
  });

  test("a PR that is no longer found stops its watch at once", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(const GhCliNotFoundException(detail: "Could not resolve to a PullRequest"));
    await h.poll();

    expect(h.host.sent.single.guidance, contains("Monitor stopped: PR not found (deleted or inaccessible)."));
    expect(h.store.sessionRecords["s1"], isEmpty);
  });

  test("an idle PR gets a reminder after the turn, repeating one delay later", () async {
    await h.watch(sessionId: "s1");
    await h.poll(after: const Duration(minutes: 25));
    expect(h.host.sent.single.timing, SesoriToolNoticeTiming.afterTurn);
    expect(h.host.sent.single.summary, "PR monitor: sesori/example#42 — idle reminder");

    await h.poll();
    expect(h.host.sent, hasLength(1));
    await h.poll(after: const Duration(minutes: 25));
    expect(h.host.sent, hasLength(2));
  });

  test("a merged PR cannot be watched, and a second watch from a session reports the first", () async {
    await h.watch(sessionId: "s1");
    expect(await h.service.watch(sessionId: "s1", target: target), isA<PullRequestAlreadyWatched>());

    h.snapshots.enqueue(emptySnapshot.copyWith(state: PullRequestState.merged));
    expect(await h.service.watch(sessionId: "s2", target: target), isA<PullRequestAlreadyEnded>());
    expect(h.store.sessionRecords["s2"], isNull);
  });

  test("the poll listener skips ticks while the group is off", () async {
    await h.watch(sessionId: "s1");
    h
      ..now = h.now.add(const Duration(minutes: 5))
      ..host.enabled = false;
    final fetches = h.snapshots.fetches.length;
    final listener = PullRequestPollListener(service: h.service, host: h.host)..start();
    await pumpEventQueue();
    await listener.dispose();
    expect(h.snapshots.fetches, hasLength(fetches));

    h.host.enabled = true;
    final enabled = PullRequestPollListener(service: h.service, host: h.host)..start();
    await pumpEventQueue();
    await enabled.dispose();
    expect(h.snapshots.fetches, hasLength(fetches + 1));
  });
}
