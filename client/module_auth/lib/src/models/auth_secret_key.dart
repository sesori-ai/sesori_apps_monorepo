import "package:sesori_persistence/sesori_persistence.dart";

/// Persisted spellings are stable; enum names are not the storage contract.
enum AuthSecretKey({@override required final String storageKey}) implements SecretStorageKey {
  accessToken(storageKey: "access_token"),
  refreshToken(storageKey: "refresh_token"),
  user(storageKey: "auth_user"),
  // COMPATIBILITY 2026-11-02 (v1.12.0): released app builds (app-v1.0.5,
  // app-v1.0.6) wrote these two keys; nothing reads them now. The deprecated
  // native-storage v1 importer still copies them and logout still clears them.
  // Remove both keys and their clear calls when that importer retires.
  pkceVerifier(storageKey: "pkce_verifier"),
  oauthProvider(storageKey: "oauth_provider"),
  oauthSessionToken(storageKey: "oauth_session_token"),
  oauthSessionExpiry(storageKey: "oauth_session_expiry"),
  lastSignInProvider(storageKey: "last_sign_in_provider"),
}
