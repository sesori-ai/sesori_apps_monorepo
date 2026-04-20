import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "app_routes.dart";

/// Single choke point for OAuth callback requests.
///
/// Parses the authorization code and state from the incoming deep link URI,
/// delegates the PKCE code exchange to [OAuthFlowProvider], and maps the
/// outcome to an [AppRoute]. Relay auto-connect is not handled here — that
/// responsibility lives on [ConnectionService], which reacts to the
/// [AuthAuthenticated] state emitted by a successful [OAuthFlowProvider.exchangeCode].
@lazySingleton
class OAuthCallbackDispatcher {
  final OAuthFlowProvider _oAuthFlowProvider;

  OAuthCallbackDispatcher(OAuthFlowProvider oAuthFlowProvider) : _oAuthFlowProvider = oAuthFlowProvider;

  /// Exchanges an OAuth authorization code from a deep link callback
  /// and returns the route to navigate to.
  Future<AppRoute?> handleOAuthCallback(Uri uri) async {
    try {
      final code = uri.queryParameters["code"];
      final callbackState = uri.queryParameters["state"];

      if (code == null || callbackState == null || code.isEmpty || callbackState.isEmpty) {
        loge("OAuth callback missing code or state params");
        return const AppRoute.login();
      }

      logd("Exchanging OAuth code for tokens");

      await _oAuthFlowProvider.exchangeCode(code: code, state: callbackState, redirectUri: redirectUri);

      logd("Login successful — navigating to projects");
      return const AppRoute.projects();
    } catch (e, st) {
      loge("OAuth code exchange failed", e, st);
      return const AppRoute.login();
    }
  }
}
