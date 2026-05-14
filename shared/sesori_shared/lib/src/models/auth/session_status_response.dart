import "package:freezed_annotation/freezed_annotation.dart";

import "auth_user.dart";

part "session_status_response.freezed.dart";
part "session_status_response.g.dart";

@Freezed(unionKey: "status", fromJson: true, toJson: true)
sealed class AuthSessionStatusResponse with _$AuthSessionStatusResponse {
  @FreezedUnionValue("pending")
  const factory AuthSessionStatusResponse.pending() = AuthSessionStatusResponsePending;

  @FreezedUnionValue("complete")
  const factory AuthSessionStatusResponse.complete({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
  }) = AuthSessionStatusResponseComplete;

  @FreezedUnionValue("denied")
  const factory AuthSessionStatusResponse.denied() = AuthSessionStatusResponseDenied;

  @FreezedUnionValue("expired")
  const factory AuthSessionStatusResponse.expired() = AuthSessionStatusResponseExpired;

  @FreezedUnionValue("error")
  const factory AuthSessionStatusResponse.error({
    required String message,
  }) = AuthSessionStatusResponseError;

  factory AuthSessionStatusResponse.fromJson(Map<String, dynamic> json) => _$AuthSessionStatusResponseFromJson(json);
}
