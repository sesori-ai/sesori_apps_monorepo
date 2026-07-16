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
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  ProcessResult Function({required List<String> arguments}) responder = _defaultResponder;
  final List<Invocation> invocations = <Invocation>[];

  /// Shared responder for git commands introduced alongside session diff
  /// collection (e.g. untracked file listing).
  static ProcessResult? supportGitDiffCalls(List<String> arguments, {String untrackedOutput = ""}) {
    if (arguments.isNotEmpty && arguments[0] == "cat-file") {
      return ProcessResult(1, 0, "0\n", "");
    }
    if (arguments.length >= 3 &&
        arguments[0] == "ls-files" &&
        arguments[1] == "--others" &&
        arguments[2] == "--exclude-standard") {
      return ProcessResult(1, 0, untrackedOutput, "");
    }
    return null;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
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
