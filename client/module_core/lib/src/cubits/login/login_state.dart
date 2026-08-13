import "package:freezed_annotation/freezed_annotation.dart";

import "login_failed_reason.dart";

part "login_state.freezed.dart";

@Freezed()
sealed class LoginState with _$LoginState {
  const factory idle() = LoginIdle;

  const factory authenticating() = LoginAuthenticating;

  const factory polling() = LoginPolling;

  const factory timeout() = LoginTimeout;

  const factory success() = LoginSuccess;

  const factory failed({required LoginFailedReason reason}) = LoginFailed;
}
