enum AntigravityAuthenticationHint() {
  authenticationRequired,
  tokenPresent,
}

/// Prepared environment used unchanged by auth/live/replay/local-probe launches.
final class AntigravityPreparedProfile({required final String geminiHome, required Map<String, String> environment}) {
  final Map<String, String> environment = Map.unmodifiable(environment);
}

class const AntigravityProfileException({
  required final String message,
  // ignore: no_slop_linter/prefer_specific_type, preserve the original storage/process failure
  required final Object? cause,
}) implements Exception {
  @override
  String toString() => "Antigravity profile: $message";
}
