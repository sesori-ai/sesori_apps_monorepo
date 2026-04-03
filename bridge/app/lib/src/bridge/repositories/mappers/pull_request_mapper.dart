import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/tables/pull_requests_table.dart";
import "../models/pull_request_record.dart";

PullRequestRecord pullRequestRecordFromDto(PullRequestDto dto) {
  return PullRequestRecord(
    projectId: dto.projectId,
    prNumber: dto.prNumber,
    branchName: dto.branchName,
    url: dto.url,
    title: dto.title,
    state: dto.state,
    mergeableStatus: dto.mergeableStatus,
    reviewDecision: dto.reviewDecision,
    checkStatus: dto.checkStatus,
    lastCheckedAt: dto.lastCheckedAt,
    createdAt: dto.createdAt,
  );
}

PullRequestInfo pullRequestInfoFromDto(PullRequestDto dto) {
  return PullRequestInfo(
    number: dto.prNumber,
    url: dto.url,
    title: dto.title,
    state: _stringToPrState(dto.state),
    mergeableStatus: _stringToPrMergeableStatus(dto.mergeableStatus),
    reviewDecision: _stringToPrReviewDecision(dto.reviewDecision),
    checkStatus: _stringToPrCheckStatus(dto.checkStatus),
  );
}

PrState _stringToPrState(String? value) {
  if (value == null) return PrState.unknown;
  return switch (value.toUpperCase()) {
    "OPEN" => PrState.open,
    "CLOSED" => PrState.closed,
    "MERGED" => PrState.merged,
    _ => PrState.unknown,
  };
}

PrMergeableStatus _stringToPrMergeableStatus(String? value) {
  if (value == null) return PrMergeableStatus.unknown;
  return switch (value.toUpperCase()) {
    "MERGEABLE" => PrMergeableStatus.mergeable,
    "CONFLICTED" => PrMergeableStatus.conflicted,
    "UNKNOWN" => PrMergeableStatus.unknown,
    _ => PrMergeableStatus.unknown,
  };
}

PrReviewDecision _stringToPrReviewDecision(String? value) {
  if (value == null) return PrReviewDecision.unknown;
  return switch (value.toUpperCase()) {
    "APPROVED" => PrReviewDecision.approved,
    "CHANGES_REQUESTED" => PrReviewDecision.changesRequested,
    "REVIEW_REQUIRED" => PrReviewDecision.reviewRequired,
    _ => PrReviewDecision.unknown,
  };
}

PrCheckStatus _stringToPrCheckStatus(String? value) {
  if (value == null) return PrCheckStatus.unknown;
  return switch (value.toUpperCase()) {
    "SUCCESS" => PrCheckStatus.success,
    "FAILURE" => PrCheckStatus.failure,
    "PENDING" => PrCheckStatus.pending,
    _ => PrCheckStatus.unknown,
  };
}
