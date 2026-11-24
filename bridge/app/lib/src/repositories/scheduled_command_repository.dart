import "package:path/path.dart" as p;

import "../api/shell_command_api.dart";
import "prompt_upload_repository.dart";

/// Runs the shell commands wake-ups and tasks carry, keeping each run's
/// output as `<root>/<key>/<YYYY-MM-DD>-<random>/{stdout,stderr}.txt` in
/// [_outputs]' root, outside every project and readable by the user alone.
class ScheduledCommandRepository({
  required final ShellCommandApi _shell,
  required final PromptUploadRepository _outputs,
}) {
  /// Runs [command] in [workingDirectory], killing it after [timeout]. Its
  /// output goes to a new folder under [outputKey]: the session it reports
  /// to, or `task-<taskId>` for a task run that has no session yet.
  Future<ShellCommandResult> run({
    required String outputKey,
    required String command,
    required String workingDirectory,
    required Duration timeout,
  }) async {
    final folder = await _outputs.reserveFolder(sessionId: outputKey);
    return await _shell.run(
      command: command,
      workingDirectory: workingDirectory,
      stdoutPath: p.join(folder, "stdout.txt"),
      stderrPath: p.join(folder, "stderr.txt"),
      timeout: timeout,
    );
  }

  /// Deletes every run's output kept from before the day of [cutoff].
  Future<void> deleteOutputsBefore({required DateTime cutoff}) => _outputs.deleteFileFoldersDatedBefore(cutoff: cutoff);
}
