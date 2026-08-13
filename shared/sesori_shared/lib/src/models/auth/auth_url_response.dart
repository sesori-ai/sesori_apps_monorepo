import "package:freezed_annotation/freezed_annotation.dart";

part "auth_url_response.freezed.dart";
part "auth_url_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class AuthUrlResponse with _$AuthUrlResponse {
  const factory({
    required String authUrl,
    required String state,
  }) = _AuthUrlResponse;

  factory fromJson(Map<String, dynamic> json) => _$AuthUrlResponseFromJson(json);
}
