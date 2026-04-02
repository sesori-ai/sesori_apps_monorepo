import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_info.freezed.dart";
part "pull_request_info.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestInfo with _$PullRequestInfo {
  const factory PullRequestInfo({
    required int number,
    required String url,
    required String title,
    required String state,
    required String? mergeableStatus,
    required String? reviewDecision,
    required String? checkStatus,
  }) = _PullRequestInfo;

  factory PullRequestInfo.fromJson(Map<String, dynamic> json) => _$PullRequestInfoFromJson(json);
}
