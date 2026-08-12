/// Thrown when a push notification fails to send.
class const PushSendException({required final int statusCode, final bool isRetry = false}) implements Exception {
  @override
  String toString() =>
      "PushSendException: notification ${isRetry ? "failed after retry" : "failed"} with status $statusCode";
}
