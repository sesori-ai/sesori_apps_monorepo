import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_refresh_settings.freezed.dart";
part "pull_request_refresh_settings.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestRefreshSettingsRequest with _$PullRequestRefreshSettingsRequest {
  const factory PullRequestRefreshSettingsRequest({
    @JsonKey(fromJson: _strictIntFromJson) required int intervalSeconds,
  }) = _PullRequestRefreshSettingsRequest;

  factory PullRequestRefreshSettingsRequest.fromJson(Map<String, dynamic> json) =>
      _$PullRequestRefreshSettingsRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestRefreshSettingsResponse with _$PullRequestRefreshSettingsResponse {
  const factory PullRequestRefreshSettingsResponse({
    required int intervalSeconds,
  }) = _PullRequestRefreshSettingsResponse;

  factory PullRequestRefreshSettingsResponse.fromJson(Map<String, dynamic> json) =>
      _$PullRequestRefreshSettingsResponseFromJson(json);
}

enum PullRequestRefreshSettingsErrorCode { intervalOutOfRange, unknown }

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestRefreshSettingsErrorResponse with _$PullRequestRefreshSettingsErrorResponse {
  const factory PullRequestRefreshSettingsErrorResponse({
    @JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown)
    required PullRequestRefreshSettingsErrorCode code,
    required int minimumIntervalSeconds,
    required int maximumIntervalSeconds,
  }) = _PullRequestRefreshSettingsErrorResponse;

  factory PullRequestRefreshSettingsErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$PullRequestRefreshSettingsErrorResponseFromJson(json);
}

int _strictIntFromJson(num value) {
  if (value is int) return value;
  throw const FormatException("Expected an integer");
}
