/// Thrown when token refresh fails.
class const TokenRefreshException(final String reason) implements Exception {
  @override
  String toString() => "TokenRefreshException: $reason";
}
