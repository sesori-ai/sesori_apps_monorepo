import "package:clock/clock.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:sesori_tool_pr_monitor/src/listeners/pull_request_poll_listener.dart";
import "package:sesori_tool_pr_monitor/src/models/gh_cli_exception.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_merge_outcome.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_monitor_config.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_watch_repository.dart";
import "package:sesori_tool_pr_monitor/src/services/models/pull_request_config_change.dart";
import "package:sesori_tool_pr_monitor/src/services/models/pull_request_merge_state.dart";
import "package:sesori_tool_pr_monitor/src/services/models/pull_request_watch_results.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_config_description_builder.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_merge_service.dart";
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
  final FakeActions actions = FakeActions();
  late PullRequestWatchService service = build();

  /// A fresh service over the same store, as after a bridge restart.
  PullRequestWatchService build() => PullRequestWatchService(
    snapshots: snapshots,
    actions: actions,
    watches: PullRequestWatchRepository(store: store),
    host: host,
    activity: activity,
    readiness: readiness,
    reports: reports,
    feedback: feedback,
    merges: PullRequestMergeService(actions: actions, readiness: readiness),
    configDescriptions: const PullRequestConfigDescriptionBuilder(),
    clock: Clock(() => now),
  );

  Future<void> watch({required String sessionId, bool autoMerge = false}) async {
    expect(
      await service.watch(sessionId: sessionId, target: target, requestedAutoMerge: autoMerge),
      isA<PullRequestWatchStarted>(),
    );
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

  test("a report queued before a get_pr_report is not sent over the newer report", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(_withComment);
    await h.poll();
    h.host.hold = true;
    await h.poll(after: const Duration(minutes: 2));
    expect(await h.service.report(sessionId: "s1", target: target), isA<PullRequestReportFresh>());
    h.host.release();
    await pumpEventQueue();
    expect(h.host.outcomes, [SesoriToolNoticeOutcome.claimLost]);

    h.host.hold = false;
    await h.poll(after: const Duration(minutes: 3));
    expect(h.host.sent, isEmpty, reason: "the fetched report already covered the comment");
  });

  test("checks that appear after the watch and pass are reported", () async {
    await h.watch(sessionId: "s1");
    h.snapshots.enqueue(
      emptySnapshot.copyWith(
        checks: [check(name: "build", outcome: PullRequestCheckOutcome.success)],
      ),
    );
    await h.poll();
    await h.poll(after: const Duration(minutes: 2));
    expect(h.host.sent.single.summary, "PR monitor: sesori/example#42 — CI passing");
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
    expect(
      await h.service.watch(sessionId: "s1", target: target, requestedAutoMerge: false),
      isA<PullRequestAlreadyWatched>(),
    );

    h.snapshots.enqueue(emptySnapshot.copyWith(state: PullRequestState.merged));
    expect(
      await h.service.watch(sessionId: "s2", target: target, requestedAutoMerge: false),
      isA<PullRequestAlreadyEnded>(),
    );
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

  group("readiness and auto-merge", () {
    final passing = emptySnapshot.copyWith(
      checks: [check(name: "build", outcome: PullRequestCheckOutcome.success)],
    );
    final ready = passing.copyWith(labels: [agentReadyLabel]);

    /// CI concludes green, and the quiet report that follows is due.
    Future<void> settle({required PullRequestSnapshot snapshot}) async {
      h.snapshots.enqueue(snapshot);
      await h.poll();
      await h.poll(after: const Duration(minutes: 2));
    }

    test("a quiet eligible report labels the PR, and with auto-merge on makes one merge at the head", () async {
      await h.watch(sessionId: "s1", autoMerge: true);
      await settle(snapshot: passing);

      expect(h.actions.calls, ["add label", "merge head-1"]);
      final report = h.host.sent.single.guidance;
      expect(report, contains('- Ready: YES — label "agent-ready" is present.'));
      expect(
        report,
        contains(
          "- Auto-merge succeeded: squash-merged sesori/example#42 at head-1 using only the PR title. "
          'Label "automatically-merged" added.',
        ),
      );

      h.snapshots.enqueue(ready.copyWith(state: PullRequestState.merged));
      await h.poll();
      expect(h.host.sent, hasLength(2));
      expect(h.host.sent.last.guidance, isNot(contains("Auto-merge succeeded")), reason: "the notice shows once");
      expect(h.store.sessionRecords["s1"], isEmpty);
    });

    test("a get_pr_report that shows the merge result is not followed by a report repeating it", () async {
      await h.watch(sessionId: "s1", autoMerge: true);
      h.actions.mergeOutcome = const PullRequestMergeRejected(reason: "Required review is missing", cause: null);
      h.snapshots.enqueue(passing);
      await h.poll();

      final fetched = await h.service.report(sessionId: "s1", target: target);
      expect((fetched as PullRequestReportFresh).report, contains("Auto-merge failed after the ready label was added"));
      h.snapshots.enqueue(ready);
      await h.poll(after: const Duration(minutes: 2));

      expect(h.host.sent, isEmpty);
      expect(h.actions.calls, ["add label", "merge head-1"]);
    });

    test("without auto-merge the label hands the PR to a human: no merge and no idle reminder", () async {
      await h.watch(sessionId: "s1");
      await settle(snapshot: passing);
      expect(h.actions.calls, ["add label"]);

      h.snapshots.enqueue(ready);
      await h.poll(after: const Duration(minutes: 40));
      expect(h.host.sent, hasLength(1));
    });

    test("auto-merge applies to the PR when any watcher has it on", () async {
      await h.watch(sessionId: "s1");
      await h.watch(sessionId: "s2", autoMerge: true);
      expect(
        await h.service.setAutoMerge(sessionId: "s2", target: target, enabled: true),
        isA<PullRequestAutoMergeUnchanged>(),
      );
      await settle(snapshot: passing);

      expect(h.actions.calls, ["add label", "merge head-1"]);
      expect(h.sentTo, ["s1", "s2"]);
      for (final notice in h.host.sent) {
        expect(notice.guidance, contains("- Auto-merge: ENABLED"));
        expect(notice.guidance, contains("- Auto-merge succeeded"));
      }
      expect([for (final watch in h.store.sessionRecords.values) watch.values.single["autoMerge"]], [false, true]);
    });

    test("one watcher turning auto-merge off leaves it on while another has it", () async {
      await h.watch(sessionId: "s1", autoMerge: true);
      await h.watch(sessionId: "s2", autoMerge: true);

      expect(
        await h.service.setAutoMerge(sessionId: "s1", target: target, enabled: false),
        isA<PullRequestAutoMergeSet>().having((result) => result.effective, "effective", isTrue),
      );
      expect(h.service.statusOf(sessionId: "s1").watches.single.autoMerge, isFalse);
      expect(
        await h.service.setAutoMerge(sessionId: "s2", target: target, enabled: false),
        isA<PullRequestAutoMergeSet>().having((result) => result.effective, "effective", isFalse),
      );
      expect(
        await h.service.setAutoMerge(sessionId: "gone", target: target, enabled: true),
        isA<PullRequestAutoMergeNotWatched>(),
      );
    });

    test("turning auto-merge on removes the ready label and waits for new activity to label again", () async {
      await h.watch(sessionId: "s1");
      h.snapshots.enqueue(ready);
      await h.poll();

      expect(
        await h.service.setAutoMerge(sessionId: "s1", target: target, enabled: true),
        isA<PullRequestAutoMergeSet>().having((result) => result.readyLabelRemoved, "readyLabelRemoved", isTrue),
      );
      h.snapshots.enqueue(passing);
      await h.poll(after: const Duration(minutes: 2));
      expect(h.actions.calls, ["remove label"], reason: "the removed handoff waits for a fresh judgment");
      expect(h.host.sent.single.guidance, contains("- Ready: NO"));

      await settle(snapshot: passing.copyWith(headSha: "head-2"));
      expect(h.actions.calls, ["remove label", "add label", "merge head-2"]);
    });

    test("a push withdraws the ready label at once, and a later quiet report adds it back", () async {
      await h.watch(sessionId: "s1");
      await settle(snapshot: ready);
      expect(h.host.sent, hasLength(1));

      h.snapshots.enqueue(
        ready.copyWith(
          headSha: "head-2",
          checks: [check(name: "build", outcome: PullRequestCheckOutcome.pending)],
        ),
      );
      await h.poll();
      expect(h.actions.calls, ["remove label"]);
      expect(h.host.sent, hasLength(2), reason: "the withdrawal reports without a quiet window");
      expect(h.host.sent.last.guidance, contains("- Ready: NO"));

      await settle(snapshot: passing.copyWith(headSha: "head-2"));
      expect(h.actions.calls, ["remove label", "add label"]);
      expect(h.host.sent.last.guidance, contains("- Ready: YES"));
    });

    test("a failed label change reports at once, retries each poll, and reports again once it works", () async {
      await h.watch(sessionId: "s1");
      h.actions.labelFailure = const GhCliCommandFailedException(exitCode: 1, httpStatus: 403, detail: "forbidden");
      await settle(snapshot: passing);
      expect(
        h.host.sent.single.guidance,
        contains('- Readiness automation failed: could not add label "agent-ready": GitHub CLI (gh) failed: forbidden'),
      );

      await h.poll();
      expect(h.actions.calls, ["add label", "add label"]);
      expect(h.host.sent, hasLength(1), reason: "the same failure is not reported twice");

      h.actions.labelFailure = null;
      await h.poll();
      expect(h.host.sent, hasLength(2));
      expect(h.host.sent.last.guidance, contains("- Ready: YES"));
      expect(h.host.sent.last.guidance, isNot(contains("Readiness automation failed")));
    });

    test("mark_pr_ready with auto-merge on merges at the last polled head and returns the outcome", () async {
      await h.watch(sessionId: "s1", autoMerge: true);
      h.actions.mergeOutcome = const PullRequestMergeRejected(reason: "Required review is missing", cause: null);

      expect(
        await h.service.setReady(sessionId: "s1", target: target, ready: true),
        isA<PullRequestMarkedReady>().having(
          (change) => change.mergeAttempt,
          "mergeAttempt",
          isA<PullRequestMergeAttempt>()
              .having((attempt) => attempt.headSha, "headSha", "head-1")
              .having((attempt) => attempt.outcome, "outcome", isA<PullRequestMergeRejected>()),
        ),
      );
      expect(h.actions.calls, ["add label", "merge head-1"]);
      expect(h.service.statusOf(sessionId: "s1").watches.single.ready, isTrue);
    });

    test("mark_pr_ready on a PR nobody watches only changes the label", () async {
      expect(
        await h.service.setReady(sessionId: "s1", target: target, ready: true),
        isA<PullRequestMarkedReady>().having((change) => change.mergeAttempt, "mergeAttempt", isNull),
      );
      h.actions.carriesReadyLabel = false;
      expect(
        await h.service.setReady(sessionId: "s1", target: target, ready: false),
        isA<PullRequestUnmarkedReady>().having((change) => change.wasCarried, "wasCarried", isFalse),
      );
      expect(h.actions.calls, ["add label", "remove label"]);
      expect(h.snapshots.fetches, isEmpty);
    });

    test("unmarking a PR that still qualifies labels it again after the next quiet report", () async {
      await h.watch(sessionId: "s1");
      await h.service.setReady(sessionId: "s1", target: target, ready: true);
      await h.service.setReady(sessionId: "s1", target: target, ready: false);
      await h.poll();
      expect(h.actions.calls, ["add label", "remove label"]);

      await h.poll(after: const Duration(minutes: 2));
      expect(h.actions.calls, ["add label", "remove label", "add label"]);
      expect(h.host.sent.single.guidance, contains("- Ready: YES"));
    });
  });

  group("configure", () {
    const repositoryOn = PullRequestRepositoryAutoMerge(repositoryKey: "sesori/example", enabled: true);

    Future<PullRequestConfigureResult> configure({
      String sessionId = "s1",
      PullRequestAutoMergeDefaultChange? autoMerge,
      int? quiet,
      int? ciWait,
      int? idle,
    }) => h.service.configure(
      sessionId: sessionId,
      change: PullRequestConfigChange(
        autoMerge: autoMerge,
        quietMinutes: quiet,
        ciWaitMinutes: ciWait,
        idleReminderMinutes: idle,
      ),
    );

    PullRequestMonitorConfig config() => h.service.statusOf(sessionId: "s1").config;

    test("narrowing and timings apply at once with no card, and are loaded after a restart", () async {
      expect(
        await configure(autoMerge: const PullRequestGlobalAutoMerge(enabled: false), quiet: 5, idle: 0),
        isA<PullRequestConfigApplied>(),
      );
      expect(h.host.asked, isEmpty);

      h.service = h.build();
      await h.service.resume();
      expect(config(), PullRequestMonitorConfig.defaults.copyWith(quietMinutes: 5, idleReminderMinutes: 0));
    });

    test("new timings apply to an existing watch from its next poll", () async {
      await h.watch(sessionId: "s1");
      await configure(quiet: 5, idle: 0);

      h.snapshots.enqueue(_withComment);
      await h.poll();
      await h.poll(after: const Duration(minutes: 2));
      expect(h.host.sent, isEmpty, reason: "the quiet window is now 5 minutes");
      await h.poll(after: const Duration(minutes: 3));
      expect(h.host.sent, hasLength(1));
      await h.poll(after: const Duration(hours: 1));
      expect(h.host.sent, hasLength(1), reason: "idle reminders are off");
    });

    test(
      "turning auto-merge on for a repository waits for Allow, then applies to watches started afterwards",
      () async {
        await h.watch(sessionId: "s1");

        final result = await configure(sessionId: "s2", autoMerge: repositoryOn, ciWait: 60);
        expect(result, isA<PullRequestConfigAwaitingApproval>());
        expect(config().ciWaitMinutes, 60, reason: "timings do not wait for the answer");
        expect(config().autoMergeFor(repositoryKey: "sesori/example"), isFalse);
        final asked = h.host.asked.single;
        expect(asked.sessionId, "s2");
        expect(asked.title, "Sesori: PR monitor auto-merge");
        expect(asked.body, startsWith("Turn auto-merge on by default for **sesori/example**?"));

        await configure(quiet: 10);
        asked.answer.complete(SesoriToolApprovalOutcome.allowed);
        await pumpEventQueue();

        expect(h.host.sent.single.sessionId, "s2");
        expect(h.host.sent.single.summary, "PR monitor: auto-merge by default for sesori/example allowed");
        expect(config().autoMergeFor(repositoryKey: "sesori/example"), isTrue);
        expect(config().quietMinutes, 10, reason: "Allow applies on top of later changes");
        expect(
          h.service.statusOf(sessionId: "s1").watches.single.autoMerge,
          isFalse,
          reason: "a watch keeps its choice",
        );
        expect(
          await h.service.watch(sessionId: "s2", target: target, requestedAutoMerge: null),
          isA<PullRequestWatchStarted>().having((started) => started.autoMerge, "autoMerge", isTrue),
        );
      },
    );

    test("a declined request changes nothing and tells the session", () async {
      await configure(autoMerge: const PullRequestGlobalAutoMerge(enabled: true));
      h.host.asked.single.answer.complete(SesoriToolApprovalOutcome.rejected);
      await pumpEventQueue();

      expect(h.host.sent.single.summary, "PR monitor: auto-merge by default for every repository declined");
      expect(config(), PullRequestMonitorConfig.defaults);
      expect(h.store.records, isEmpty);
    });

    test("a session that approves everything turns it on at once, with no card or notice", () async {
      h.host.approvesEverything = true;

      final result = await configure(autoMerge: const PullRequestGlobalAutoMerge(enabled: true));
      expect(
        result,
        isA<PullRequestConfigApplied>().having((applied) => applied.config.autoMerge, "autoMerge", isTrue),
      );
      await pumpEventQueue();
      expect(h.host.asked, isEmpty);
      expect(h.host.sent, isEmpty);
    });

    test("removing a repository's own off setting under a global on default asks first", () async {
      h.host.approvesEverything = true;
      await configure(autoMerge: const PullRequestGlobalAutoMerge(enabled: true));
      h.host.approvesEverything = false;
      expect(
        await configure(
          autoMerge: const PullRequestRepositoryAutoMerge(repositoryKey: "sesori/example", enabled: false),
        ),
        isA<PullRequestConfigApplied>(),
      );

      expect(
        await configure(autoMerge: const PullRequestRepositoryAutoMergeCleared(repositoryKey: "sesori/example")),
        isA<PullRequestConfigAwaitingApproval>(),
      );
      expect(h.host.asked.single.body, startsWith("Remove **sesori/example**'s own auto-merge setting (off)"));
      expect(
        await configure(autoMerge: const PullRequestGlobalAutoMerge(enabled: false)),
        isA<PullRequestConfigApplied>(),
      );
    });
  });
}
