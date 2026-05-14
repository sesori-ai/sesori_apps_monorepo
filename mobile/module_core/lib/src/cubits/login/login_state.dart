import "package:freezed_annotation/freezed_annotation.dart";

import "login_failed_reason.dart";

part "login_state.freezed.dart";

@Freezed()
sealed class LoginState with _$LoginState {
  const factory LoginState.idle() = LoginIdle;

  const factory LoginState.authenticating() = LoginAuthenticating;

  const factory LoginState.awaitingConfirmation({required String userCode}) = LoginAwaitingConfirmation;

  const factory LoginState.polling() = LoginPolling;

  const factory LoginState.timeout() = LoginTimeout;

  const factory LoginState.success() = LoginSuccess;

  const factory LoginState.failed({required LoginFailedReason reason}) = LoginFailed;
}
