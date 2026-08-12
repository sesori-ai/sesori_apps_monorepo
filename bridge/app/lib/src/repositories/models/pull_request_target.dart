import "pull_request_selection.dart";

enum PullRequestNoBranchReason() { missingDirectory, notGitRepository, detachedHead }

sealed class const PullRequestDirectoryTarget();

final class const PullRequestGithubDirectoryTarget({required this.target}) extends PullRequestDirectoryTarget {
  final PullRequestSelectionTarget target;
}

final class const PullRequestLocalBranchDirectoryTarget({required this.branchName}) extends PullRequestDirectoryTarget {
  final String branchName;
}

final class const PullRequestNoBranchDirectoryTarget({required this.reason}) extends PullRequestDirectoryTarget {
  final PullRequestNoBranchReason reason;
}

final class const PullRequestBranchResolutionFailed({required this.error}) extends PullRequestDirectoryTarget {
  final PullRequestTargetResolutionException error;
}

final class const PullRequestBranchChangedDuringResolution() extends PullRequestDirectoryTarget;

final class const PullRequestRepositoryResolutionFailed({
    required this.branchName,
    required this.error,
  }) extends PullRequestDirectoryTarget {
  final String branchName;
  final PullRequestTargetResolutionException error;
}

final class const PullRequestTargetResolutionException({
    required this.innerError,
    required this.innerStackTrace,
  }) implements Exception {
  final Object innerError;
  final StackTrace innerStackTrace;

  @override
  String toString() => "Local pull request target resolution failed while handling ${innerError.runtimeType}";
}

sealed class const PullRequestReplacementOutcome();

final class const PullRequestReplacementApplied({required this.changed}) extends PullRequestReplacementOutcome {
  final bool changed;
}

final class const PullRequestReplacementScopeChanged() extends PullRequestReplacementOutcome;
