import "package:path/path.dart" as path;

/// Whether a Pi process creates a session or resumes an existing session file.
sealed class const PiSessionLaunch();

/// Starts a new session under a bridge-generated ID.
final class PiNewSession({required final String sessionId}) extends PiSessionLaunch {
  this {
    if (!isValidPiSessionId(sessionId: sessionId)) {
      throw ArgumentError.value(sessionId, "sessionId", "must be a valid Pi session ID");
    }
  }
}

/// Resumes the session stored at an exact absolute JSONL path.
final class PiResumedSession({required final String sessionPath}) extends PiSessionLaunch {
  this {
    if (!path.isAbsolute(sessionPath)) {
      throw ArgumentError.value(sessionPath, "sessionPath", "must be absolute");
    }
  }
}

final RegExp _sessionIdPattern = RegExp(r"^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$");

bool isValidPiSessionId({required String sessionId}) => _sessionIdPattern.hasMatch(sessionId);

/// The verified command line for one Pi JSONL RPC process.
///
/// One process serves one session and inherits the user's environment so Pi can
/// use normal credentials, configuration, packages, and session directories.
class PiLaunchSpec({
  required final String binaryPath,
  required final String workingDirectory,
  required final PiSessionLaunch launch,
  required Map<String, String> environment,
}) {
  this {
    if (environment.containsKey("HOME")) {
      throw ArgumentError.value("HOME", "environment", "must not override this key");
    }
  }

  /// Additional entries merged over the inherited process environment.
  final Map<String, String> environment = Map.unmodifiable({...environment, "PI_SKIP_VERSION_CHECK": "1"});

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
