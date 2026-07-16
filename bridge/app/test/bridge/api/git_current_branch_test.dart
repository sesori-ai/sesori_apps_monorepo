import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  group("getCurrentBranch", () {
    test("returns the branch the directory is checked out on", () async {
      final runner = _FakeProcessRunner.result(exitCode: 0, stdout: "ui/session-list-item\n");

      final branch = await _api(runner).getCurrentBranch(projectPath: "/repo");

      expect(branch, equals("ui/session-list-item"));
    });

    test("asks git for the abbreviated HEAD in the given directory", () async {
      final runner = _FakeProcessRunner.result(exitCode: 0, stdout: "main\n");

      await _api(runner).getCurrentBranch(projectPath: "/repo");

      expect(runner.invocations.single.arguments, equals(["rev-parse", "--abbrev-ref", "HEAD"]));
      expect(runner.invocations.single.workingDirectory, equals("/repo"));
    });

    test("returns null for a detached HEAD, which git reports as the literal HEAD", () async {
      final runner = _FakeProcessRunner.result(exitCode: 0, stdout: "HEAD\n");

      expect(await _api(runner).getCurrentBranch(projectPath: "/repo"), isNull);
    });

    test("returns null when the directory is not a git repository", () async {
      final runner = _FakeProcessRunner.result(exitCode: 128, stdout: "");

      expect(await _api(runner).getCurrentBranch(projectPath: "/not-a-repo"), isNull);
    });

    test("returns null when git cannot start, as for a directory that no longer exists", () async {
      final runner = _FakeProcessRunner.error(
        const ProcessException("git", ["rev-parse"], "No such file or directory"),
      );

      expect(await _api(runner).getCurrentBranch(projectPath: "/gone"), isNull);
    });

    test("returns null when a repository has no commits and so names no branch", () async {
      final runner = _FakeProcessRunner.result(exitCode: 0, stdout: "\n");

      expect(await _api(runner).getCurrentBranch(projectPath: "/empty"), isNull);
    });
  });
}

GitCliApi _api(ProcessRunner runner) =>
    GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true);

typedef _Invocation = ({List<String> arguments, String? workingDirectory});

class _FakeProcessRunner implements ProcessRunner {
  _FakeProcessRunner._({ProcessResult? result, Object? error}) : _result = result, _error = error;

  factory _FakeProcessRunner.result({required int exitCode, required String stdout}) =>
      _FakeProcessRunner._(result: ProcessResult(0, exitCode, stdout, ""));

  factory _FakeProcessRunner.error(Object error) => _FakeProcessRunner._(error: error);

  final ProcessResult? _result;
  final Object? _error;
  final List<_Invocation> invocations = <_Invocation>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add((arguments: arguments, workingDirectory: workingDirectory));
    final error = _error;
    if (error != null) throw error;
    return _result!;
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnsupportedError("never starts processes");
  }
}
