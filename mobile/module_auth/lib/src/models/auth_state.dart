import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "auth_state.freezed.dart";

@Freezed()
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.authenticating() = AuthAuthenticating;
  const factory AuthState.authenticated({required AuthUser user}) = AuthAuthenticated;
  const factory AuthState.failed({required String error}) = AuthFailed;
}
