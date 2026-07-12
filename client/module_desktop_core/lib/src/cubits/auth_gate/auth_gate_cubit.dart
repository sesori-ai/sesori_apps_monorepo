import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
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
  AuthGateCubit(
    AuthSession authSession, {
    @visibleForTesting Duration signOutRestoreFence = const Duration(seconds: 5),
  }) : _authSession = authSession,
       _signOutRestoreFence = signOutRestoreFence,
       super(const AuthGateState.checking()) {
    unawaited(_restoreAndSubscribe());
  }

  final AuthSession _authSession;
  final Duration _signOutRestoreFence;
  StreamSubscription<AuthState>? _subscription;
  Future<void>? _backgroundRestore;

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
    // the state to a full signedIn(user) when it completes. The future is
    // kept so signOut() can fence on it.
    final Future<void> restore = _recoverUserInBackground();
    _backgroundRestore = restore;
    await restore;
    _backgroundRestore = null;
  }

  Future<void> _recoverUserInBackground() async {
    try {
      final bool restored = await _authSession.restoreSession();
      if (!restored) {
        // Deliberately stay provisionally signed in: an unreachable auth
        // server must not log the user out. A server-REJECTED (revoked)
        // token also lands here because the auth layer cannot yet
        // distinguish the two cases; until it can, the user resolves a
        // genuinely dead session by signing out.
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
    // Fence on the startup user recovery: its /auth/me completion re-emits
    // authenticated, which must land BEFORE logout's unauthenticated — never
    // after, or a signed-out user would be flipped back to signed in.
    final Future<void>? pending = _backgroundRestore;
    if (pending != null) {
      try {
        await pending.timeout(_signOutRestoreFence);
      } on TimeoutException {
        // Pathologically slow restore: proceed with the sign-out rather than
        // blocking the user — but the hung restore can still re-emit
        // authenticated when it finally lands, so re-run the local logout
        // after it settles: sign-out always wins eventually.
        logw("Background session restore still pending at sign-out; re-clearing when it settles");
        // Deliberately UNCONDITIONAL: the settling restore's own token
        // refresh can re-persist tokens after the logout, and the auth layer
        // has no logout generation, so no local check can distinguish them
        // from a fresh sign-in. A fresh sign-in completing inside this
        // pathological window is bounced once — visible and recoverable —
        // which beats a silently undone sign-out.
        unawaited(pending.whenComplete(_clearSessionBestEffort));
      }
    }
    await _clearSessionBestEffort();
  }

  Future<void> _clearSessionBestEffort() async {
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
