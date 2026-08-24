import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/foundation/process_runner.dart";

typedef ProcessResponder = FutureOr<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
  Duration timeout,
});

class NoopProcessRunner() implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    throw UnimplementedError("NoopProcessRunner must not run processes");
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError("NoopProcessRunner must not start processes");
  }
}

class const ProcessRunInvocation({
  required final String executable,
  required final List<String> arguments,
  required final Map<String, String>? environment,
  required final String? workingDirectory,
  required final Duration timeout,
});

final class RecordingProcessRunner({
  ProcessResponder? responder,
  ProcessResult? result,
  int exitCode = 0,
  String stdout = "",
  String stderr = "",
}) implements ProcessRunner {
  final ProcessResponder _responder =
      responder ??
      ((_, _, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
        return result ?? ProcessResult(1, exitCode, stdout, stderr);
      });
  final List<ProcessRunInvocation> invocations = <ProcessRunInvocation>[];

  List<ProcessRunInvocation> get calls => invocations;
  String? get executable => invocations.lastOrNull?.executable;
  List<String>? get arguments => invocations.lastOrNull?.arguments;
  Map<String, String>? get environment => invocations.lastOrNull?.environment;
  String? get workingDirectory => invocations.lastOrNull?.workingDirectory;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(
      ProcessRunInvocation(
        executable: executable,
        arguments: List<String>.from(arguments),
        environment: environment == null ? null : Map<String, String>.from(environment),
        workingDirectory: workingDirectory,
        timeout: timeout,
      ),
    );
    return await _responder(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError("RecordingProcessRunner only records run calls");
  }
}
