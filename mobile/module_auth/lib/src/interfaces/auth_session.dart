import "package:rxdart/streams.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../models/auth_state.dart";

/// Reactive view of the current authentication session.
///
/// Provides auth state observation and high-level session
/// operations (get user, invalidate sessions, local logout).
/// Cannot initiate login —
/// use [OAuthFlowProvider] for that.
abstract interface class AuthSession {
  /// Push-based stream of auth state changes. Late subscribers
  /// immediately receive the current value.
  ValueStream<AuthState> get authStateStream;

  /// Synchronous access to the current auth state.
  AuthState get currentState;

  /// Fetches the current user from the auth server.
  /// Returns `null` if not authenticated or on error.
  Future<AuthUser?> getCurrentUser();

  /// Invalidates all sessions across all devices by calling the auth server.
  /// On success, clears local tokens and emits unauthenticated.
  /// On failure, throws — local tokens are NOT cleared (the server-side
  /// sessions remain valid).
  Future<void> invalidateAllSessions();

  /// Checks for stored tokens and tries to restore a previous session.
  ///
  /// If valid tokens exist and the auth server confirms the user,
  /// emits [AuthState.authenticated] and returns `true`.
  /// Otherwise the state remains unchanged and returns `false`.
  Future<bool> restoreSession();

  /// Authenticates using email and password.
  /// Throws [Exception] on authentication failure (including 401).
  Future<AuthUser> loginWithEmail(String email, String password);

  /// Clears local tokens and emits unauthenticated.
  /// Does NOT call the auth server — other devices remain authenticated.
  /// Use for simple sign-out on this device.
  Future<void> logoutCurrentDevice();
}
