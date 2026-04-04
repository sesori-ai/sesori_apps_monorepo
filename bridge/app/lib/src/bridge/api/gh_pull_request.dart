import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "gh_pull_request.freezed.dart";
part "gh_pull_request.g.dart";

/// Parses the statusCheckRollup field from gh CLI output.
///
/// gh returns one of:
/// - A simple string like "SUCCESS"
/// - A map with a "state" or "conclusion" key
/// - A list of CheckRun/StatusContext objects, each with "status"+"conclusion"
/// - null when no checks are configured
PrCheckStatus _prCheckStatusFromRollup(Object? value) {
  return switch (value) {
    null => PrCheckStatus.none,
    final String s => _prCheckStatusFromString(s),
    final Map<String, dynamic> m => _prCheckStatusFromString(
      m["state"]?.toString() ?? m["conclusion"]?.toString(),
    ),
    final List<dynamic> checks => _aggregateCheckStatuses(checks),
    _ => PrCheckStatus.unknown,
  };
}

/// Aggregates a list of CheckRun/StatusContext objects into a single status.
/// Logic matches gh CLI source (queries_pr.go):
/// - Any failure → failure
/// - Any pending (and no failures) → pending
/// - All passing → success
/// - Empty list / no checks configured → none
PrCheckStatus _aggregateCheckStatuses(List<dynamic> checks) {
  if (checks.isEmpty) return PrCheckStatus.none;

  var hasPending = false;
  var hasAnyValid = false;
  for (final check in checks) {
    if (check is! Map<String, dynamic>) continue;
    hasAnyValid = true;

    final typeName = check["__typename"]?.toString();
    final status = check["status"]?.toString().toUpperCase();
    final conclusion = check["conclusion"]?.toString().toUpperCase();
    final state = check["state"]?.toString().toUpperCase();

    if (typeName == "StatusContext") {
      // StatusContext uses "state" field: SUCCESS, FAILURE, ERROR, PENDING, EXPECTED
      final result = _prCheckStatusFromString(state);
      if (result == PrCheckStatus.failure) return PrCheckStatus.failure;
      if (result != PrCheckStatus.success) hasPending = true;
    } else {
      // CheckRun uses "status" + "conclusion" fields
      if (status == "COMPLETED") {
        final result = _prCheckStatusFromString(conclusion);
        if (result == PrCheckStatus.failure) return PrCheckStatus.failure;
        if (result != PrCheckStatus.success) hasPending = true;
      } else {
        hasPending = true;
      }
    }
  }

  if (!hasAnyValid) return PrCheckStatus.unknown;
  return hasPending ? PrCheckStatus.pending : PrCheckStatus.success;
}

PrState _prStateFromString(String? value) {
  if (value == null || value.isEmpty) return PrState.unknown;
  return switch (value.toUpperCase()) {
    "OPEN" => PrState.open,
    "CLOSED" => PrState.closed,
    "MERGED" => PrState.merged,
    _ => PrState.unknown,
  };
}

PrMergeableStatus _prMergeableStatusFromString(String? value) {
  if (value == null || value.isEmpty) return PrMergeableStatus.unknown;
  return switch (value.toUpperCase()) {
    "MERGEABLE" => PrMergeableStatus.mergeable,
    "CONFLICTED" || "CONFLICTING" => PrMergeableStatus.conflicting,
    _ => PrMergeableStatus.unknown,
  };
}

PrReviewDecision _prReviewDecisionFromString(String? value) {
  if (value == null || value.isEmpty) return PrReviewDecision.unknown;
  return switch (value.toUpperCase()) {
    "APPROVED" => PrReviewDecision.approved,
    "CHANGES_REQUESTED" => PrReviewDecision.changesRequested,
    "REVIEW_REQUIRED" => PrReviewDecision.reviewRequired,
    _ => PrReviewDecision.unknown,
  };
}

PrCheckStatus _prCheckStatusFromString(String? value) {
  if (value == null || value.isEmpty) return PrCheckStatus.unknown;
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
  PrCheckStatus.none => "NONE",
  PrCheckStatus.unknown => null,
};
