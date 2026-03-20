import "package:freezed_annotation/freezed_annotation.dart";

part "auth_url_response.freezed.dart";
part "auth_url_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class AuthUrlResponse with _$AuthUrlResponse {
  const factory AuthUrlResponse({
    required String authUrl,
    required String state,
  }) = _AuthUrlResponse;

  factory AuthUrlResponse.fromJson(Map<String, dynamic> json) => _$AuthUrlResponseFromJson(json);
}
