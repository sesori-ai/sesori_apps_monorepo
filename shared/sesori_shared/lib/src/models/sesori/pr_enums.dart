import "package:freezed_annotation/freezed_annotation.dart";

/// Pull request state enum with unknown fallback.
enum PrState {
  @JsonValue("OPEN")
  open,
  @JsonValue("CLOSED")
  closed,
  @JsonValue("MERGED")
  merged,
  unknown,
}

/// Pull request mergeable status enum with unknown fallback.
enum PrMergeableStatus {
  @JsonValue("MERGEABLE")
  mergeable,
  @JsonValue("CONFLICTING")
  conflicting,
  @JsonValue("UNKNOWN")
  unknown,
}

/// Pull request review decision enum with unknown fallback.
enum PrReviewDecision {
  @JsonValue("APPROVED")
  approved,
  @JsonValue("CHANGES_REQUESTED")
  changesRequested,
  @JsonValue("REVIEW_REQUIRED")
  reviewRequired,
  unknown,
}

/// Pull request check status enum with unknown fallback.
enum PrCheckStatus {
  @JsonValue("SUCCESS")
  success,
  @JsonValue("FAILURE")
  failure,
  @JsonValue("PENDING")
  pending,
  @JsonValue("NONE")
  none,
  unknown,
}
