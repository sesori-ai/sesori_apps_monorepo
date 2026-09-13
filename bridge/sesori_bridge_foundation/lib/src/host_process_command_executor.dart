import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show HostProcessService, Log, PluginStartAbortedException, SpawnedProcess, StartAbortSignal;

import "command_executor.dart";

/// A [CommandExecutor] that runs commands through the bridge's
/// [HostProcessService] rather than spawning OS processes directly.
///
/// Plugins must not reach around the host to spawn processes, so runtime
/// acquisition primitives (archive extraction, version probing) run their
/// short-lived helper commands (`tar`, `unzip`, `<bin> --version`) through this
/// adapter. It drains stdout/stderr from spawn so a chatty child cannot block on
/// a full pipe, and force-kills a child that outlives the timeout. Forced
/// termination is not considered complete until the child exit is observed.
class HostProcessCommandExecutor({
  required final HostProcessService _processes,
  required final bool _runInShell,
  required final bool _includeParentEnvironment,
  required final int? _maxCapturedOutputCharactersPerStream,
  final Duration _defaultTimeout = const Duration(seconds: 30),
}) implements CommandExecutor {
  this
    : assert(
        _maxCapturedOutputCharactersPerStream == null || _maxCapturedOutputCharactersPerStream >= 0,
        "maxCapturedOutputCharactersPerStream must not be negative",
      );

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) => _run(
    executable: executable,
    arguments: arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    timeout: timeout,
    abortSignal: null,
  );

  /// Runs a mutation command whose process must be force-stopped when bridge
  /// shutdown wins the race.
  Future<CommandResult> runAbortable({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
    required Duration? timeout,
    required StartAbortSignal abortSignal,
  }) => _run(
    executable: executable,
    arguments: arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    timeout: timeout,
    abortSignal: abortSignal,
  );

  Future<CommandResult> _run({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
    required Duration? timeout,
    required StartAbortSignal? abortSignal,
  }) async {
    if (abortSignal?.isAborted ?? false) throw const PluginStartAbortedException();
    final SpawnedProcess process = await _processes.spawn(
      includeParentEnvironment: _includeParentEnvironment,
      executable: executable,
      arguments: arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: _runInShell,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    // allowMalformed: tool output (tar/unzip listings) is not guaranteed valid
    // UTF-8; a decode error must not crash a command run.
    const decoder = Utf8Decoder(allowMalformed: true);
    final stdoutSub = process.stdout
        .transform(decoder)
        .listen(
          (chunk) => _capture(buffer: stdoutBuffer, chunk: chunk),
          onError: (Object error, StackTrace stackTrace) =>
              Log.w("HostProcessCommandExecutor: '$executable' stdout stream error", error, stackTrace),
        );
    final stderrSub = process.stderr
        .transform(decoder)
        .listen(
          (chunk) => _capture(buffer: stderrBuffer, chunk: chunk),
          onError: (Object error, StackTrace stackTrace) =>
              Log.w("HostProcessCommandExecutor: '$executable' stderr stream error", error, stackTrace),
        );
    // Completes when each stream is fully delivered (the child has exited AND the
    // pipe is drained). Draining happens via the listeners above, so awaiting
    // these alongside exitCode never deadlocks on a full pipe.
    final Future<void> stdoutDone = stdoutSub.asFuture<void>();
    final Future<void> stderrDone = stderrSub.asFuture<void>();
    try {
      final exit = process.exitCode;
      final effectiveTimeout = timeout ?? _defaultTimeout;
      final int exitCode = abortSignal == null
          ? await exit.timeout(effectiveTimeout)
          : await Future.any<int>([
              exit,
              abortSignal.whenAborted.then<int>((_) => throw const PluginStartAbortedException()),
            ]).timeout(effectiveTimeout);
      // Wait for the output streams to finish before reading the buffers, so a
      // command whose stdout/stderr is still buffered at exit (e.g. a fast
      // `--version` or a `tar -tzf` listing) is not captured truncated. Bounded
      // so a pipe that never closes after exit can't hang the result.
      try {
        await Future.wait<void>([stdoutDone, stderrDone]).timeout(const Duration(seconds: 5));
      } on TimeoutException catch (error, stackTrace) {
        Log.w(
          "HostProcessCommandExecutor: '$executable' output streams did not close promptly after exit",
          error,
          stackTrace,
        );
      }
      return CommandResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    } on PluginStartAbortedException {
      await _kill(process: process, executable: executable, reason: "aborted");
      rethrow;
    } on TimeoutException {
      await _kill(process: process, executable: executable, reason: "timed-out");
      rethrow;
    } finally {
      // Isolate each cancel: a cancel failure must neither mask the in-flight
      // command result/error nor skip the other subscription's teardown.
      await _cancelQuietly(stdoutSub, stream: "stdout", executable: executable);
      await _cancelQuietly(stderrSub, stream: "stderr", executable: executable);
    }
  }

  Future<void> _kill({
    required SpawnedProcess process,
    required String executable,
    required String reason,
  }) async {
    Object? signalError;
    StackTrace? signalStackTrace;
    try {
      await _processes.signalForce(pid: process.pid);
    } on Object catch (error, stackTrace) {
      signalError = error;
      signalStackTrace = stackTrace;
      Log.w("HostProcessCommandExecutor: failed to kill $reason '$executable'", error, stackTrace);
    }

    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on Object catch (error, stackTrace) {
      Log.w(
        "HostProcessCommandExecutor: failed to confirm termination of $reason '$executable'",
        error,
        stackTrace,
      );
      if (signalError case final error?) {
        Error.throwWithStackTrace(error, signalStackTrace ?? StackTrace.current);
      }
      rethrow;
    }
  }

  void _capture({required StringBuffer buffer, required String chunk}) {
    final limit = _maxCapturedOutputCharactersPerStream;
    if (limit == null) {
      buffer.write(chunk);
      return;
    }
    final remaining = limit - buffer.length;
    if (remaining <= 0) return;
    buffer.write(chunk.length <= remaining ? chunk : chunk.substring(0, remaining));
  }

  Future<void> _cancelQuietly(
    StreamSubscription<void> subscription, {
    required String stream,
    required String executable,
  }) async {
    try {
      await subscription.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("HostProcessCommandExecutor: '$executable' $stream cancel failed", error, stackTrace);
    }
  }
}
