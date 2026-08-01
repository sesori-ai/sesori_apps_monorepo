import "package:sesori_shared/sesori_shared.dart";

typedef PullRequestSelectionTarget = ({
  String githubRepositoryIdentity,
  String branchName,
});

sealed class PullRequestSelectionOutcome {
  const PullRequestSelectionOutcome();
}

final class PullRequestSelectionCompleted extends PullRequestSelectionOutcome {
  final List<PullRequestTargetSelection> selections;

  const PullRequestSelectionCompleted({required this.selections});
}

final class PullRequestSelectionIdentityChanged extends PullRequestSelectionOutcome {
  const PullRequestSelectionIdentityChanged();
}

sealed class PullRequestTargetSelection {
  final PullRequestSelectionTarget target;

  const PullRequestTargetSelection({required this.target});
}

final class PullRequestTargetSelected extends PullRequestTargetSelection {
  final int number;
  final String url;
  final String title;
  final DateTime createdAt;
  final PrState state;
  final PrMergeableStatus mergeableStatus;
  final PrReviewDecision reviewDecision;
  final PrCheckStatus checkStatus;

  const PullRequestTargetSelected({
    required super.target,
    required this.number,
    required this.url,
    required this.title,
    required this.createdAt,
    required this.state,
    required this.mergeableStatus,
    required this.reviewDecision,
    required this.checkStatus,
  });
}

final class PullRequestTargetUnmatched extends PullRequestTargetSelection {
  const PullRequestTargetUnmatched({required super.target});
}
