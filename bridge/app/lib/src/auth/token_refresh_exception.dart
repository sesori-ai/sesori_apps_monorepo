/// Thrown when token refresh fails.
class const TokenRefreshException({
  required final String reason,
  final int? statusCode,
}) implements Exception {
  @override
  String toString() => "TokenRefreshException: $reason";
}
