import "package:path/path.dart" as p;

import "../api/shell_command_api.dart";
import "models/scheduled_command_result.dart";

/// Runs the shell commands wake-ups and tasks carry, writing each run's
/// output as `stdout.txt` and `stderr.txt` in the folder it is given.
class ScheduledCommandRepository({required final ShellCommandApi _shell}) {
  /// Runs [command] in [workingDirectory] with its output in [folder], which
  /// only the user can open. Kills it after [timeout], or once [stop]
  /// completes.
  Future<ScheduledCommandResult> run({
    required String folder,
    required String command,
    required String workingDirectory,
    required Duration timeout,
    required Future<void> stop,
  }) async {
    final result = await _shell.run(
      command: command,
      workingDirectory: workingDirectory,
      stdoutPath: p.join(folder, "stdout.txt"),
      stderrPath: p.join(folder, "stderr.txt"),
      timeout: timeout,
      stop: stop,
    );
    return switch (result) {
      ShellCommandExited(:final exitCode, :final stdout, :final stderr) => ScheduledCommandExited(
        exitCode: exitCode,
        stdout: _stream(output: stdout),
        stderr: _stream(output: stderr),
      ),
      ShellCommandTimedOut(:final timeout, :final stdout, :final stderr) => ScheduledCommandTimedOut(
        timeout: timeout,
        stdout: _stream(output: stdout),
        stderr: _stream(output: stderr),
      ),
      ShellCommandStopped(:final stdout, :final stderr) => ScheduledCommandStopped(
        stdout: _stream(output: stdout),
        stderr: _stream(output: stderr),
      ),
      ShellCommandCouldNotStart(:final error) => ScheduledCommandCouldNotStart(error: error),
    };
  }

  static CommandStreamOutput _stream({required ShellStreamOutput output}) => CommandStreamOutput(
    path: output.path,
    wordCount: output.wordCount,
    lastLines: output.lastLines,
    text: output.text,
  );
}
