import "pull_request_selection.dart";

enum PullRequestNoBranchReason() { missingDirectory, notGitRepository, detachedHead }

sealed class const PullRequestDirectoryTarget();

final class const PullRequestGithubDirectoryTarget({required final PullRequestSelectionTarget target}) extends PullRequestDirectoryTarget;

final class const PullRequestLocalBranchDirectoryTarget({required final String branchName}) extends PullRequestDirectoryTarget;

final class const PullRequestNoBranchDirectoryTarget({required final PullRequestNoBranchReason reason}) extends PullRequestDirectoryTarget;

final class const PullRequestBranchResolutionFailed({required final PullRequestTargetResolutionException error}) extends PullRequestDirectoryTarget;

final class const PullRequestBranchChangedDuringResolution() extends PullRequestDirectoryTarget;

final class const PullRequestRepositoryResolutionFailed({
    required final String branchName,
    required final PullRequestTargetResolutionException error,
  }) extends PullRequestDirectoryTarget;

final class const PullRequestTargetResolutionException({
    required final Object innerError,
    required final StackTrace innerStackTrace,
  }) implements Exception {
  @override
  String toString() => "Local pull request target resolution failed while handling ${innerError.runtimeType}";
}

sealed class const PullRequestReplacementOutcome();

final class const PullRequestReplacementApplied({required final bool changed}) extends PullRequestReplacementOutcome;

final class const PullRequestReplacementScopeChanged() extends PullRequestReplacementOutcome;
