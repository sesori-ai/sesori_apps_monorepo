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
  final AuthSession _authSession = authSession;
  final ConnectionService _connectionService = connectionService;

  /// Starts the relay connection once the signed-in desktop destination is
  /// visible. The auth-state check makes a destination transition racing a
  /// logout harmless, while allowing the provisional token-only state.
  Future<void> connectForAuthenticatedDestination() async {
    switch (_authSession.currentState) {
      case AuthAuthenticated():
        await _connectionService.connectWithFreshAuthToken();
      case AuthInitial():
        final bool hasLocalSession;
        try {
          hasLocalSession = await _authSession.hasLocallyValidSession();
        } on Object catch (error, stackTrace) {
          logw("Failed to verify the provisional desktop session before relay startup", error, stackTrace);
          return;
        }
        if (!hasLocalSession) return;
        switch (_authSession.currentState) {
          case AuthInitial() || AuthAuthenticated():
            await _connectionService.connectWithFreshAuthToken();
          case AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
            return;
        }
      case AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
        return;
    }
  }
}
