/// Thrown when token refresh fails.
class TokenRefreshException implements Exception {
  final String reason;
  const TokenRefreshException(this.reason);
  @override
  String toString() => "TokenRefreshException: $reason";
}
