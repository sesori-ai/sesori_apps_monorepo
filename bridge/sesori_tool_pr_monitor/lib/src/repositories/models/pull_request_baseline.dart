import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_snapshot.dart" show PullRequestMergeable, PullRequestState;

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

  factory fromJson(Map<String, dynamic> json) => _$PullRequestBaselineFromJson(json);
}
