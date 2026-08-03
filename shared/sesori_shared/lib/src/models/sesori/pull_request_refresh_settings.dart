import "package:freezed_annotation/freezed_annotation.dart";

import "../../converters/strict_int_json_converter.dart";

part "pull_request_refresh_settings.freezed.dart";
part "pull_request_refresh_settings.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestRefreshSettingsResponse with _$PullRequestRefreshSettingsResponse {
  const factory PullRequestRefreshSettingsResponse({
    @strictIntJsonConverter required int intervalSeconds,
  }) = _PullRequestRefreshSettingsResponse;

  factory PullRequestRefreshSettingsResponse.fromJson(Map<String, dynamic> json) =>
      _$PullRequestRefreshSettingsResponseFromJson(json);
}
