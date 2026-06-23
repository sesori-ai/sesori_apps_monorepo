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
    final stdoutSub = process.stdout.transform(decoder).listen(stdoutBuffer.write, onError: (Object _) {});
    final stderrSub = process.stderr.transform(decoder).listen(stderrBuffer.write, onError: (Object _) {});
    try {
      final int exitCode = await process.exitCode.timeout(timeout ?? _defaultTimeout);
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
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }
  }
}
