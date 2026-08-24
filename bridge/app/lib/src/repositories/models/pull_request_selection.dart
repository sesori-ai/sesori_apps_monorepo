import "../../api/gh_pull_request.dart";

typedef PullRequestSelectionTarget = ({
  String githubRepositoryIdentity,
  String branchName,
});

sealed class const PullRequestSelectionOutcome();

final class const PullRequestSelectionCompleted({required final List<PullRequestTargetSelection> selections})
    extends PullRequestSelectionOutcome;

final class const PullRequestSelectionIdentityChanged() extends PullRequestSelectionOutcome;

sealed class const PullRequestTargetSelection({required final PullRequestSelectionTarget target});

final class const PullRequestTargetSelected({required super.target, required final GhPullRequest pullRequest})
    extends PullRequestTargetSelection;

final class const PullRequestTargetUnmatched({required super.target}) extends PullRequestTargetSelection;
