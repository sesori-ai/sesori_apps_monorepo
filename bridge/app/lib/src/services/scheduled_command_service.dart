import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/models/scheduled_command_result.dart";
import "../repositories/prompt_upload_repository.dart";
import "../repositories/scheduled_command_repository.dart";
import "scheduled_command_result_formatter.dart";

/// The one owner of the shell commands wake-ups and tasks run: it runs them,
/// reports their result in the words the agent reads, keeps their output
/// files in [_outputs] for [outputLifetime], and stops the running ones at
/// shutdown. The commands are agent-written, so nothing here logs them.
class ScheduledCommandService({
  required final ScheduledCommandRepository _commands,
  required final PromptUploadRepository _outputs,
  required final ScheduledCommandResultFormatter _formatter,
  required final Clock _clock,
}) {
  static const Duration timeout = Duration(minutes: 10);
  static const Duration outputLifetime = Duration(days: 7);

  final Completer<void> _stop = Completer<void>();
  final Set<Future<void>> _running = {};

  /// Runs [command] in [workingDirectory] and returns the block that reports
  /// its result. Its output goes to a new folder under [outputKey]: the
  /// session it reports to, or `task-<taskId>` for a task run that has no
  /// session yet. Never throws: a failure to run reads as a command that
  /// could not start.
  Future<String> run({required String outputKey, required String command, required String workingDirectory}) async {
    final run = _runOrFailure(outputKey: outputKey, command: command, workingDirectory: workingDirectory);
    _running.add(run);
    try {
      final result = await run;
      unawaited(sweepExpiredOutputs());
      return _formatter.format(result: result);
    } finally {
      _running.remove(run);
    }
  }

  /// Best-effort: deletes the output kept longer than [outputLifetime] and
  /// only logs a failure. Runs at bridge startup and after each command.
  Future<void> sweepExpiredOutputs() async {
    final cutoff = _clock.now().subtract(outputLifetime);
    try {
      await _outputs.deleteFileFoldersDatedBefore(cutoff: cutoff);
    } on Object catch (error, stackTrace) {
      Log.w("Could not sweep command output kept from before $cutoff", error, stackTrace);
    }
  }

  /// Kills every running command and waits for each to end; a command started
  /// afterwards is killed at once.
  Future<void> dispose() async {
    if (!_stop.isCompleted) _stop.complete();
    await Future.wait(_running.toList());
  }

  Future<ScheduledCommandResult> _runOrFailure({
    required String outputKey,
    required String command,
    required String workingDirectory,
  }) async {
    try {
      final folder = await _outputs.reserveFolder(sessionId: outputKey);
      return await _commands.run(
        folder: folder,
        command: command,
        workingDirectory: workingDirectory,
        timeout: timeout,
        stop: _stop.future,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Could not run a command for $outputKey in $workingDirectory", error, stackTrace);
      return ScheduledCommandCouldNotStart(error: "$error");
    }
  }
}
