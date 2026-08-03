import "pull_request_selection.dart";

enum PullRequestNoBranchReason { missingDirectory, notGitRepository, detachedHead }

sealed class PullRequestDirectoryTarget {
  const PullRequestDirectoryTarget();
}

final class PullRequestGithubDirectoryTarget extends PullRequestDirectoryTarget {
  final PullRequestSelectionTarget target;

  const PullRequestGithubDirectoryTarget({required this.target});
}

final class PullRequestLocalBranchDirectoryTarget extends PullRequestDirectoryTarget {
  final String branchName;

  const PullRequestLocalBranchDirectoryTarget({required this.branchName});
}

final class PullRequestNoBranchDirectoryTarget extends PullRequestDirectoryTarget {
  final PullRequestNoBranchReason reason;

  const PullRequestNoBranchDirectoryTarget({required this.reason});
}

final class PullRequestBranchResolutionFailed extends PullRequestDirectoryTarget {
  final PullRequestTargetResolutionException error;

  const PullRequestBranchResolutionFailed({required this.error});
}

final class PullRequestBranchChangedDuringResolution extends PullRequestDirectoryTarget {
  const PullRequestBranchChangedDuringResolution();
}

final class PullRequestRepositoryResolutionFailed extends PullRequestDirectoryTarget {
  final String branchName;
  final PullRequestTargetResolutionException error;

  const PullRequestRepositoryResolutionFailed({
    required this.branchName,
    required this.error,
  });
}

final class PullRequestTargetResolutionException implements Exception {
  final Object innerError;
  final StackTrace innerStackTrace;

  const PullRequestTargetResolutionException({
    required this.innerError,
    required this.innerStackTrace,
  });

  @override
  String toString() => "Local pull request target resolution failed while handling ${innerError.runtimeType}";
}

sealed class PullRequestReplacementOutcome {
  const PullRequestReplacementOutcome();
}

final class PullRequestReplacementApplied extends PullRequestReplacementOutcome {
  final bool changed;

  const PullRequestReplacementApplied({required this.changed});
}

final class PullRequestReplacementScopeChanged extends PullRequestReplacementOutcome {
  const PullRequestReplacementScopeChanged();
}
