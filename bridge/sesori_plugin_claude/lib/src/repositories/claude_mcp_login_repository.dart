import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../api/claude_process_launch.dart";
import "models/claude_mcp_command_exception.dart";
import "parsers/claude_mcp_login_output_parser.dart";

sealed class const ClaudeMcpCallbackSubmission();

final class const ClaudeMcpCallbackSubmitted() extends ClaudeMcpCallbackSubmission;

final class const ClaudeMcpCallbackRejected({required final ClaudeMcpProviderCallbackException cause})
    extends ClaudeMcpCallbackSubmission;

final class const ClaudeMcpLoginTrustRequiredException() implements Exception {
  @override
  String toString() => "Approve this configured MCP server in the native harness before signing in";
}

/// Keeps the original stream failure without printing authentication output.
final class const ClaudeMcpLoginOutputException({required final Object innerError}) implements Exception {
  @override
  String toString() => "Claude MCP login output could not be read";
}

/// Owns exactly one native MCP login child, including cancellation during spawn.
/// The bridge attempt owner bounds URL/completion waits and holds the runtime lease.
final class ClaudeMcpLoginRepository({
  required final HostClaudeProcessFactory _processFactory,
  required final String _binaryPath,
  required final String _serverName,
  required final String _workingDirectory,
  required final Map<String, String> _environment,
  required final Duration _killGrace,
}) {
  final Completer<ClaudeMcpLoginChallenge> _challenge = Completer();
  final Completer<int> _exit = Completer();
  final Completer<void> _outputClosed = Completer();
  final CompositeSubscription _subscriptions = CompositeSubscription();
  Future<ClaudeProcessHandle>? _spawn;
  Future<void>? _disposal;

  Future<ClaudeMcpLoginChallenge> start() async {
    final spawn = _processFactory.spawnTerminal(
      launch: ClaudeProcessLaunch(
        binaryPath: _binaryPath,
        arguments: ["mcp", "login", "--no-browser", "--", _serverName],
        workingDirectory: _workingDirectory,
        environment: _environment,
      ),
    );
    _spawn = spawn;
    final process = await spawn;
    // A write failure is surfaced by submitCallback; exit remains authoritative.
    unawaited(
      process.stdin.done.catchError((Object error, StackTrace stackTrace) {
        Log.w("[claude] MCP login input closed with an error", error, stackTrace);
      }),
    );
    final stdoutClosed = Completer<void>();
    final stderrClosed = Completer<void>();
    _subscriptions.add(
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_challenge.isCompleted) return;
              try {
                if (const ClaudeMcpLoginOutputParser().requiresNativeTrust(line: line)) {
                  _challenge.completeError(const ClaudeMcpLoginTrustRequiredException());
                  return;
                }
                final challenge = const ClaudeMcpLoginOutputParser().parseLine(line: line);
                if (challenge != null) _challenge.complete(challenge);
              } on FormatException catch (error, stackTrace) {
                _challenge.completeError(ClaudeMcpLoginOutputException(innerError: error), stackTrace);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              final failure = ClaudeMcpLoginOutputException(innerError: error);
              if (!_challenge.isCompleted) _challenge.completeError(failure, stackTrace);
              Log.w("[claude] MCP login output failed", failure, stackTrace);
            },
            onDone: stdoutClosed.complete,
          ),
    );
    _subscriptions.add(
      process.stderr.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => Log.w("[claude] MCP login helper failed", error, stackTrace),
        onDone: stderrClosed.complete,
      ),
    );
    unawaited(Future.wait([stdoutClosed.future, stderrClosed.future]).then((_) => _outputClosed.complete()));
    unawaited(process.exitCode.then(_exit.complete));
    unawaited(
      waitForExit().then((code) {
        if (!_challenge.isCompleted) _challenge.completeError(ClaudeMcpCommandExitedException(exitCode: code));
      }),
    );
    return await _challenge.future;
  }

  Future<ClaudeMcpCallbackSubmission> submitCallback({required String callback}) async {
    final challenge = await _challenge.future;
    final Uri uri;
    try {
      uri = challenge.validateCallback(value: callback);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(PluginMcpAuthenticationCallbackRejectedException(innerError: error), stackTrace);
    }
    final failure = challenge.providerFailure(callback: uri);
    if (failure != null) return ClaudeMcpCallbackRejected(cause: failure);
    final process = await _started();
    process.stdin.add(utf8.encode("$uri\n"));
    await process.stdin.flush();
    return const ClaudeMcpCallbackSubmitted();
  }

  Future<int> waitForExit() async {
    final code = await _exit.future;
    await _outputClosed.future;
    return code;
  }

  Future<void> dispose() => _disposal ??= _stop();

  Future<void> _stop() async {
    final ClaudeProcessHandle process;
    try {
      process = await _started();
    } on Object {
      // A failed spawn is surfaced by start; there is no owned child to stop.
      return;
    }
    if (!_exit.isCompleted) {
      process.kill();
      try {
        await process.exitCode.timeout(_killGrace);
      } on TimeoutException {
        process.kill(io.ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    await _subscriptions.cancel();
    if (!_outputClosed.isCompleted) _outputClosed.complete();
    await process.stdin.close();
  }

  Future<ClaudeProcessHandle> _started() {
    final spawn = _spawn;
    if (spawn == null) throw StateError("MCP login has not started");
    return spawn;
  }
}
