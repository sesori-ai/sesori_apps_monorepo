import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/shell_command_api.dart";
import "../repositories/scheduled_command_repository.dart";
import "scheduled_command_result_formatter.dart";

/// The one owner of the shell commands wake-ups and tasks run: it runs them,
/// reports their result in the words the agent reads, and keeps their output
/// files for [outputLifetime]. The commands are agent-written, so nothing
/// here logs them.
class ScheduledCommandService({
  required final ScheduledCommandRepository _commands,
  required final ScheduledCommandResultFormatter _formatter,
  required final Clock _clock,
}) {
  static const Duration timeout = Duration(minutes: 10);
  static const Duration outputLifetime = Duration(days: 7);

  /// Runs [command] in [workingDirectory] and returns the block that reports
  /// its result. Its output goes to [outputKey]'s folder (see
  /// [ScheduledCommandRepository.run]). Never throws: a failure to run reads
  /// as a command that could not start.
  Future<String> run({required String outputKey, required String command, required String workingDirectory}) async {
    final result = await _runOrFailure(outputKey: outputKey, command: command, workingDirectory: workingDirectory);
    unawaited(sweepExpiredOutputs());
    return _formatter.format(result: result);
  }

  /// Best-effort: deletes the output kept longer than [outputLifetime] and
  /// only logs a failure. Runs at bridge startup and after each command.
  Future<void> sweepExpiredOutputs() async {
    final cutoff = _clock.now().subtract(outputLifetime);
    try {
      await _commands.deleteOutputsBefore(cutoff: cutoff);
    } on Object catch (error, stackTrace) {
      Log.w("Could not sweep command output kept from before $cutoff", error, stackTrace);
    }
  }

  Future<ShellCommandResult> _runOrFailure({
    required String outputKey,
    required String command,
    required String workingDirectory,
  }) async {
    try {
      return await _commands.run(
        outputKey: outputKey,
        command: command,
        workingDirectory: workingDirectory,
        timeout: timeout,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Could not run a command for $outputKey in $workingDirectory", error, stackTrace);
      return ShellCommandCouldNotStart(error: "$error");
    }
  }
}
