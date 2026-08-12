/// Thrown when token refresh fails.
class const TokenRefreshException(this.reason) implements Exception {
  final String reason;
  @override
  String toString() => "TokenRefreshException: $reason";
}
