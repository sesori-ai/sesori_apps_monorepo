import "package:sesori_shared/sesori_shared.dart";

/// Converts a string state value to PrState enum.
PrState stringToPrState(String? value) {
  if (value == null) return PrState.unknown;
  return switch (value.toUpperCase()) {
    "OPEN" => PrState.open,
    "CLOSED" => PrState.closed,
    "MERGED" => PrState.merged,
    _ => PrState.unknown,
  };
}

/// Converts a string mergeable status value to PrMergeableStatus enum.
PrMergeableStatus stringToPrMergeableStatus(String? value) {
  if (value == null) return PrMergeableStatus.unknown;
  return switch (value.toUpperCase()) {
    "MERGEABLE" => PrMergeableStatus.mergeable,
    "CONFLICTED" => PrMergeableStatus.conflicted,
    "UNKNOWN" => PrMergeableStatus.unknown,
    _ => PrMergeableStatus.unknown,
  };
}

/// Converts a string review decision value to PrReviewDecision enum.
PrReviewDecision stringToPrReviewDecision(String? value) {
  if (value == null) return PrReviewDecision.unknown;
  return switch (value.toUpperCase()) {
    "APPROVED" => PrReviewDecision.approved,
    "CHANGES_REQUESTED" => PrReviewDecision.changesRequested,
    "REVIEW_REQUIRED" => PrReviewDecision.reviewRequired,
    _ => PrReviewDecision.unknown,
  };
}

/// Converts a string check status value to PrCheckStatus enum.
PrCheckStatus stringToPrCheckStatus(String? value) {
  if (value == null) return PrCheckStatus.unknown;
  return switch (value.toUpperCase()) {
    "SUCCESS" => PrCheckStatus.success,
    "FAILURE" => PrCheckStatus.failure,
    "PENDING" => PrCheckStatus.pending,
    _ => PrCheckStatus.unknown,
  };
}
