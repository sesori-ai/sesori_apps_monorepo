import "package:sesori_shared/sesori_shared.dart";

typedef PullRequestSelectionTarget = ({
  String githubRepositoryIdentity,
  String branchName,
});

sealed class const PullRequestSelectionOutcome();

final class const PullRequestSelectionCompleted({required this.selections}) extends PullRequestSelectionOutcome {
  final List<PullRequestTargetSelection> selections;
}

final class const PullRequestSelectionIdentityChanged() extends PullRequestSelectionOutcome;

sealed class const PullRequestTargetSelection({required this.target}) {
  final PullRequestSelectionTarget target;
}

final class const PullRequestTargetSelected({
    required super.target,
    required this.number,
    required this.url,
    required this.title,
    required this.createdAt,
    required this.state,
    required this.mergeableStatus,
    required this.reviewDecision,
    required this.checkStatus,
  }) extends PullRequestTargetSelection {
  final int number;
  final String url;
  final String title;
  final DateTime createdAt;
  final PrState state;
  final PrMergeableStatus mergeableStatus;
  final PrReviewDecision reviewDecision;
  final PrCheckStatus checkStatus;
}

final class const PullRequestTargetUnmatched({required super.target}) extends PullRequestTargetSelection;
