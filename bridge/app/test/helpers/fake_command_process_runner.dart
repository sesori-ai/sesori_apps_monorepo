import "dart:io";

import "package:sesori_bridge/src/foundation/process_runner.dart";

/// Answers each command line from [_results]; an unlisted command fails to start.
class FakeCommandProcessRunner({required final Map<String, ProcessResult> _results}) implements ProcessRunner {
  final List<String> commands = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final command = [executable, ...arguments].join(" ");
    commands.add(command);
    final result = _results[command];
    if (result == null) throw ProcessException(executable, arguments, "not found", 2);
    return result;
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) => throw UnimplementedError();
}

/// A zero-exit result printing [stdout].
ProcessResult processOutput({required String stdout}) => ProcessResult(1, 0, stdout, "");
