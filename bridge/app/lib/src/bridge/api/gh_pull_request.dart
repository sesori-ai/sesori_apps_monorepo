import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "gh_pull_request.freezed.dart";
part "gh_pull_request.g.dart";

PrCheckStatus _prCheckStatusFromRollup(Object? value) {
  final raw = switch (value) {
    null => null,
    final String stringValue => stringValue,
    final Map<String, dynamic> object => object["state"]?.toString() ?? object["conclusion"]?.toString(),
    _ => null,
  };
  return _prCheckStatusFromString(raw);
}

PrState _prStateFromString(String? value) {
  if (value == null) return PrState.unknown;
  return switch (value.toUpperCase()) {
    "OPEN" => PrState.open,
    "CLOSED" => PrState.closed,
    "MERGED" => PrState.merged,
    _ => PrState.unknown,
  };
}

PrMergeableStatus _prMergeableStatusFromString(String? value) {
  if (value == null) return PrMergeableStatus.unknown;
  return switch (value.toUpperCase()) {
    "MERGEABLE" => PrMergeableStatus.mergeable,
    "CONFLICTED" || "CONFLICTING" => PrMergeableStatus.conflicted,
    _ => PrMergeableStatus.unknown,
  };
}

PrReviewDecision _prReviewDecisionFromString(String? value) {
  if (value == null) return PrReviewDecision.unknown;
  return switch (value.toUpperCase()) {
    "APPROVED" => PrReviewDecision.approved,
    "CHANGES_REQUESTED" => PrReviewDecision.changesRequested,
    "REVIEW_REQUIRED" => PrReviewDecision.reviewRequired,
    _ => PrReviewDecision.unknown,
  };
}

PrCheckStatus _prCheckStatusFromString(String? value) {
  if (value == null) return PrCheckStatus.unknown;
  return switch (value.toUpperCase()) {
    "SUCCESS" || "NEUTRAL" || "SKIPPED" => PrCheckStatus.success,
    "FAILURE" ||
    "ERROR" ||
    "CANCELLED" ||
    "TIMED_OUT" ||
    "ACTION_REQUIRED" ||
    "STARTUP_FAILURE" => PrCheckStatus.failure,
    "PENDING" ||
    "IN_PROGRESS" ||
    "QUEUED" ||
    "WAITING" ||
    "REQUESTED" ||
    "EXPECTED" ||
    "STALE" => PrCheckStatus.pending,
    _ => PrCheckStatus.unknown,
  };
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequest with _$GhPullRequest {
  const factory GhPullRequest({
    required int number,
    required String url,
    required String title,
    @JsonKey(fromJson: _prStateFromString) required PrState state,
    required String headRefName,
    @Default(false) bool isCrossRepository,
    @JsonKey(fromJson: _prMergeableStatusFromString) required PrMergeableStatus mergeable,
    @JsonKey(fromJson: _prReviewDecisionFromString) required PrReviewDecision reviewDecision,
    @JsonKey(fromJson: _prCheckStatusFromRollup, toJson: _rollupStateToJson) required PrCheckStatus statusCheckRollup,
  }) = _GhPullRequest;

  factory GhPullRequest.fromJson(Map<String, dynamic> json) => _$GhPullRequestFromJson(json);
}

String? _rollupStateToJson(PrCheckStatus value) => switch (value) {
  PrCheckStatus.success => "SUCCESS",
  PrCheckStatus.failure => "FAILURE",
  PrCheckStatus.pending => "PENDING",
  PrCheckStatus.unknown => null,
};
