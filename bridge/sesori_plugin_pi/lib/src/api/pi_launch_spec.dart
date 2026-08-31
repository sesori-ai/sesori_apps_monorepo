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

final class PiForkedSession({required final String sessionId, required final String parentSessionPath})
    extends PiSessionLaunch {
  this {
    if (!isValidPiSessionId(sessionId: sessionId)) {
      throw ArgumentError.value(sessionId, "sessionId", "must be a valid Pi session ID");
    }
    if (!path.isAbsolute(parentSessionPath)) {
      throw ArgumentError.value(parentSessionPath, "parentSessionPath", "must be absolute");
    }
  }
}

final class const PiNoSession() extends PiSessionLaunch;

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
/// The first turn's requested selection is part of the command line so Pi
/// extensions observe it during `session_start`, before RPC commands are read.
class PiLaunchSpec({
  required final String binaryPath,
  required final String workingDirectory,
  required final PiSessionLaunch launch,
  required final ({String providerID, String modelID})? model,
  required final String? thinkingLevel,
  required Map<String, String> environment,
}) {
  this {
    if (environment.containsKey("HOME")) {
      throw ArgumentError.value("HOME", "environment", "must not override this key");
    }
  }

  /// Additional entries merged over the inherited process environment.
  final Map<String, String> environment = Map.unmodifiable({...environment, "PI_SKIP_VERSION_CHECK": "1"});

  List<String> get arguments {
    final selectedModel = model;
    final selectedThinkingLevel = thinkingLevel;
    return [
      ...switch (launch) {
        PiNoSession() => ["--mode", "rpc", "--no-session", "--approve"],
        PiNewSession(:final sessionId) => ["--mode", "rpc", "--approve", "--session-id", sessionId],
        PiForkedSession(:final sessionId, :final parentSessionPath) => [
          "--mode",
          "rpc",
          "--approve",
          "--fork",
          parentSessionPath,
          "--session-id",
          sessionId,
        ],
        PiResumedSession(:final sessionPath) => ["--mode", "rpc", "--approve", "--session", sessionPath],
      },
      if (selectedModel != null) ...[
        "--provider",
        selectedModel.providerID,
        "--model",
        selectedModel.modelID,
      ],
      if (selectedThinkingLevel != null) ...["--thinking", selectedThinkingLevel],
    ];
  }
}
