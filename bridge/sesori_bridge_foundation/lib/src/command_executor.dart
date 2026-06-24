import "package:meta/meta.dart";

/// Runs a child process to completion and returns its captured output.
///
/// This is the run-to-completion seam used by runtime-acquisition primitives
/// (archive extraction, version probing) that need a command's exit code and
/// stdout/stderr — distinct from [HostProcessService], which spawns and
/// supervises long-lived runtimes. Production wires an adapter over the
/// bridge's `ProcessRunner`; tests implement this directly.
abstract class CommandExecutor {
  /// Runs [executable] with [arguments], waits for it to exit, and returns the
  /// captured result. Implementations must enforce a timeout (killing the child
  /// and throwing) so a hung command can never stall the caller; [timeout],
  /// when provided, overrides the implementation default.
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  });
}

/// The captured outcome of a [CommandExecutor.run] call.
@immutable
class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  @override
  bool operator ==(Object other) =>
      other is CommandResult &&
      other.exitCode == exitCode &&
      other.stdout == stdout &&
      other.stderr == stderr;

  @override
  int get hashCode => Object.hash(exitCode, stdout, stderr);

  @override
  String toString() => "CommandResult(exitCode: $exitCode, stdout: $stdout, stderr: $stderr)";
}
