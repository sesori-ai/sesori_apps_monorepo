import "package:freezed_annotation/freezed_annotation.dart";

import "pr_enums.dart";

part "pull_request_info.freezed.dart";
part "pull_request_info.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestInfo with _$PullRequestInfo {
  const factory PullRequestInfo({
    required int number,
    required String url,
    required String title,
    @JsonKey(unknownEnumValue: PrState.unknown) required PrState state,
    @JsonKey(unknownEnumValue: PrMergeableStatus.unknown) required PrMergeableStatus mergeableStatus,
    @JsonKey(unknownEnumValue: PrReviewDecision.unknown) required PrReviewDecision reviewDecision,
    @JsonKey(unknownEnumValue: PrCheckStatus.unknown) required PrCheckStatus checkStatus,
  }) = _PullRequestInfo;

  factory PullRequestInfo.fromJson(Map<String, dynamic> json) => _$PullRequestInfoFromJson(json);
}
