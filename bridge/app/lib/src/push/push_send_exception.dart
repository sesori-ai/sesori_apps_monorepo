/// Thrown when a push notification fails to send.
class const PushSendException({required this.statusCode, this.isRetry = false}) implements Exception {
  final int statusCode;
  final bool isRetry;
  @override
  String toString() =>
      "PushSendException: notification ${isRetry ? "failed after retry" : "failed"} with status $statusCode";
}
