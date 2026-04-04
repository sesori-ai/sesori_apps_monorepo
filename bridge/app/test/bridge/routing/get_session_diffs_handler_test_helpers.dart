import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";

class Invocation {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  const Invocation({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });
}

class FakeProcessRunner implements ProcessRunner {
  ProcessResult Function({required List<String> arguments}) responder = _defaultResponder;
  final List<Invocation> invocations = <Invocation>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(
      Invocation(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return responder(arguments: arguments);
  }

  static ProcessResult _defaultResponder({required List<String> arguments}) {
    throw StateError("Unexpected git call: $arguments");
  }
}
