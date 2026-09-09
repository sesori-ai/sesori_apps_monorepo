import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Layer-3 owner of the desktop destination's auth-to-relay startup handoff.
///
/// [ConnectionService] normally starts from an `AuthAuthenticated` emission.
/// A token-only local restore deliberately keeps the auth session in
/// `AuthInitial` while the desktop gate is already provisionally signed in, so
/// the signed-in destination needs an explicit lifecycle handoff. Keeping that
/// policy here prevents the presentation-only connection overlay cubit from
/// issuing transport commands.
@lazySingleton
class DesktopRelayConnectionService({
  required AuthSession authSession,
  required ConnectionService connectionService,
}) {
  static const Duration _reconnectTimeout = Duration(seconds: 15);

  final AuthSession _authSession = authSession;
  final ConnectionService _connectionService = connectionService;

  /// Starts the relay connection once the signed-in desktop destination is
  /// visible. The auth-state check makes a destination transition racing a
  /// logout harmless, while allowing the provisional token-only state.
  Future<void> connectForAuthenticatedDestination() async {
    if (!await _hasAuthenticatedDestination()) {
      return;
    }
    await _connectionService.connectWithFreshAuthToken();
  }

  /// Re-establishes the authenticated desktop relay after supervised-helper
  /// recovery without exposing transport-state branching to the product shell.
  Future<void> recoverForAuthenticatedDestination() async {
    if (!await _hasAuthenticatedDestination()) {
      return;
    }
    if (_connectionService.currentStatus is ConnectionDisconnected) {
      await _connectionService.connectWithFreshAuthToken();
      return;
    }
    await _connectionService.reconnectAndAwaitOutcome(timeout: _reconnectTimeout);
  }

  Future<bool> _hasAuthenticatedDestination() async {
    switch (_authSession.currentState) {
      case AuthAuthenticated():
        return true;
      case AuthInitial():
        final bool hasLocalSession;
        try {
          hasLocalSession = await _authSession.hasLocallyValidSession();
        } on Object catch (error, stackTrace) {
          logw("Failed to verify the provisional desktop session before relay startup", error, stackTrace);
          return false;
        }
        if (!hasLocalSession) {
          return false;
        }
        return switch (_authSession.currentState) {
          AuthInitial() || AuthAuthenticated() => true,
          AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => false,
        };
      case AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
        return false;
    }
  }
}
