import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../orchestration/desktop_logout_orchestrator.dart";
import "../../services/desktop_relay_connection_service.dart";
import "auth_gate_state.dart";

/// Desktop sign-in gate: maps the auth session's state stream into the
/// signed-in/out truth the desktop window and bridge-spawn auth gating render.
///
/// On construction it restores a locally persisted session (local-only, no
/// network — the startup posture mobile's splash uses), then tracks live
/// transitions. Mid-login states do not flip the gate: the login surface owns
/// its own progress UI.
class AuthGateCubit._create({
  required final AuthSession _authSession,
  required final DesktopLogoutOrchestrator _logoutOrchestrator,
  required final DesktopRelayConnectionService _relayConnectionService,
}) extends Cubit<AuthGateState> {
  new({
    required AuthSession authSession,
    required DesktopLogoutOrchestrator logoutOrchestrator,
    required DesktopRelayConnectionService relayConnectionService,
  }) : this._create(
         authSession: authSession,
         logoutOrchestrator: logoutOrchestrator,
         relayConnectionService: relayConnectionService,
       );

  this : super(const AuthGateState.checking()) {
    unawaited(_restoreAndSubscribe());
  }

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
    // the state to a full signedIn(user) when it completes. AuthManager owns
    // the logout generation that prevents a late result from re-authenticating.
    await _recoverUserInBackground();
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

  /// Starts the relay once the signed-in destination is visible.
  ///
  /// This is deliberately separate from local startup restoration: the gate
  /// remains local-only and the relay coordinator owns the transport command.
  Future<void> onSignedInDestinationReady() {
    return _relayConnectionService.connectForAuthenticatedDestination();
  }

  /// Coordinated device-local sign-out. The logout owner stops the supervised
  /// helper before clearing local tokens; step 11 extends that same owner with
  /// unregister handling. AuthManager fences every in-flight auth result.
  Future<void> signOut() async {
    await _logoutBestEffort();
  }

  Future<void> _logoutBestEffort() async {
    await _logoutOrchestrator.logoutCurrentDevice();
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
    return await super.close();
  }
}
