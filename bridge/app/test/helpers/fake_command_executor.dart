import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// Answers each command line from [_results]; an unlisted command fails to start.
class FakeCommandExecutor({required final Map<String, CommandResult> _results}) implements CommandExecutor {
  final List<String> commands = [];

  @override
  Future<CommandResult> run({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
    required Duration? timeout,
  }) async {
    final command = [executable, ...arguments].join(" ");
    commands.add(command);
    final result = _results[command];
    if (result == null) throw ProcessException(executable, arguments, "not found", 2);
    return result;
  }
}

/// A zero-exit result printing [stdout].
CommandResult commandOutput({required String stdout}) => CommandResult(exitCode: 0, stdout: stdout, stderr: "");
