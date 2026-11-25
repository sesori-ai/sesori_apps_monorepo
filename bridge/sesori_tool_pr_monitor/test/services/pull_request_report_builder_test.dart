import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_report_builder.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";

String report({required PullRequestSnapshot snapshot, required PullRequestSnapshot? baseline}) => reports.buildReport(
  target: target,
  snapshot: snapshot,
  baseline: baseline == null ? null : activity.baselineOf(snapshot: baseline),
  forcedHoldMinutes: null,
  autoMergeEnabled: false,
  readinessError: null,
  autoMergeNotice: null,
  opening: PullRequestReportOpening.ongoing,
);

void main() {
  test("reports locate pending unprefixed local-account follow-ups as human feedback", () {
    final reply = agentReply(id: "thread-1-comment-1", at: "2026-08-03T11:00:00Z");
    final before = emptySnapshot.copyWith(
      reviewThreads: [
        thread(id: "thread-1", isResolved: false, comments: [reply]),
      ],
    );
    final after = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            reply,
            comment(
              id: "thread-1-comment-2",
              author: "owner",
              at: "2026-08-03T12:01:00Z",
            ).copyWith(origin: PullRequestCommentOrigin.local, reviewState: PullRequestReviewState.pending),
          ],
        ).copyWith(path: "bridge/app/lib/src/services/session_creation_service.dart", line: 90),
      ],
    );

    final text = report(snapshot: after, baseline: before);

    expect(text, contains("owner [local account, unprefixed; pending review]"));
    expect(
      text,
      contains(
        "Changed threads: `bridge/app/lib/src/services/session_creation_service.dart:90` [thread `thread-1`] "
        "(unresolved; 1 owner [local account, unprefixed; pending review])",
      ),
    );
    expect(text, contains("new human comment, not an earlier agent reply"));
    expect(text, contains("Pending-review comments may be absent from REST pull-comment results"));
    expect(text, contains("inspect the listed thread through GraphQL before marking ready"));
    expect(text, contains("Local agent replies count only when they begin with `[Sesori reply]`"));
  });

  test("reports identify resolved and unresolved threads that received new comments", () {
    final old1 = comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z");
    final old3 = comment(id: "thread-3-comment-1", author: "reviewer", at: "2026-08-03T11:30:00Z");
    final before = emptySnapshot.copyWith(
      reviewThreads: [
        thread(id: "thread-1", isResolved: false, comments: [old1]),
        thread(id: "thread-3", isResolved: false, comments: [old3]),
      ],
    );
    final after = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            old1,
            comment(id: "thread-1-comment-2", author: "alice", at: "2026-08-03T12:01:00Z"),
          ],
        ).copyWith(path: "core/report.ts", line: 53),
        thread(
          id: "thread-2",
          isResolved: true,
          comments: [comment(id: "thread-2-comment-1", author: "owner", at: "2026-08-03T12:02:00Z")],
        ).copyWith(path: "core/report.ts", line: 53),
        thread(id: "thread-3", isResolved: false, comments: [old3]),
      ],
    );

    final text = report(snapshot: after, baseline: before);

    expect(
      text,
      contains("[comment:inline] ACTION REQUIRED: 2 threads received 2 new relevant comments since last flush"),
    );
    expect(text, contains("(1 currently unresolved, 1 currently resolved; 1 alice, 1 owner)"));
    expect(text, contains("The unresolved-thread count is unchanged at 2; inspect every changed thread anyway."));
    expect(text, contains("`core/report.ts:53` [thread `thread-1`] (unresolved; 1 alice)"));
    expect(text, contains("`core/report.ts:53` [thread `thread-2`] (resolved; 1 owner)"));
  });

  test("report baselines use comment IDs when GitHub timestamps share a second", () {
    final first = comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T12:00:00Z");
    final before = emptySnapshot.copyWith(
      reviewThreads: [
        thread(id: "thread-1", isResolved: false, comments: [first]),
      ],
    );
    final after = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            first,
            comment(id: "thread-1-comment-2", author: "owner", at: "2026-08-03T12:00:00Z"),
          ],
        ),
      ],
    );

    expect(
      report(snapshot: after, baseline: before),
      contains("1 thread received 1 new relevant comment since last flush"),
    );
  });

  test("a first report counts every existing comment as new", () {
    final snapshot = emptySnapshot.copyWith(
      reviewSummaries: [comment(id: "review-summary", author: "review-bot", at: "2026-08-03T11:00:00Z")],
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z")],
        ),
      ],
      issueCommentsTotal: 2,
      issueComments: [
        comment(id: "issue-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
        agentReply(id: "issue-2", at: "2026-08-03T11:05:00Z"),
      ],
    );

    final text = report(snapshot: snapshot, baseline: null);

    expect(text, contains("- [comment:review] ACTION REQUIRED: 1 new relevant review summary since last flush"));
    expect(
      text,
      contains("Inspect every changed thread regardless of the current unresolved-thread count (1). "),
    );
    expect(text, contains("Changed threads: thread `thread-1` (unresolved; 1 reviewer)."));
    expect(text, contains("- [comment:issue] 2 total (1 new relevant since last flush: 1 reviewer)"));
  });

  test("a quiet open report lists state, blockers and the next step", () {
    final snapshot = emptySnapshot.copyWith(
      title: "  test\n  PR  ",
      reviews: [
        PullRequestReview(
          login: "alice",
          state: PullRequestReviewState.approved,
          submittedAt: DateTime.parse("2026-08-03T11:00:00Z"),
        ),
        PullRequestReview(
          login: "bob",
          state: PullRequestReviewState.changesRequested,
          submittedAt: DateTime.parse("2026-08-03T11:00:00Z"),
        ),
      ],
      pendingReviewers: ["carol"],
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z")],
        ),
      ],
      labels: ["bug"],
    );

    const nextStep =
        '- Required next step: Do more work until the PR is ready, or use `mark_pr_ready(pr: "sesori/example#42")` '
        "if you believe nothing else is required. Local agent replies count only when they begin with "
        "`[Sesori reply]`.";

    expect(
      report(snapshot: snapshot, baseline: snapshot),
      [
        '[PR Monitor] [sesori/example#42](https://github.com/sesori/example/pull/42) — "test PR"',
        "- CI: none",
        "- Mergeable: MERGEABLE",
        "- Reviews: alice ✓ approved · bob ✗ changes_requested · carol ⏳ pending",
        "- [comment:review] 0 new relevant review summaries since last flush",
        "- [comment:inline] 1 unresolved thread; 0 threads received new relevant comments since last flush",
        "- [comment:issue] 0 total (0 new since last flush)",
        '- Ready: NO — label "agent-ready" is absent.',
        "- Automatic readiness blocked by: 1 review thread awaits a prefixed reply from the local GitHub account.",
        nextStep,
        "- Labels: bug",
      ].join("\n"),
    );
  });

  test("CI lines cover passing, failing, running and the forced hold", () {
    String ciLine({required List<PullRequestCheck> checks, required int? forcedHoldMinutes}) => reports
        .buildReport(
          target: target,
          snapshot: emptySnapshot.copyWith(checks: checks),
          baseline: null,
          forcedHoldMinutes: forcedHoldMinutes,
          autoMergeEnabled: false,
          readinessError: null,
          autoMergeNotice: null,
          opening: PullRequestReportOpening.ongoing,
        )
        .split("\n")[1];

    final lint = check(name: "lint", outcome: PullRequestCheckOutcome.success);
    final failedLint = check(name: "lint", outcome: PullRequestCheckOutcome.failure);
    final tests = check(name: "tests", outcome: PullRequestCheckOutcome.pending);
    final build = check(name: "build", outcome: PullRequestCheckOutcome.pending);

    expect(ciLine(checks: [lint], forcedHoldMinutes: null), "- CI: passing (1/1)");
    expect(
      ciLine(
        checks: [
          failedLint,
          check(name: "tests", outcome: PullRequestCheckOutcome.success),
        ],
        forcedHoldMinutes: null,
      ),
      "- CI: failing (1/2 failed: lint)",
    );
    expect(ciLine(checks: [lint, tests], forcedHoldMinutes: null), "- CI: running (1/2 done)");
    expect(
      ciLine(checks: [failedLint, tests], forcedHoldMinutes: null),
      "- CI: running (1/2 done, 1 failed so far: lint)",
    );
    expect(
      ciLine(checks: [lint, tests, build], forcedHoldMinutes: 30),
      "- CI: running for 30m+ (in_progress: tests, build)",
    );
  });

  test("terminal states preserve an existing ready label", () {
    final merged = emptySnapshot.copyWith(state: PullRequestState.merged, labels: ["agent-ready"]);

    final text = report(snapshot: merged, baseline: merged);

    expect(text.split("\n").first, endsWith(" — MERGED"));
    expect(text, contains('- Ready: YES — label "agent-ready" is present.'));
    expect(text, contains("- Monitor stopped: PR merged"));
    expect(text, isNot(contains("Required next step")));
    expect(text, isNot(contains("Automatic readiness blocked by")));
  });

  test("new review-summary feedback is reported as action required", () {
    final changed = emptySnapshot.copyWith(
      reviewSummaries: [
        comment(id: "review-summary", author: "review-bot", at: "2026-08-03T12:01:00Z").copyWith(isBot: true),
      ],
    );

    expect(
      report(snapshot: changed, baseline: emptySnapshot),
      contains(
        "- [comment:review] ACTION REQUIRED: 1 new relevant review summary since last flush (1 review-bot[bot]).",
      ),
    );
  });

  test("author breakdowns sort by count and keep first-seen order on ties", () {
    final snapshot = emptySnapshot.copyWith(
      issueCommentsTotal: 4,
      issueComments: [
        comment(id: "issue-1", author: "bob", at: "2026-08-03T11:00:00Z"),
        comment(id: "issue-2", author: "alice", at: "2026-08-03T11:01:00Z"),
        comment(id: "issue-3", author: "carol", at: "2026-08-03T11:02:00Z"),
        comment(id: "issue-4", author: "carol", at: "2026-08-03T11:03:00Z"),
      ],
    );

    expect(
      report(snapshot: snapshot, baseline: null),
      contains("- [comment:issue] 4 total (4 new relevant since last flush: 2 carol, 1 bob, 1 alice)"),
    );
  });

  test("the auto-merge line, a readiness failure and the merge result appear in the report", () {
    final text = reports.buildReport(
      target: target,
      snapshot: emptySnapshot,
      baseline: null,
      forcedHoldMinutes: null,
      autoMergeEnabled: true,
      readinessError: 'could not add label "agent-ready": boom',
      autoMergeNotice: "Auto-merge succeeded: merged.",
      opening: PullRequestReportOpening.ongoing,
    );

    expect(text, contains('- Readiness automation failed: could not add label "agent-ready": boom'));
    expect(text, contains("\n- Auto-merge succeeded: merged."));

    expect(
      text,
      contains(
        "- Auto-merge: ENABLED — readiness (automatic or mark_pr_ready) makes one squash-merge attempt, as the user "
        "wants; never hold mark_pr_ready back to wait for a human.",
      ),
    );
  });

  test("an idle reminder shows current state and asks why a ready auto-merge PR is still open", () {
    final ready = emptySnapshot.copyWith(labels: ["agent-ready"]);

    final reminder = reports.buildIdleReminder(
      target: target,
      snapshot: ready,
      idleMinutes: 25,
      autoMergeEnabled: true,
      readinessError: null,
    );
    final unready = reports.buildIdleReminder(
      target: target,
      snapshot: emptySnapshot,
      idleMinutes: 25,
      autoMergeEnabled: false,
      readinessError: null,
    );

    expect(reminder.split("\n").first, endsWith('— "test PR" — idle reminder'));
    expect(reminder, contains("- Idle: no PR activity and no report for 25m."));
    expect(reminder, contains("- [comment:inline] 0 unresolved threads"));
    expect(reminder, contains("the PR is ready with auto-merge on but is still open, so the merge did not go through"));
    expect(unready, isNot(contains("auto-merge on but is still open")));
    expect(unready, contains("- Required next step: Do more work until the PR is ready"));
  });
}
