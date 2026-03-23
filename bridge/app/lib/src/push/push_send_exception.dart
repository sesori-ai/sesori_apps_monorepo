/// Thrown when a push notification fails to send.
class PushSendException implements Exception {
  final int statusCode;
  final bool isRetry;
  const PushSendException({required this.statusCode, this.isRetry = false});
  @override
  String toString() =>
      "PushSendException: notification ${isRetry ? "failed after retry" : "failed"} with status $statusCode";
}
