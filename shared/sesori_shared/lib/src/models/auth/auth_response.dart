import "package:freezed_annotation/freezed_annotation.dart";
import "auth_user.dart";

part "auth_response.freezed.dart";
part "auth_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}
