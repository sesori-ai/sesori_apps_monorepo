import "package:freezed_annotation/freezed_annotation.dart";

part "auth_init_response.freezed.dart";
part "auth_init_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class AuthInitResponse with _$AuthInitResponse {
  const factory AuthInitResponse({
    required String authUrl,
    required String state,
    required String userCode,
    required int expiresIn,
  }) = _AuthInitResponse;

  factory AuthInitResponse.fromJson(Map<String, dynamic> json) => _$AuthInitResponseFromJson(json);
}
