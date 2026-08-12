import "package:sesori_shared/sesori_shared.dart";

typedef PullRequestSelectionTarget = ({
  String githubRepositoryIdentity,
  String branchName,
});

sealed class const PullRequestSelectionOutcome();

final class const PullRequestSelectionCompleted({required final List<PullRequestTargetSelection> selections})
    extends PullRequestSelectionOutcome;

final class const PullRequestSelectionIdentityChanged() extends PullRequestSelectionOutcome;

sealed class const PullRequestTargetSelection({required final PullRequestSelectionTarget target});

final class const PullRequestTargetSelected({
  required super.target,
  required final int number,
  required final String url,
  required final String title,
  required final DateTime createdAt,
  required final PrState state,
  required final PrMergeableStatus mergeableStatus,
  required final PrReviewDecision reviewDecision,
  required final PrCheckStatus checkStatus,
}) extends PullRequestTargetSelection;

final class const PullRequestTargetUnmatched({required super.target}) extends PullRequestTargetSelection;
