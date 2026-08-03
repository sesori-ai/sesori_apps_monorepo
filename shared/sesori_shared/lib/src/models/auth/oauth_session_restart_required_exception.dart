final class OAuthSessionRestartRequiredException implements Exception {
  final Duration restartAfter;
  final DateTime deadline;
  const OAuthSessionRestartRequiredException({required this.restartAfter, required this.deadline});
}
