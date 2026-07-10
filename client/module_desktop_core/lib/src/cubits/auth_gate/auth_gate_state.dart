import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "auth_gate_state.freezed.dart";

/// Signed-in/out truth for the desktop app surfaces (window, later tray).
@Freezed()
sealed class AuthGateState with _$AuthGateState {
  /// Local session restore has not finished yet — render a neutral splash,
  /// not the login view (avoids a login flash for returning users).
  const factory AuthGateState.checking() = AuthGateChecking;

  const factory AuthGateState.signedOut() = AuthGateSignedOut;

  const factory AuthGateState.signedIn({required AuthUser user}) = AuthGateSignedIn;
}
