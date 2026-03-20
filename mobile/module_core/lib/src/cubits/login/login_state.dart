import "package:freezed_annotation/freezed_annotation.dart";

part "login_state.freezed.dart";

@Freezed()
sealed class LoginState with _$LoginState {
  const factory LoginState.idle() = LoginIdle;

  const factory LoginState.authenticating() = LoginAuthenticating;

  const factory LoginState.awaitingCallback() = LoginAwaitingCallback;

  const factory LoginState.failed({required String error}) = LoginFailed;
}
