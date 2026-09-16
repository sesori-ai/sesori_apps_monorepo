import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:rxdart/rxdart.dart";
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
  final Duration _killGrace = const Duration(seconds: 5),
}) {
  static const int _stderrTailLines = 20;

  final ClaudeLoginOutputParser _parser = const ClaudeLoginOutputParser();
  final Completer<Uri> _authorizationUri = Completer<Uri>();
  final Completer<int> _exitCode = Completer<int>();
  final CompositeSubscription _pipes = CompositeSubscription();
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
    // Both pipes are drained until they close so the CLI never blocks on a full pipe.
    final stdoutClosed = Completer<void>();
    final stderrClosed = Completer<void>();
    _pipes.add(
      _decodeLines(bytes: process.stdout).listen(
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
        onDone: stdoutClosed.complete,
      ),
    );
    _pipes.add(
      _decodeLines(bytes: process.stderr).listen(
        (line) {
          _stderrTail.add(_parser.redactLine(line: line));
          if (_stderrTail.length > _stderrTailLines) _stderrTail.removeAt(0);
        },
        onError: (Object error, StackTrace stackTrace) => Log.w("[claude] login stderr failed", error, stackTrace),
        onDone: stderrClosed.complete,
      ),
    );
    // The exit can be reported before the last output arrives, so it counts
    // only once both pipes close and the stderr tail is complete.
    unawaited(
      Future.wait([stdoutClosed.future, stderrClosed.future]).then((_) => process.exitCode).then(_exitCode.complete),
    );
    unawaited(
      _exitCode.future.then((exitCode) {
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

  /// Completes with the exit code once the CLI has exited and closed both
  /// pipes. Call only after [start] returned a URL.
  Future<int> waitForExit() => _exitCode.future;

  /// Stops a running CLI, forcing it after a grace period, waits for it to
  /// exit, and stops reading its pipes.
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
    // Signals go by PID, so a CLI whose exit was already read is not signalled.
    if (!_exitCode.isCompleted) {
      process.kill();
      try {
        await process.exitCode.timeout(_killGrace);
      } on TimeoutException {
        process.kill(io.ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    // A descendant can keep a pipe open after the CLI exits.
    await _pipes.cancel();
  }

  Future<ClaudeProcessHandle> _started() => _spawn ?? Future.error(StateError("Claude Code login has not started"));

  static Stream<String> _decodeLines({required Stream<List<int>> bytes}) =>
      bytes.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());
}
