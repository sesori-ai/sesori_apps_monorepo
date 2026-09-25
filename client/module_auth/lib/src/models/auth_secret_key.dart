import "package:sesori_persistence/sesori_persistence.dart";

/// Persisted spellings are stable; enum names are not the storage contract.
enum AuthSecretKey({@override required final String storageKey}) implements SecretStorageKey {
  accessToken(storageKey: "access_token"),
  refreshToken(storageKey: "refresh_token"),
  user(storageKey: "auth_user"),
  pkceVerifier(storageKey: "pkce_verifier"),
  oauthProvider(storageKey: "oauth_provider"),
  oauthSessionToken(storageKey: "oauth_session_token"),
  oauthSessionExpiry(storageKey: "oauth_session_expiry"),
}
