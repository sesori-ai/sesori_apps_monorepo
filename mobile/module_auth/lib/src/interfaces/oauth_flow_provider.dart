import "package:sesori_shared/sesori_shared.dart";
import "../auth_config.dart";

/// Drives the OAuth authorization flow (PKCE + code exchange).
///
/// PKCE verifier generation, storage, and retrieval are fully
/// encapsulated — callers never touch cryptographic details.
abstract interface class OAuthFlowProvider {
  /// Generates a PKCE verifier, stores it along with [provider],
  /// and returns the authorization URL to open in a browser.
  Future<String> getAuthorizationUrl(OAuthProvider provider, String redirectUri);

  /// Completes the OAuth flow: reads the stored PKCE verifier and
  /// provider, exchanges [code] for tokens, persists them, and
  /// returns the authenticated user.
  Future<AuthUser> exchangeCode({
    required String code,
    required String state,
    required String redirectUri,
  });
}
