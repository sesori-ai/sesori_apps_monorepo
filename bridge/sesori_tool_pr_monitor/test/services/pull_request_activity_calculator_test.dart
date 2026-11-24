import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";

void main() {
  test("a follow-up in an existing thread is activity even when resolution counts do not change", () {
    final first = comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z");
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
            comment(id: "thread-1-comment-2", author: "owner", at: "2026-08-03T11:10:00Z"),
          ],
        ),
      ],
    );

    expect(
      activity.detectActivity(previous: before, next: after, lastDefiniteMergeable: PullRequestMergeable.mergeable),
      isTrue,
    );
  });

  test("an ignored reply rolling a full comment window does not look like visible activity", () {
    final visible = [
      for (var index = 0; index < 100; index++)
        comment(
          id: "comment-${index + 1}",
          author: "reviewer",
          at: "2026-08-03T11:${(index % 60).toString().padLeft(2, "0")}:00Z",
        ),
    ];
    final before = emptySnapshot.copyWith(
      reviewThreads: [thread(id: "thread-1", isResolved: false, comments: visible)],
    );
    final afterIgnoredReply = emptySnapshot.copyWith(
      reviewThreads: [thread(id: "thread-1", isResolved: false, comments: visible.sublist(1))],
    );
    final afterHumanReply = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            ...visible.sublist(1),
            comment(id: "comment-101", author: "owner", at: "2026-08-03T12:01:00Z"),
          ],
        ),
      ],
    );

    expect(
      activity.detectActivity(
        previous: before,
        next: afterIgnoredReply,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isFalse,
    );
    expect(
      activity.detectActivity(
        previous: before,
        next: afterHumanReply,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
  });

  test("new merge conflicts are recognized across transient UNKNOWN polls", () {
    final conflicting = emptySnapshot.copyWith(mergeable: PullRequestMergeable.conflicting);

    expect(
      activity.hasNewMergeConflict(lastDefiniteMergeable: PullRequestMergeable.mergeable, next: conflicting),
      isTrue,
    );
    expect(
      activity.hasNewMergeConflict(lastDefiniteMergeable: PullRequestMergeable.conflicting, next: conflicting),
      isFalse,
    );
    expect(activity.hasNewMergeConflict(lastDefiniteMergeable: null, next: conflicting), isTrue);
  });

  test("a failed same-name check rerun is new activity when its check-run identity changes", () {
    final before = emptySnapshot.copyWith(
      checks: [const PullRequestCheck(id: "check-run-1", name: "tests", outcome: PullRequestCheckOutcome.failure)],
    );
    final after = emptySnapshot.copyWith(
      checks: [const PullRequestCheck(id: "check-run-2", name: "tests", outcome: PullRequestCheckOutcome.failure)],
    );

    expect(activity.hasNewCiFailure(previous: before, next: after), isTrue);
    expect(activity.hasNewCiFailure(previous: after, next: after), isFalse);
  });

  test("mergeability churn through UNKNOWN is quiet until it settles somewhere new", () {
    final unknown = emptySnapshot.copyWith(mergeable: PullRequestMergeable.unknown);
    final conflicting = emptySnapshot.copyWith(mergeable: PullRequestMergeable.conflicting);

    expect(
      activity.detectActivity(
        previous: emptySnapshot,
        next: unknown,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isFalse,
    );
    expect(
      activity.detectActivity(
        previous: unknown,
        next: emptySnapshot,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isFalse,
    );
    expect(
      activity.detectActivity(
        previous: unknown,
        next: conflicting,
        lastDefiniteMergeable: PullRequestMergeable.mergeable,
      ),
      isTrue,
    );
  });

  test("CI starting or progressing is quiet and its conclusion is activity", () {
    final running = emptySnapshot.copyWith(
      checks: [
        check(name: "lint", outcome: PullRequestCheckOutcome.success),
        check(name: "tests", outcome: PullRequestCheckOutcome.pending),
      ],
    );
    final passed = emptySnapshot.copyWith(
      checks: [
        check(name: "lint", outcome: PullRequestCheckOutcome.success),
        check(name: "tests", outcome: PullRequestCheckOutcome.success),
      ],
    );

    expect(activity.detectActivity(previous: emptySnapshot, next: running, lastDefiniteMergeable: null), isFalse);
    expect(activity.detectActivity(previous: running, next: passed, lastDefiniteMergeable: null), isTrue);
    expect(activity.detectActivity(previous: passed, next: passed, lastDefiniteMergeable: null), isFalse);
  });

  test("thread resolution is activity", () {
    final comments = [
      comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
      agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
    ];
    final open = emptySnapshot.copyWith(
      reviewThreads: [thread(id: "thread-1", isResolved: false, comments: comments)],
    );
    final resolved = emptySnapshot.copyWith(
      reviewThreads: [thread(id: "thread-1", isResolved: true, comments: comments)],
    );

    expect(activity.detectActivity(previous: open, next: resolved, lastDefiniteMergeable: null), isTrue);
  });
}
