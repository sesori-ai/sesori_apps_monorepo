/// How a scheduled command's run ended.
sealed class const ScheduledCommandResult();

final class const ScheduledCommandExited({
  required final int exitCode,
  required final CommandStreamOutput stdout,
  required final CommandStreamOutput stderr,
}) extends ScheduledCommandResult;

/// Killed at its timeout; the streams hold what it wrote until then.
final class const ScheduledCommandTimedOut({
  required final Duration timeout,
  required final CommandStreamOutput stdout,
  required final CommandStreamOutput stderr,
}) extends ScheduledCommandResult;

/// Killed by a bridge shutdown.
final class const ScheduledCommandStopped({
  required final CommandStreamOutput stdout,
  required final CommandStreamOutput stderr,
}) extends ScheduledCommandResult;

/// The command did not start, for example because its folder is gone.
final class const ScheduledCommandCouldNotStart({required final String error}) extends ScheduledCommandResult;

/// One output stream of a run.
final class const CommandStreamOutput({
  /// The file holding the whole stream; null when it could not be written.
  required final String? path,
  required final int wordCount,

  /// Its last lines, each cut to a few hundred characters.
  required final List<String> lastLines,

  /// The whole stream, or null when it grew too large to keep in memory.
  required final String? text,
});
