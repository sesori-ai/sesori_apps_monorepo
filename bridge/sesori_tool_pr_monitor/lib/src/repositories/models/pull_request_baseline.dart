import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_snapshot.dart";

part "pull_request_baseline.freezed.dart";

/// What a watcher's last report covered: a comment is new when its id is not
/// here. It keeps ids and counts only, never comment bodies.
@freezed
sealed class PullRequestBaseline with _$PullRequestBaseline {
  const factory({
    required Set<String> issueCommentIds,
    required Set<String> reviewSummaryIds,

    /// Comment ids per review thread id.
    required Map<String, Set<String>> threadCommentIds,
    required int unresolvedThreadCount,
  }) = _PullRequestBaseline;

  factory fromSnapshot({required PullRequestSnapshot snapshot}) => PullRequestBaseline(
    issueCommentIds: {for (final comment in snapshot.issueComments) comment.id},
    reviewSummaryIds: {for (final comment in snapshot.reviewSummaries) comment.id},
    threadCommentIds: {
      for (final thread in snapshot.reviewThreads) thread.id: {for (final comment in thread.comments) comment.id},
    },
    unresolvedThreadCount: snapshot.reviewThreads.where((thread) => !thread.isResolved).length,
  );
}
