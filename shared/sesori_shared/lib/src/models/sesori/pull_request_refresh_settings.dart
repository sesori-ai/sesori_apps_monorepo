import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_refresh_settings.freezed.dart";
part "pull_request_refresh_settings.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestRefreshSettingsResponse with _$PullRequestRefreshSettingsResponse {
  const factory PullRequestRefreshSettingsResponse({
    @JsonKey(fromJson: _strictIntFromJson) required int intervalSeconds,
  }) = _PullRequestRefreshSettingsResponse;

  factory PullRequestRefreshSettingsResponse.fromJson(Map<String, dynamic> json) =>
      _$PullRequestRefreshSettingsResponseFromJson(json);
}

// ignore: no_slop_linter/prefer_specific_type, JSON converter input must validate the raw value
int _strictIntFromJson(Object? value) {
  if (value is int) return value;
  throw const FormatException("Expected an integer");
}
