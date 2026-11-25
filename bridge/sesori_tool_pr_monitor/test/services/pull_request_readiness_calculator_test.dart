import "package:sesori_shared/sesori_shared.dart" show PullRequestWatchNeed, PullRequestWatchStatus;
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";

void main() {
  test("a watched PR needs the user for every current reason, and is otherwise ready or waiting", () {
    final ready = emptySnapshot.copyWith(labels: ["agent-ready"]);
    expect(readiness.watchStatus(snapshot: emptySnapshot, autoMerge: false), const PullRequestWatchStatus.waiting());
    expect(readiness.watchStatus(snapshot: ready, autoMerge: true), const PullRequestWatchStatus.ready());
    expect(
      readiness.watchStatus(
        snapshot: ready.copyWith(
          checks: [check(name: "lint", outcome: PullRequestCheckOutcome.failure)],
          mergeable: PullRequestMergeable.conflicting,
          issueComments: [comment(id: "c1", author: "reviewer", at: "2026-11-25T12:00:00Z")],
        ),
        autoMerge: false,
      ),
      const PullRequestWatchStatus.needsYou(
        reasons: [
          PullRequestWatchNeed.ciFailing,
          PullRequestWatchNeed.conflict,
          PullRequestWatchNeed.newReviewComments,
          PullRequestWatchNeed.readyWithoutAutoMerge,
        ],
      ),
    );
    expect(
      readiness.watchStatus(
        snapshot: emptySnapshot.copyWith(
          checks: [check(name: "build", outcome: PullRequestCheckOutcome.pending)],
        ),
        autoMerge: false,
      ),
      const PullRequestWatchStatus.waiting(),
      reason: "running CI is not a failure",
    );
  });

  test("ready-label matching follows GitHub's case-insensitive label identity", () {
    expect(readiness.hasReadyLabel(snapshot: emptySnapshot.copyWith(labels: ["Agent-Ready"])), isTrue);
  });

  test("automatic readiness accepts deliberately unresolved threads after a prefixed local reply", () {
    final result = readiness.assess(
      snapshot: emptySnapshot.copyWith(
        checks: [check(name: "tests", outcome: PullRequestCheckOutcome.success)],
        reviews: [
          PullRequestReview(
            login: "reviewer",
            state: PullRequestReviewState.changesRequested,
            submittedAt: DateTime.parse("2026-08-03T11:00:00Z"),
          ),
        ],
        reviewSummaries: [comment(id: "review-summary", author: "reviewer", at: "2026-08-03T11:02:00Z")],
        pendingReviewers: ["another-reviewer"],
        reviewThreads: [
          thread(
            id: "thread-1",
            isResolved: false,
            comments: [
              comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
              agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
            ],
          ),
        ],
        issueCommentsTotal: 1,
        issueComments: [
          comment(id: "issue-feedback", author: "reviewer", at: "2026-08-03T11:01:00Z"),
          agentReply(id: "issue-reply", at: "2026-08-03T11:06:00Z"),
        ],
      ),
    );

    expect(result.eligible, isTrue);
    expect(result.blockers, isEmpty);
  });

  test("automatic readiness conservatively blocks mixed same-second cross-channel feedback", () {
    const sameTime = "2026-08-03T11:00:00Z";
    final mixed = readiness.assess(
      snapshot: emptySnapshot.copyWith(
        issueComments: [agentReply(id: "issue-reply", at: sameTime)],
        reviewSummaries: [comment(id: "review-feedback", author: "reviewer", at: sameTime)],
      ),
    );
    final emptyThread = readiness.assess(
      snapshot: emptySnapshot.copyWith(
        reviewThreads: [thread(id: "empty-thread", isResolved: false, comments: const [])],
      ),
    );
    final acknowledged = readiness.assess(
      snapshot: emptySnapshot.copyWith(
        issueComments: [agentReply(id: "issue-reply", at: sameTime)],
        reviewSummaries: [agentReply(id: "review-reply", at: sameTime)],
      ),
    );

    expect(mixed.eligible, isFalse);
    expect(mixed.awaitingUnthreadedReply, isTrue);
    expect(emptyThread.eligible, isFalse);
    expect(emptyThread.awaitingThreadReplies, 1);
    expect(acknowledged.eligible, isTrue);
  });

  test("blockers name every reason in order", () {
    final result = readiness.assess(
      snapshot: emptySnapshot.copyWith(
        state: PullRequestState.closed,
        mergeable: PullRequestMergeable.conflicting,
        checks: [check(name: "tests", outcome: PullRequestCheckOutcome.pending)],
        reviewThreads: [
          for (final id in ["thread-1", "thread-2"])
            thread(
              id: id,
              isResolved: false,
              comments: [comment(id: "$id-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z")],
            ),
        ],
        issueComments: [comment(id: "issue-feedback", author: "reviewer", at: "2026-08-03T11:00:00Z")],
      ),
    );

    expect(result.blockers, [
      "PR is closed",
      "CI is running",
      "the PR has a merge conflict",
      "2 review threads await a prefixed reply from the local GitHub account",
      "issue or review-summary feedback awaits a prefixed reply from the local GitHub account",
    ]);
    expect(
      readiness
          .assess(
            snapshot: emptySnapshot.copyWith(
              mergeable: PullRequestMergeable.unknown,
              checks: [check(name: "tests", outcome: PullRequestCheckOutcome.failure)],
            ),
          )
          .blockers,
      ["CI is failing", "mergeability is still unknown"],
    );
  });

  test("deleting the latest prefixed reply is an acknowledgement regression", () {
    final feedback = comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z");
    final reply = agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z");
    final initial = emptySnapshot.copyWith(
      labels: ["agent-ready"],
      reviewThreads: [
        thread(id: "thread-1", isResolved: false, comments: [feedback, reply]),
      ],
    );
    final changed = initial.copyWith(
      reviewThreads: [
        thread(id: "thread-1", isResolved: false, comments: [feedback]),
      ],
    );
    final edited = initial.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            feedback,
            reply.copyWith(origin: PullRequestCommentOrigin.local),
          ],
        ),
      ],
    );
    final agentOnly = emptySnapshot.copyWith(
      reviewThreads: [
        thread(id: "thread-2", isResolved: false, comments: [reply]),
      ],
    );
    final emptied = emptySnapshot.copyWith(
      reviewThreads: [thread(id: "thread-2", isResolved: false, comments: const [])],
    );

    expect(readiness.hasAcknowledgementRegression(previous: initial, next: edited), isTrue);
    expect(readiness.hasAcknowledgementRegression(previous: agentOnly, next: emptied), isTrue);
    expect(readiness.hasAcknowledgementRegression(previous: emptySnapshot, next: emptied), isTrue);
    expect(
      readiness.hasReadinessInvalidation(
        previous: initial,
        next: changed,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
    expect(readiness.assess(snapshot: changed).blockers, [
      "1 review thread awaits a prefixed reply from the local GitHub account",
    ]);
  });

  test("an unthreaded channel regresses only when it was acknowledged", () {
    final replied = emptySnapshot.copyWith(
      issueComments: [
        comment(id: "issue-feedback", author: "reviewer", at: "2026-08-03T11:00:00Z"),
        agentReply(id: "issue-reply", at: "2026-08-03T11:05:00Z"),
      ],
    );
    final followUp = replied.copyWith(
      issueComments: [
        ...replied.issueComments,
        comment(id: "issue-follow-up", author: "reviewer", at: "2026-08-03T11:10:00Z"),
      ],
    );
    final unanswered = emptySnapshot.copyWith(
      issueComments: [comment(id: "issue-feedback", author: "reviewer", at: "2026-08-03T11:00:00Z")],
    );

    expect(readiness.hasAcknowledgementRegression(previous: replied, next: followUp), isTrue);
    expect(readiness.hasAcknowledgementRegression(previous: unanswered, next: followUp), isFalse);
    expect(readiness.hasAcknowledgementRegression(previous: replied, next: emptySnapshot), isFalse);
  });

  test("new bot feedback on an existing acknowledged thread withdraws readiness", () {
    final acknowledged = [
      comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
      agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
    ];
    final initial = emptySnapshot.copyWith(
      labels: ["agent-ready"],
      reviewThreads: [thread(id: "thread-1", isResolved: false, comments: acknowledged)],
    );
    final changed = initial.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            ...acknowledged,
            comment(id: "thread-1-comment-3", author: "review-bot", at: "2026-08-03T12:01:00Z").copyWith(isBot: true),
          ],
        ),
      ],
    );

    expect(
      readiness.hasReadinessInvalidation(
        previous: initial,
        next: changed,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
  });

  test("new review-summary feedback withdraws readiness even when its review is approving", () {
    final initial = emptySnapshot.copyWith(labels: ["agent-ready"]);
    final changed = initial.copyWith(
      reviews: [
        PullRequestReview(
          login: "review-bot",
          state: PullRequestReviewState.approved,
          submittedAt: DateTime.parse("2026-08-03T12:01:00Z"),
        ),
      ],
      reviewSummaries: [
        comment(id: "review-summary", author: "review-bot", at: "2026-08-03T12:01:00Z").copyWith(isBot: true),
      ],
    );

    expect(
      readiness.hasReadinessInvalidation(
        previous: initial,
        next: changed,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
  });

  test("a new CI-less head withdraws readiness", () {
    final initial = emptySnapshot.copyWith(labels: ["agent-ready"]);
    final pushed = initial.copyWith(headSha: "head-2");

    expect(
      readiness.hasReadinessInvalidation(
        previous: initial,
        next: pushed,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
  });

  test("resolution, transient UNKNOWN, merge and close do not withdraw readiness", () {
    final comments = [
      comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
      agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
    ];
    final initial = emptySnapshot.copyWith(
      labels: ["agent-ready"],
      reviewThreads: [thread(id: "thread-1", isResolved: false, comments: comments)],
    );
    final resolved = initial.copyWith(
      reviewThreads: [thread(id: "thread-1", isResolved: true, comments: comments)],
    );

    for (final next in [
      resolved,
      initial.copyWith(mergeable: PullRequestMergeable.unknown),
      initial.copyWith(state: PullRequestState.merged, headSha: "head-2"),
      initial.copyWith(state: PullRequestState.closed),
    ]) {
      expect(
        readiness.hasReadinessInvalidation(
          previous: initial,
          next: next,
          lastDefiniteMergeable: PullRequestMergeable.mergeable,
        ),
        isFalse,
      );
    }
  });

  test("CI leaving readiness, a new failure or a new conflict withdraws readiness", () {
    final passing = emptySnapshot.copyWith(
      checks: [check(name: "tests", outcome: PullRequestCheckOutcome.success)],
    );
    final rerunning = passing.copyWith(
      checks: [check(name: "tests", outcome: PullRequestCheckOutcome.pending)],
    );
    final failing = emptySnapshot.copyWith(
      checks: [
        check(name: "lint", outcome: PullRequestCheckOutcome.failure),
        check(name: "tests", outcome: PullRequestCheckOutcome.pending),
      ],
    );
    final failingMore = failing.copyWith(
      checks: [
        check(name: "lint", outcome: PullRequestCheckOutcome.failure),
        check(name: "tests", outcome: PullRequestCheckOutcome.failure),
      ],
    );

    bool invalidates({required PullRequestSnapshot previous, required PullRequestSnapshot next}) =>
        readiness.hasReadinessInvalidation(
          previous: previous,
          next: next,
          lastDefiniteMergeable: PullRequestMergeable.mergeable,
        );

    expect(invalidates(previous: passing, next: rerunning), isTrue);
    expect(invalidates(previous: failing, next: failingMore), isTrue);
    expect(invalidates(previous: failing, next: failing), isFalse);
    expect(
      invalidates(
        previous: emptySnapshot,
        next: emptySnapshot.copyWith(mergeable: PullRequestMergeable.conflicting),
      ),
      isTrue,
    );
  });
}
