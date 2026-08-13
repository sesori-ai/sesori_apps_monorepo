import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "auth_state.freezed.dart";

@Freezed()
sealed class AuthState with _$AuthState {
  const factory initial() = AuthInitial;
  const factory unauthenticated() = AuthUnauthenticated;
  const factory authenticating() = AuthAuthenticating;
  const factory authenticated({required AuthUser user}) = AuthAuthenticated;
  const factory failed({required String error}) = AuthFailed;
}
