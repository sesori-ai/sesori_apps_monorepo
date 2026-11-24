import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_snapshot.freezed.dart";

/// Every PR reply the agent posts starts with this, so the monitor can tell an
/// agent's acknowledgement from other comments by the same GitHub account.
const String sesoriReplyPrefix = "[Sesori reply]";

enum PullRequestState() {
  open,
  merged,
  closed,
}

/// GitHub's mergeability. `unknown` means GitHub has not computed it yet.
enum PullRequestMergeable() {
  mergeable,
  conflicting,
  unknown,
}

enum PullRequestCheckOutcome() {
  pending,
  success,
  failure,
}

/// Who wrote a comment, as far as the monitor's rules care.
enum PullRequestCommentOrigin() {
  /// Anyone but the GitHub account `gh` is signed in as.
  other,

  /// The signed-in account, without the reply prefix: the user or an agent
  /// that forgot it.
  local,

  /// The signed-in account, starting with [sesoriReplyPrefix].
  agentReply,
}

enum PullRequestReviewState() {
  pending,
  commented,
  approved,
  changesRequested,
  dismissed,
  unknown,
}

/// One poll of a pull request, normalized for the monitor's rules. It holds
/// metadata only: comment bodies are not kept.
@freezed
sealed class PullRequestSnapshot with _$PullRequestSnapshot {
  const factory({
    required String title,
    required String url,
    required PullRequestState state,
    required PullRequestMergeable mergeable,
    required String headSha,

    /// Empty when the head commit has no CI at all.
    required List<PullRequestCheck> checks,

    /// The latest submitted review per reviewer.
    required List<PullRequestReview> reviews,

    /// Reviews with a non-blank body, plus changes-requested reviews that have
    /// no inline comments.
    required List<PullRequestComment> reviewSummaries,

    /// Requested reviewers (user and bot logins, team slugs) who have not
    /// reviewed yet.
    required List<String> pendingReviewers,
    required List<PullRequestReviewThread> reviewThreads,

    /// GitHub's issue-comment count minus the agent replies in the fetched
    /// window, never below zero.
    required int issueCommentsTotal,

    /// The latest 100 issue comments, agent replies included.
    required List<PullRequestComment> issueComments,
    required List<String> labels,
  }) = _PullRequestSnapshot;
}

/// A CheckRun or a commit StatusContext. A StatusContext's [id] is built from
/// its context name and creation time, which change on every new status.
@freezed
sealed class PullRequestCheck with _$PullRequestCheck {
  const factory({
    required String id,
    required String name,
    required PullRequestCheckOutcome outcome,
  }) = _PullRequestCheck;
}

@freezed
sealed class PullRequestReview with _$PullRequestReview {
  const factory({
    required String login,
    required PullRequestReviewState state,
    required DateTime submittedAt,
  }) = _PullRequestReview;
}

/// An issue comment, a review-thread comment, or a review summary.
@freezed
sealed class PullRequestComment with _$PullRequestComment {
  const factory({
    required String id,

    /// `ghost` when GitHub reports no author (a deleted account).
    required String author,
    required bool isBot,
    required DateTime createdAt,

    required PullRequestCommentOrigin origin,

    /// The state of the review a thread comment belongs to; null for issue
    /// comments and review summaries.
    required PullRequestReviewState? reviewState,
  }) = _PullRequestComment;
}

@freezed
sealed class PullRequestReviewThread with _$PullRequestReviewThread {
  const factory({
    required String id,
    required bool isResolved,
    required String? path,

    /// The current line, or the original line once the code moved away.
    required int? line,

    /// The latest 100 comments, agent replies included.
    required List<PullRequestComment> comments,
  }) = _PullRequestReviewThread;
}
