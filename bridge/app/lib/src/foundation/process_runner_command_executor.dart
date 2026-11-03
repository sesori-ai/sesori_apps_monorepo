import "dart:io" show ProcessResult;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "process_runner.dart";

/// Adapts the bridge's [ProcessRunner] to the runtime [CommandExecutor] seam, so
/// Layer-0 acquisition primitives (archive extraction, runtime version probing)
/// can run commands to completion without depending on the app's process layer.
class ProcessRunnerCommandExecutor({required final ProcessRunner _processRunner}) implements CommandExecutor {
  @override
  Future<CommandResult> run({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
    required Duration? timeout,
  }) async {
    // ProcessRunner.run owns the default timeout; only override it when the
    // caller asked for a specific one rather than duplicating that default here.
    final ProcessResult result = timeout == null
        ? await _processRunner.run(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment,
          )
        : await _processRunner.run(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment,
            timeout: timeout,
          );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}
