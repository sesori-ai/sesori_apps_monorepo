import "package:freezed_annotation/freezed_annotation.dart";

import "account_status.dart";
import "auth_user.dart";

part "auth_login_response.freezed.dart";
part "auth_login_response.g.dart";

/// Token response returned only by interactive authentication endpoints.
@Freezed(fromJson: true, toJson: false)
sealed class AuthLoginResponse with _$AuthLoginResponse {
  const factory({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
    @JsonKey(unknownEnumValue: AccountStatus.unknown) required AccountStatus accountStatus,
  }) = _AuthLoginResponse;

  factory fromJson(Map<String, dynamic> json) => _$AuthLoginResponseFromJson(json);
}
