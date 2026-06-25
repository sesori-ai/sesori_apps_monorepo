/// Read-only access to a fresh authentication token.
///
/// Consumers that need a raw token string (e.g. for WebSocket auth)
/// inject this interface. They cannot clear, refresh, or otherwise
/// control the token lifecycle.
abstract interface class AuthTokenProvider {
  /// Returns a valid access token, refreshing proactively if the
  /// remaining validity is less than [minTtl].
  ///
  /// Returns `null` when no valid token is available (user not
  /// authenticated or refresh failed).
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  });
}
