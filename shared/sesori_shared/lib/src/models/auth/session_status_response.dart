import "package:freezed_annotation/freezed_annotation.dart";

import "account_status.dart";
import "auth_user.dart";

part "session_status_response.freezed.dart";
part "session_status_response.g.dart";

@Freezed(unionKey: "status", fromJson: true, toJson: true)
sealed class AuthSessionStatusResponse with _$AuthSessionStatusResponse {
  @FreezedUnionValue("pending")
  const factory pending() = AuthSessionStatusResponsePending;

  @FreezedUnionValue("complete")
  const factory complete({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
    @JsonKey(unknownEnumValue: AccountStatus.unknown) required AccountStatus accountStatus,
  }) = AuthSessionStatusResponseComplete;

  @FreezedUnionValue("denied")
  const factory denied() = AuthSessionStatusResponseDenied;

  @FreezedUnionValue("expired")
  const factory expired() = AuthSessionStatusResponseExpired;

  @FreezedUnionValue("error")
  const factory error({
    required String message,
  }) = AuthSessionStatusResponseError;

  factory fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseFromJson(json);
}
