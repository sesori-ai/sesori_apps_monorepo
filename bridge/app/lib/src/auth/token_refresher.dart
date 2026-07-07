abstract interface class TokenRefresher {
  Future<String> getAccessToken({bool forceRefresh = false});
}

/// The typed failure a [TokenRefresher] throws when it cannot supply any usable
/// access token and a relay reconnect must therefore be deferred rather than
/// proceeding from a stale/cached token. In supervised mode the GUI replied with
/// a null token (signed out / mid-login) or the control channel was unavailable;
/// the supervised refresher also invalidates its cache before throwing, so there
/// is no safe token to fall back on. Distinct from a transient refresh failure
/// (e.g. the standalone auth-refresh endpoint being momentarily down while a
/// valid cached token is still on hand), which callers may recover from by
/// reconnecting with the cached token.
class ControlTokenUnavailableException implements Exception {
  final String reason;
  const ControlTokenUnavailableException(this.reason);
  @override
  String toString() => "ControlTokenUnavailableException: $reason";
}
