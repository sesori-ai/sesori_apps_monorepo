import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "auth_gate_state.dart";

/// Desktop sign-in gate: maps the auth session's state stream into the
/// signed-in/out truth the desktop window (and later the tray menu, logout
/// flow, and bridge-spawn auth gating) renders.
///
/// On construction it restores a locally persisted session (local-only, no
/// network — the startup posture mobile's splash uses), then tracks live
/// transitions. Mid-login states do not flip the gate: the login surface owns
/// its own progress UI.
class AuthGateCubit extends Cubit<AuthGateState> {
  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  AuthGateCubit(AuthSession authSession) : _authSession = authSession, super(const AuthGateState.checking()) {
    unawaited(_restoreAndSubscribe());
  }

  final AuthSession _authSession;
  StreamSubscription<AuthState>? _subscription;

  Future<void> _restoreAndSubscribe() async {
    try {
      if (await _authSession.hasLocallyValidSession()) {
        await _authSession.restoreLocalSession();
      }
    } on Object catch (error, stackTrace) {
      // Degrade to whatever the live stream says — worst case the user is
      // asked to sign in again.
      logw("Failed to restore the local auth session", error, stackTrace);
    }
    if (isClosed) {
      return;
    }
    _subscription = _authSession.authStateStream.listen(_onAuthState);
    _onAuthState(_authSession.currentState);
  }

  /// Device-local sign-out (clears local tokens only; other devices stay
  /// signed in). The coordinated bridge-unregister logout flow builds on top
  /// of this later.
  Future<void> signOut() async {
    try {
      await _authSession.logoutCurrentDevice();
    } on Object catch (error, stackTrace) {
      // Local-only operation; a failure leaves the session as-is and the gate
      // unchanged, so surface it in the log.
      logw("Device-local sign-out failed", error, stackTrace);
    }
  }

  void _onAuthState(AuthState authState) {
    final AuthGateState? next = switch (authState) {
      AuthAuthenticated(:final user) => AuthGateState.signedIn(user: user),
      AuthUnauthenticated() || AuthFailed() => const AuthGateState.signedOut(),
      // Never signed in on this device: only meaningful right after the
      // restore attempt; later `initial` emissions must not flip the gate.
      AuthInitial() => state is AuthGateChecking ? const AuthGateState.signedOut() : null,
      // Mid-login progress belongs to the login surface, not the gate.
      AuthAuthenticating() => null,
    };
    if (next != null) {
      emit(next);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
