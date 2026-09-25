import "package:sesori_shared/sesori_shared.dart";

import "../models/auth_login_result.dart";
import "../models/oauth_flow_errors.dart";
import "../models/oauth_handoff.dart";

/// Drives the OAuth authorization flow through the auth-server session flow.
///
/// The auth server owns provider redirects and PKCE. Callers open the returned
/// [OAuthHandoff.authUrl], then wait for [pollForResult] to complete after
/// the user confirms the sign-in on the auth-server page (which describes this
/// device).
abstract interface class OAuthFlowProvider() {
  /// Starts an auth-server backed OAuth session for [provider].
  Future<OAuthHandoff> startOAuthFlow({required OAuthProvider provider});

  /// Polls the auth server until the pending OAuth session reaches a terminal result.
  ///
  /// Throws [OAuthFlowDenied] or [OAuthFlowExpired] when the auth server
  /// reports that the user declined or the session expired.
  Future<AuthLoginResult> pollForResult();

  /// Resumes polling for an OAuth session that was previously started.
  ///
  /// Use this when the app was backgrounded and returned to the foreground
  /// while an OAuth flow is still active on the auth server.
  Future<AuthLoginResult> resumeOAuthFlow();

  /// Whether there is an active OAuth session that can be resumed.
  Future<bool> hasActiveOAuthSession();

  /// Abandons the OAuth flow that is current when this is called.
  ///
  /// A pending [pollForResult] for that flow ends as superseded and can no
  /// longer save tokens. A flow started after this call is left untouched.
  Future<void> cancelOAuthFlow();
}
