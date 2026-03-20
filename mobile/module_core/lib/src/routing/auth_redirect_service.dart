import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/relay/relay_config.dart";
import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/server_connection_config.dart";
import "../logging/logging.dart";
import "app_routes.dart";

/// Handles auth-related routing decisions for [appRouter]'s redirect.
///
/// Encapsulates OAuth deep link handling and session restore logic so
/// the router config itself stays free of direct service resolution.
@lazySingleton
class AuthRedirectService {
  final OAuthFlowProvider _oAuthFlowProvider;
  final AuthSession _authSession;
  final AuthTokenProvider _authTokenProvider;
  final ConnectionService _connectionService;

  AuthRedirectService(
    OAuthFlowProvider oAuthFlowProvider,
    AuthSession authSession,
    AuthTokenProvider authTokenProvider,
    ConnectionService connectionService,
  ) : _oAuthFlowProvider = oAuthFlowProvider,
      _authSession = authSession,
      _authTokenProvider = authTokenProvider,
      _connectionService = connectionService;

  /// Exchanges an OAuth authorization code from a deep link callback
  /// and returns the route to navigate to.
  Future<AppRoute?> handleOAuthCallback(Uri uri) async {
    try {
      final code = uri.queryParameters["code"];
      final callbackState = uri.queryParameters["state"];

      if (code == null || callbackState == null || code.isEmpty || callbackState.isEmpty) {
        loge("OAuth callback missing code or state params");
        return AppRoute.login;
      }

      logd("Exchanging OAuth code for tokens");

      await _oAuthFlowProvider.exchangeCode(code: code, state: callbackState, redirectUri: redirectUri);
      await _autoConnectToRelay();

      logd("Login successful — navigating to projects");
      return AppRoute.projects;
    } catch (e, st) {
      loge("OAuth code exchange failed", e, st);
      return AppRoute.login;
    }
  }

  /// Checks for stored tokens and tries to restore a previous session,
  /// returning [AppRoute.projects] to skip login if successful.
  Future<AppRoute?> tryRestoreSession() async {
    final user = await _authSession.getCurrentUser();
    if (user != null) {
      logd("Session restored for ${user.providerUsername ?? user.id} — auto-connecting to relay");
      await _autoConnectToRelay();
      return AppRoute.projects;
    }

    return null;
  }

  Future<void> _autoConnectToRelay() async {
    try {
      final accessToken = await _authTokenProvider.getFreshAccessToken(minTtl: const Duration(minutes: 2));
      if (accessToken == null) {
        loge("Auto-connect to relay failed: no valid token");
        return;
      }
      final config = ServerConnectionConfig(relayHost: relayHost, authToken: accessToken);
      await _connectionService.connect(config);
    } catch (e, st) {
      loge("Auto-connect to relay failed", e, st);
    }
  }
}
