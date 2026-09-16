import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../api/claude_process_launch.dart";
import "../models/claude_pasted_code.dart";
import "parsers/claude_login_output_parser.dart";

/// A login failure. Its message never carries the sign-in URL or the code.
final class ClaudeAuthenticationException({required final String message}) implements Exception {
  @override
  String toString() => "ClaudeAuthenticationException: $message";
}

/// Owns the `claude auth login --claudeai` child of one login attempt.
final class ClaudeAuthenticationRepository({
  required final HostClaudeProcessFactory _processFactory,
  required final String _binaryPath,
  required final String _workingDirectory,
  required final Map<String, String> _environment,
  final ClaudeLoginOutputParser _parser = const ClaudeLoginOutputParser(),
  final Duration _killGrace = const Duration(seconds: 5),
}) {
  static const int _stderrTailLines = 20;

  final Completer<Uri> _authorizationUri = Completer<Uri>();
  final List<String> _stderrTail = [];
  Future<ClaudeProcessHandle>? _spawn;
  Future<void>? _disposal;

  /// The last stderr lines with URLs removed, for local failure logs.
  String get stderrTail => _stderrTail.join("\n");

  /// Spawns the CLI and completes with the sign-in URL it prints. Fails when
  /// the CLI prints an unusable URL or exits first; the caller bounds the wait.
  Future<Uri> start() async {
    final spawn = _processFactory.spawn(
      ClaudeProcessLaunch(
        binaryPath: _binaryPath,
        arguments: const ["auth", "login", "--claudeai"],
        workingDirectory: _workingDirectory,
        environment: _environment,
      ),
    );
    _spawn = spawn;
    final process = await spawn;
    // Broken pipes surface on `stdin.done`; the exit code reports the failure.
    unawaited(process.stdin.done.catchError((Object _) {}));
    // Both pipes are drained until exit so the CLI never blocks on a full pipe.
    _decodeLines(process.stdout).listen(
      (line) {
        if (_authorizationUri.isCompleted) return;
        switch (_parser.parseLine(line: line)) {
          case ClaudeLoginOutputNone():
            break;
          case ClaudeLoginOutputUrl(:final authorizationUri):
            _authorizationUri.complete(authorizationUri);
          case ClaudeLoginOutputInvalidUrl(:final length):
            _authorizationUri.completeError(
              ClaudeAuthenticationException(
                message: "Claude Code printed an unusable sign-in URL ($length characters)",
              ),
            );
        }
      },
      onError: (Object error, StackTrace stackTrace) => Log.w("[claude] login stdout failed", error, stackTrace),
    );
    _decodeLines(process.stderr).listen(
      (line) {
        _stderrTail.add(_parser.redactLine(line: line));
        if (_stderrTail.length > _stderrTailLines) _stderrTail.removeAt(0);
      },
      onError: (Object error, StackTrace stackTrace) => Log.w("[claude] login stderr failed", error, stackTrace),
    );
    unawaited(
      process.exitCode.then((exitCode) {
        if (_authorizationUri.isCompleted) return;
        _authorizationUri.completeError(
          ClaudeAuthenticationException(
            message: "Claude Code exited with code $exitCode before printing a sign-in URL",
          ),
        );
      }),
    );
    return await _authorizationUri.future;
  }

  /// Writes [code] to the CLI as one line. The bridge runtime allows one
  /// submission per operation.
  Future<void> submitCode({required ClaudePastedCode code}) async {
    final process = await _started();
    process.stdin.add(utf8.encode("${code.value}\n"));
    await process.stdin.flush();
  }

  Future<int> waitForExit() async {
    final process = await _started();
    return await process.exitCode;
  }

  /// Stops the CLI, forcing it after a grace period, and waits for it to exit.
  Future<void> dispose() => _disposal ??= _stop();

  Future<void> _stop() async {
    final ClaudeProcessHandle process;
    try {
      // An in-flight spawn is awaited so a cancelled login leaves no CLI behind.
      process = await _started();
    } on Object {
      // Nothing is running; start reports a failed spawn.
      return;
    }
    process.kill();
    try {
      await process.exitCode.timeout(_killGrace);
    } on TimeoutException {
      process.kill(io.ProcessSignal.sigkill);
      await process.exitCode;
    }
  }

  Future<ClaudeProcessHandle> _started() => _spawn ?? Future.error(StateError("Claude Code login has not started"));

  static Stream<String> _decodeLines(Stream<List<int>> bytes) =>
      bytes.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());
}
