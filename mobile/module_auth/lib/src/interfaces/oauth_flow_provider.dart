import "package:sesori_shared/sesori_shared.dart";

/// Drives the OAuth authorization flow through the auth-server session flow.
///
/// The auth server owns provider redirects and PKCE. Callers open the returned
/// [AuthInitResponse.authUrl], display [AuthInitResponse.userCode], then wait
/// for [pollForResult] to complete after the browser confirmation step.
abstract interface class OAuthFlowProvider {
  /// Starts an auth-server backed OAuth session for [provider].
  Future<AuthInitResponse> startOAuthFlow({required OAuthProvider provider});

  /// Polls the auth server until the pending OAuth session reaches a terminal result.
  Future<AuthUser> pollForResult();
}
