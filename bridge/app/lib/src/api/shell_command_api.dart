import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";
import "../foundation/streaming_process_runner.dart";

/// Runs one command line through the user's shell.
///
/// POSIX runs `$SHELL -lc <command>`, falling back to `/bin/sh`: a login
/// shell gives a bridge that launchd or systemd started the user's `PATH`.
/// Windows runs `cmd.exe /d /s /c <command>`. A kill stops the shell and
/// every process below it: `taskkill /T` on Windows, and on POSIX the shell is
/// stopped, then its descendants in the process table and the shell killed.
final class ShellCommandApi._({
  required final StreamingProcessRunner _runner,
  required final ProcessRunner _tools,
  required final bool _isWindows,
  required final String _shell,
  required final List<String> _shellArguments,
}) {
  /// [environment] is the bridge's; POSIX reads the login shell from `SHELL`.
  /// [tools] runs the platform's process tools for a kill.
  factory forPlatform({
    required PlatformOs platform,
    required StreamingProcessRunner runner,
    required ProcessRunner tools,
    required Map<String, String> environment,
  }) => switch (platform) {
    PlatformOs.macos || PlatformOs.linux => ShellCommandApi._(
      runner: runner,
      tools: tools,
      isWindows: false,
      shell: switch (environment["SHELL"]) {
        final shell? when shell.trim().isNotEmpty => shell,
        _ => "/bin/sh",
      },
      shellArguments: const ["-lc"],
    ),
    PlatformOs.windows => ShellCommandApi._(
      runner: runner,
      tools: tools,
      isWindows: true,
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
      if (ending is! ShellCommandExited) await _killTree(process: process);
      return (ending: ending, output: output);
    },
  );

  /// Kills [process] and everything below it. A failure is logged, and the
  /// runner then still kills the shell itself.
  Future<void> _killTree({required StreamingProcess process}) async {
    final pid = process.pid;
    try {
      if (_isWindows) {
        final result = await _tools.run(
          executable: "taskkill",
          arguments: ["/PID", "$pid", "/T", "/F"],
          workingDirectory: null,
          environment: null,
        );
        if (result.exitCode != 0) Log.w("taskkill could not stop command process $pid: ${result.stderr}");
        return;
      }
      // Stopped first, so the shell cannot start more while the table is read.
      // ponytail: a descendant that forks between the read and its kill
      // leaves that child running; stop each level first if one ever does.
      Process.killPid(pid, ProcessSignal.sigstop);
      for (final descendant in await _posixDescendants(pid: pid)) {
        Process.killPid(descendant, ProcessSignal.sigkill);
      }
      Process.killPid(pid, ProcessSignal.sigkill);
    } on Object catch (error, stackTrace) {
      Log.w("Could not stop every process below command process $pid", error, stackTrace);
    }
  }

  Future<List<int>> _posixDescendants({required int pid}) async {
    final result = await _tools.run(
      executable: "ps",
      arguments: const ["-A", "-o", "pid=,ppid="],
      workingDirectory: null,
      environment: const {"LC_ALL": "C"},
    );
    if (result.exitCode != 0) throw ProcessException("ps", const [], "${result.stderr}", result.exitCode);
    final children = <int, List<int>>{};
    for (final line in const LineSplitter().convert("${result.stdout}")) {
      if (line.trim().split(RegExp(r"\s+")) case [final child, final parent]) {
        if (int.tryParse(child) case final childPid?) {
          if (int.tryParse(parent) case final parentPid? when parentPid != childPid) {
            (children[parentPid] ??= []).add(childPid);
          }
        }
      }
    }
    final descendants = <int>[];
    final pending = [pid];
    while (pending.isNotEmpty) {
      for (final child in children[pending.removeLast()] ?? const <int>[]) {
        descendants.add(child);
        pending.add(child);
      }
    }
    return descendants;
  }
}

/// How a command run ended.
sealed class const ShellCommandEnding();

final class const ShellCommandExited({required final int exitCode}) extends ShellCommandEnding;

/// Killed at its timeout.
final class const ShellCommandTimedOut() extends ShellCommandEnding;

/// Killed because its caller stopped it, as at a bridge shutdown.
final class const ShellCommandStopped() extends ShellCommandEnding;
