enum OAuthSessionRestartOperation { init, status }

enum OAuthSessionRestartReason { serviceUnavailable, sessionMissing }

final class OAuthSessionRestartRequiredException implements Exception {
  final Duration restartAfter;
  final DateTime deadline;
  final OAuthSessionRestartOperation operation;
  final OAuthSessionRestartReason reason;

  const OAuthSessionRestartRequiredException({
    required this.restartAfter,
    required this.deadline,
    required this.operation,
    required this.reason,
  });

  @override
  String toString() =>
      "OAuth session restart required (operation: ${operation.name}, reason: ${reason.name}, "
      "restartAfterMs: ${restartAfter.inMilliseconds}, deadline: ${deadline.toIso8601String()})";
}
