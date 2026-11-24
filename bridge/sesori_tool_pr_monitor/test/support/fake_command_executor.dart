import "dart:collection";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

class FakeCommandInvocation({
  required final String executable,
  required final List<String> arguments,
  required final Duration? timeout,
}) {
  /// The value passed with `-f`/`-F` for [field], or null when absent.
  String? field({required String field}) {
    for (var index = 0; index < arguments.length - 1; index++) {
      final flag = arguments[index];
      final value = arguments[index + 1];
      if ((flag == "-f" || flag == "-F") && value.startsWith("$field=")) return value.substring(field.length + 1);
    }
    return null;
  }
}

/// Answers each `run` with the next queued result or error, in order.
class FakeCommandExecutor() implements CommandExecutor {
  final Queue<Object> _responses = Queue<Object>();
  final List<FakeCommandInvocation> invocations = [];

  void enqueueStdout({required String stdout}) =>
      _responses.add(CommandResult(exitCode: 0, stdout: stdout, stderr: ""));

  void enqueueFixture({required String name}) => enqueueStdout(stdout: File("test/fixtures/$name").readAsStringSync());

  void enqueueFailure({required int exitCode, required String stderr}) =>
      _responses.add(CommandResult(exitCode: exitCode, stdout: "", stderr: stderr));

  void enqueueError({required Object error}) => _responses.add(error);

  @override
  Future<CommandResult> run({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
    required Duration? timeout,
  }) async {
    invocations.add(FakeCommandInvocation(executable: executable, arguments: arguments, timeout: timeout));
    if (_responses.isEmpty) throw StateError("No response queued for $executable ${arguments.take(2).join(" ")}");
    final response = _responses.removeFirst();
    if (response is CommandResult) return response;
    throw response;
  }
}
