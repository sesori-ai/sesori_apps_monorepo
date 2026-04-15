import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  group("GitCliApi", () {
    late _FakeProcessRunner processRunner;
    late bool gitDirectoryExists;
    late GitCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      gitDirectoryExists = false;
      service = GitCliApi(
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => gitDirectoryExists,
      );
    });

    test("isGitInitialized returns true when .git exists", () async {
      gitDirectoryExists = true;
      final isInitialized = await service.isGitInitialized(projectPath: "/repo/project");
      expect(isInitialized, isTrue);
    });

    test("isGitInitialized returns false when .git does not exist", () async {
      gitDirectoryExists = false;
      final isInitialized = await service.isGitInitialized(projectPath: "/repo/project");
      expect(isInitialized, isFalse);
    });

    test("hasAtLeastOneCommit returns true when git rev-parse HEAD succeeds", () async {
      processRunner.enqueue(result: _processResult(exitCode: 0));
      final hasCommit = await service.hasAtLeastOneCommit(projectPath: "/repo/project");
      expect(hasCommit, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.single.command, equals("git"));
      expect(processRunner.invocations.single.arguments, equals(["rev-parse", "HEAD"]));
      expect(processRunner.invocations.single.workingDirectory, equals("/repo/project"));
    });

    test("hasAtLeastOneCommit returns false when git rev-parse HEAD fails", () async {
      processRunner.enqueue(result: _processResult(exitCode: 128, stderr: "fatal"));
      final hasCommit = await service.hasAtLeastOneCommit(projectPath: "/repo/project");
      expect(hasCommit, isFalse);
    });
  });
}

class _FakeProcessRunner implements ProcessRunner {
  final List<_Invocation> invocations = [];
  final List<ProcessResult> _results = [];

  void enqueue({required ProcessResult result}) => _results.add(result);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(_Invocation(command: executable, arguments: arguments, workingDirectory: workingDirectory));
    if (_results.isEmpty) {
      throw StateError("No queued ProcessResult for $executable ${arguments.join(' ')}");
    }
    return _results.removeAt(0);
  }
}

class _Invocation {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;

  const _Invocation({required this.command, required this.arguments, required this.workingDirectory});
}

ProcessResult _processResult({required int exitCode, String stdout = "", String stderr = ""}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
