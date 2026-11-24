import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;

import "../foundation/streaming_process_runner.dart";

/// Runs one command line through the user's shell.
///
/// POSIX runs `$SHELL -lc <command>`, falling back to `/bin/sh`: a login
/// shell gives a bridge that launchd or systemd started the user's `PATH`.
/// Windows runs `cmd.exe /d /s /c <command>`. A kill stops the shell; a
/// process it started in the background may keep running.
final class ShellCommandApi._({
  required final StreamingProcessRunner _runner,
  required final String _shell,
  required final List<String> _shellArguments,
}) {
  /// [environment] is the bridge's; POSIX reads the login shell from `SHELL`.
  factory forPlatform({
    required PlatformOs platform,
    required StreamingProcessRunner runner,
    required Map<String, String> environment,
  }) => switch (platform) {
    PlatformOs.macos || PlatformOs.linux => ShellCommandApi._(
      runner: runner,
      shell: switch (environment["SHELL"]) {
        final shell? when shell.trim().isNotEmpty => shell,
        _ => "/bin/sh",
      },
      shellArguments: const ["-lc"],
    ),
    PlatformOs.windows => ShellCommandApi._(
      runner: runner,
      shell: "cmd.exe",
      shellArguments: const ["/d", "/s", "/c"],
    ),
  };

  /// Runs [command] in [workingDirectory] with no input, handing its stdout
  /// and stderr to [capture] as soon as it starts, and returns what [capture]
  /// returned. Kills the command after [timeout], or as soon as [stop]
  /// completes. Throws a `ProcessException` when the shell cannot start, for
  /// example because the folder is gone.
  Future<({ShellCommandEnding ending, T output})> run<T>({
    required String command,
    required String workingDirectory,
    required Duration timeout,
    required Future<void> stop,
    required T Function({required Stream<List<int>> stdout, required Stream<List<int>> stderr}) capture,
  }) => _runner.run(
    executable: _shell,
    arguments: [..._shellArguments, command],
    workingDirectory: workingDirectory,
    environment: null,
    // A backstop only: the operation ends by itself soon after [timeout].
    timeout: timeout + const Duration(minutes: 1),
    operation: ({required process}) async {
      final output = capture(stdout: process.stdout, stderr: process.stderr);
      await process.closeStdin();
      final ending = await Future.any<ShellCommandEnding>([
        process.exitCode.then((exitCode) => ShellCommandExited(exitCode: exitCode)),
        Future<ShellCommandEnding>.delayed(timeout, () => const ShellCommandTimedOut()),
        stop.then((_) => const ShellCommandStopped()),
      ]);
      if (ending is! ShellCommandExited) process.kill();
      return (ending: ending, output: output);
    },
  );
}

/// How a command run ended.
sealed class const ShellCommandEnding();

final class const ShellCommandExited({required final int exitCode}) extends ShellCommandEnding;

/// Killed at its timeout.
final class const ShellCommandTimedOut() extends ShellCommandEnding;

/// Killed because its caller stopped it, as at a bridge shutdown.
final class const ShellCommandStopped() extends ShellCommandEnding;
