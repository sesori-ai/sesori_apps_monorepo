import "package:sesori_shared/sesori_shared.dart";

/// Where a watched pull request stands for the user, most urgent first: the
/// order of the list's groups and of a session's lead pull request.
enum PullRequestWatchStage() {
  /// Ready with no auto-merge, so the user merges it. The only stage that
  /// needs the user.
  toMerge,

  /// Failing CI, a conflict or unanswered review comments, which the agent
  /// handles.
  agentOnIt,

  /// Waiting on checks or review, or in a state this build does not know.
  waiting,

  /// Ready, and auto-merge will merge it.
  mergesAutomatically,

  /// Merged since the computer's local midnight.
  mergedToday;

  /// The stage of a pull request in [status]. A reason the agent handles wins
  /// over ready to merge, because the pull request is not really mergeable
  /// yet.
  static PullRequestWatchStage of({required PullRequestWatchStatus status}) => switch (status) {
    PullRequestWatchStatusNeedsYou(:final reasons) when reasons.any(isAgentReason) => agentOnIt,
    PullRequestWatchStatusNeedsYou(:final reasons) when reasons.contains(PullRequestWatchNeed.readyWithoutAutoMerge) =>
      toMerge,
    PullRequestWatchStatusNeedsYou() || PullRequestWatchStatusWaiting() || PullRequestWatchStatusUnknown() => waiting,
    PullRequestWatchStatusReady() => mergesAutomatically,
    PullRequestWatchStatusMerged() => mergedToday,
  };

  /// Whether the agent handles [need] on its own.
  static bool isAgentReason(PullRequestWatchNeed need) => switch (need) {
    PullRequestWatchNeed.ciFailing || PullRequestWatchNeed.conflict || PullRequestWatchNeed.newReviewComments => true,
    PullRequestWatchNeed.readyWithoutAutoMerge || PullRequestWatchNeed.unknown => false,
  };
}
