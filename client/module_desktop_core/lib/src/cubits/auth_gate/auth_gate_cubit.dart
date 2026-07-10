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
    bool hasLocalSession = false;
    try {
      hasLocalSession = await _authSession.hasLocallyValidSession();
      if (hasLocalSession) {
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

    final AuthState current = _authSession.currentState;
    final bool tokenOnlySession = hasLocalSession && current is AuthInitial;
    if (tokenOnlySession) {
      // Valid tokens but no cached user record (a prior best-effort user
      // save failed), so the local restore could not emit: the session is
      // still signed in — forcing a re-login would discard working
      // credentials. Gate on the tokens (mobile's startup posture) BEFORE
      // subscribing, so a replayed `initial` from the stream can never flash
      // the login view for a returning user.
      emit(const AuthGateState.signedIn(user: null));
    }

    _subscription = _authSession.authStateStream.listen(_onAuthState);

    if (!tokenOnlySession) {
      _onAuthState(current);
      return;
    }

    // Recover the account details in the background; the auth stream upgrades
    // the state to a full signedIn(user) when it completes.
    try {
      final bool restored = await _authSession.restoreSession();
      if (!restored) {
        // Deliberately stay provisionally signed in: an unreachable auth
        // server must not log the user out; genuinely dead credentials
        // surface as an unauthenticated stream event on first real use.
        logw("Background session restore could not confirm the user; staying provisionally signed in");
      }
    } on Object catch (error, stackTrace) {
      // Same posture as the unconfirmed case above.
      logw("Background session restore failed", error, stackTrace);
    }
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
