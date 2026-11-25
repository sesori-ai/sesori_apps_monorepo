import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_snapshot.dart";

part "pull_request_baseline.freezed.dart";
part "pull_request_baseline.g.dart";

/// What a watcher's last report covered. A comment is new when its id is not
/// here, and any other difference from a fresh poll is activity since then.
/// It is stored with the watch, so it keeps ids, counts and signatures only,
/// never comment bodies.
@freezed
sealed class PullRequestBaseline with _$PullRequestBaseline {
  const factory({
    required PullRequestState state,
    required String headSha,
    required PullRequestMergeable mergeable,

    /// Whether any check was still pending.
    required bool ciRunning,
    required Set<String> failedCheckIds,

    /// Each latest review's author, state and time, plus the pending
    /// reviewers.
    required String reviewSignature,

    /// Relevant comments only: the agent's prefixed replies are never news.
    required Set<String> issueCommentIds,
    required int issueCommentsTotal,
    required Set<String> reviewSummaryIds,

    /// Relevant comment ids per review thread id.
    required Map<String, Set<String>> threadCommentIds,
    required Set<String> resolvedThreadIds,
    required int unresolvedThreadCount,
  }) = _PullRequestBaseline;

  factory fromSnapshot({required PullRequestSnapshot snapshot}) => PullRequestBaseline(
    state: snapshot.state,
    headSha: snapshot.headSha,
    mergeable: snapshot.mergeable,
    ciRunning: snapshot.checks.any((check) => check.outcome == PullRequestCheckOutcome.pending),
    failedCheckIds: {
      for (final check in snapshot.checks)
        if (check.outcome == PullRequestCheckOutcome.failure) check.id,
    },
    reviewSignature: reviewSignatureOf(snapshot: snapshot),
    issueCommentIds: _relevantIds(comments: snapshot.issueComments),
    issueCommentsTotal: snapshot.issueCommentsTotal,
    reviewSummaryIds: _relevantIds(comments: snapshot.reviewSummaries),
    threadCommentIds: {for (final thread in snapshot.reviewThreads) thread.id: _relevantIds(comments: thread.comments)},
    resolvedThreadIds: {
      for (final thread in snapshot.reviewThreads)
        if (thread.isResolved) thread.id,
    },
    unresolvedThreadCount: snapshot.reviewThreads.where((thread) => !thread.isResolved).length,
  );

  factory fromJson(Map<String, dynamic> json) => _$PullRequestBaselineFromJson(json);

  /// A change here is review activity: a new or changed review, or a
  /// reviewer requested or removed.
  static String reviewSignatureOf({required PullRequestSnapshot snapshot}) {
    final states = [
      for (final review in snapshot.reviews)
        "${review.login}=${review.state.name}@${review.submittedAt.toUtc().toIso8601String()}",
    ]..sort();
    final pending = [...snapshot.pendingReviewers]..sort();
    return "${states.join(",")}|${pending.join(",")}";
  }

  static Set<String> _relevantIds({required List<PullRequestComment> comments}) => {
    for (final comment in comments)
      if (comment.origin != PullRequestCommentOrigin.agentReply) comment.id,
  };
}
