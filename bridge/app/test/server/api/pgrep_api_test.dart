import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/server/api/pgrep_api.dart";
import "package:test/test.dart";

void main() {
  test("exact-matches the executable name and parses process ids", () async {
    final runner = _RecordingProcessRunner(stdout: "123\n456\n");
    final api = PgrepApi(processRunner: runner);

    final processIds = await api.listProcessIdsByExecutableName(executableName: "sesori-bridge");

    expect(processIds, equals(<int>[123, 456]));
    expect(runner.executable, equals("pgrep"));
    expect(runner.arguments, equals(<String>["-x", "sesori-bridge"]));
    expect(runner.environment, equals(const <String, String>{"LC_ALL": "C"}));
  });

  test("returns an empty list when pgrep finds no matches", () async {
    final api = PgrepApi(processRunner: _RecordingProcessRunner(exitCode: 1));

    expect(
      await api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
      isEmpty,
    );
  });

  test("throws when pgrep fails", () async {
    final api = PgrepApi(
      processRunner: _RecordingProcessRunner(exitCode: 2, stderr: "invalid pattern"),
    );

    await expectLater(
      api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
      throwsA(isA<ProcessException>()),
    );
  });

  test("rejects malformed or non-positive process ids", () async {
    for (final stdout in <String>["not-a-pid\n", "0\n", "-1\n"]) {
      final api = PgrepApi(processRunner: _RecordingProcessRunner(stdout: stdout));

      await expectLater(
        api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

class _RecordingProcessRunner implements ProcessRunner {
  _RecordingProcessRunner({this.exitCode = 0, this.stdout = "", this.stderr = ""});

  final int exitCode;
  final String stdout;
  final String stderr;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    return ProcessResult(1, exitCode, stdout, stderr);
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}
