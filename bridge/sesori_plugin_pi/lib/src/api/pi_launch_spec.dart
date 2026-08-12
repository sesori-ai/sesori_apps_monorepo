import "package:path/path.dart" as path;

/// Whether a Pi process creates a session or resumes an existing session file.
sealed class const PiSessionLaunch();

/// Starts a new session under a bridge-generated ID.
final class PiNewSession({required this.sessionId}) extends PiSessionLaunch {
  this {
    if (!_sessionIdPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, "sessionId", "must be a valid Pi session ID");
    }
  }

  final String sessionId;
}

/// Resumes the session stored at an exact absolute JSONL path.
final class PiResumedSession({required this.sessionPath}) extends PiSessionLaunch {
  this {
    if (!path.isAbsolute(sessionPath)) {
      throw ArgumentError.value(sessionPath, "sessionPath", "must be absolute");
    }
  }

  final String sessionPath;
}

final RegExp _sessionIdPattern = RegExp(r"^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$");

/// The verified command line for one Pi JSONL RPC process.
///
/// One process serves one session and inherits the user's environment so Pi can
/// use normal credentials, configuration, packages, and session directories.
class PiLaunchSpec({
    required this.binaryPath,
    required this.workingDirectory,
    required this.launch,
    required Map<String, String> environment,
  }) {
  this : environment = Map.unmodifiable({...environment, "PI_SKIP_VERSION_CHECK": "1"}) {
    if (environment.containsKey("HOME")) {
      throw ArgumentError.value("HOME", "environment", "must not override this key");
    }
  }

  final String binaryPath;
  final String workingDirectory;
  final PiSessionLaunch launch;

  /// Additional entries merged over the inherited process environment.
  final Map<String, String> environment;

  List<String> get arguments => [
    "--mode",
    "rpc",
    "--approve",
    ...switch (launch) {
      PiNewSession(:final sessionId) => ["--session-id", sessionId],
      PiResumedSession(:final sessionPath) => ["--session", sessionPath],
    },
  ];
}
