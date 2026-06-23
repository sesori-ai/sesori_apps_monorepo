import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostProcessService, Log, SpawnedProcess;

import "command_executor.dart";

/// A [CommandExecutor] that runs commands through the bridge's
/// [HostProcessService] rather than spawning OS processes directly.
///
/// Plugins must not reach around the host to spawn processes, so runtime
/// acquisition primitives (archive extraction, version probing) run their
/// short-lived helper commands (`tar`, `unzip`, `<bin> --version`) through this
/// adapter. It drains stdout/stderr from spawn so a chatty child cannot block on
/// a full pipe, and force-kills a child that outlives the timeout.
class HostProcessCommandExecutor implements CommandExecutor {
  final HostProcessService _processes;
  final bool _runInShell;
  final Duration _defaultTimeout;

  HostProcessCommandExecutor({
    required HostProcessService processes,
    required bool runInShell,
    Duration defaultTimeout = const Duration(seconds: 30),
  }) : _processes = processes,
       _runInShell = runInShell,
       _defaultTimeout = defaultTimeout;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    final SpawnedProcess process = await _processes.spawn(
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
    final stdoutSub = process.stdout.transform(decoder).listen(
      stdoutBuffer.write,
      onError: (Object error) => Log.d("HostProcessCommandExecutor: ignoring '$executable' stdout error: $error"),
    );
    final stderrSub = process.stderr.transform(decoder).listen(
      stderrBuffer.write,
      onError: (Object error) => Log.d("HostProcessCommandExecutor: ignoring '$executable' stderr error: $error"),
    );
    // Completes when each stream is fully delivered (the child has exited AND the
    // pipe is drained). Draining happens via the listeners above, so awaiting
    // these alongside exitCode never deadlocks on a full pipe.
    final Future<void> stdoutDone = stdoutSub.asFuture<void>();
    final Future<void> stderrDone = stderrSub.asFuture<void>();
    try {
      final int exitCode = await process.exitCode.timeout(timeout ?? _defaultTimeout);
      // Wait for the output streams to finish before reading the buffers, so a
      // command whose stdout/stderr is still buffered at exit (e.g. a fast
      // `--version` or a `tar -tzf` listing) is not captured truncated. Bounded
      // so a pipe that never closes after exit can't hang the result.
      try {
        await Future.wait<void>([stdoutDone, stderrDone]).timeout(const Duration(seconds: 5));
      } on TimeoutException catch (error) {
        Log.d("HostProcessCommandExecutor: '$executable' output streams did not close promptly after exit: $error");
      }
      return CommandResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    } on TimeoutException {
      try {
        await _processes.signalForce(pid: process.pid);
      } on Object catch (error) {
        Log.d("HostProcessCommandExecutor: failed to kill timed-out '$executable': $error");
      }
      rethrow;
    } finally {
      // Isolate each cancel: a cancel failure must neither mask the in-flight
      // command result/error nor skip the other subscription's teardown.
      await _cancelQuietly(stdoutSub, stream: "stdout", executable: executable);
      await _cancelQuietly(stderrSub, stream: "stderr", executable: executable);
    }
  }

  Future<void> _cancelQuietly(
    StreamSubscription<void> subscription, {
    required String stream,
    required String executable,
  }) async {
    try {
      await subscription.cancel();
    } on Object catch (error) {
      Log.d("HostProcessCommandExecutor: ignoring '$executable' $stream cancel failure: $error");
    }
  }
}
