import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  test("commitAll disables signing for the command-scoped identity", () async {
    final processRunner = _RecordingProcessRunner();
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => false,
    );

    final committed = await api.commitAll(
      projectPath: "/project",
      message: "Initial commit",
    );

    expect(committed, isTrue);
    expect(processRunner.workingDirectory, "/project");
    expect(processRunner.arguments, [
      "-c",
      "user.name=Sesori",
      "-c",
      "user.email=sesori@localhost",
      "-c",
      "commit.gpgSign=false",
      "commit",
      "-m",
      "Initial commit",
    ]);
  });

  test("isInsideGitWorkTree queries Git membership", () async {
    final processRunner = _RecordingProcessRunner(stdout: "true\n");
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => false,
    );

    final isInside = await api.isInsideGitWorkTree(projectPath: "/project/child");

    expect(isInside, isTrue);
    expect(processRunner.workingDirectory, "/project/child");
    expect(processRunner.arguments, ["rev-parse", "--is-inside-work-tree"]);
  });

  test("getCurrentBranch removes one line ending without trimming the branch", () async {
    for (final testCase in [
      (stdout: "Feature/Current\n", expected: "Feature/Current"),
      (stdout: "\u2003Feature/Current\u2003\r\n", expected: "\u2003Feature/Current\u2003"),
      (stdout: "Feature/Current\r", expected: "Feature/Current"),
      (stdout: "Feature/Current\n\n", expected: "Feature/Current\n"),
    ]) {
      final processRunner = _RecordingProcessRunner(stdout: testCase.stdout);
      final api = GitCliApi(
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => true,
      );

      final result = await api.getCurrentBranch(projectPath: "/project");

      expect(result, isA<GitCurrentBranchNamed>());
      expect((result as GitCurrentBranchNamed).branchName, testCase.expected);
      expect(processRunner.arguments, ["symbolic-ref", "--quiet", "--short", "HEAD"]);
      expect(processRunner.environment, const {"LC_ALL": "C"});
    }
  });

  test("getCurrentBranch distinguishes detached, non-git, and missing directories", () async {
    final detachedApi = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 1),
      gitPathExists: ({required String gitPath}) => true,
    );
    final nonGitApi = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 128, stderr: "fatal: not a git repository"),
      gitPathExists: ({required String gitPath}) => true,
    );
    final missingRunner = _RecordingProcessRunner();
    final missingApi = GitCliApi(
      processRunner: missingRunner,
      gitPathExists: ({required String gitPath}) => false,
    );

    expect(await detachedApi.getCurrentBranch(projectPath: "/detached"), isA<GitCurrentBranchDetached>());
    expect(await nonGitApi.getCurrentBranch(projectPath: "/plain"), isA<GitCurrentBranchNotRepository>());
    expect(
      await missingApi.getCurrentBranch(projectPath: "/missing"),
      isA<GitCurrentBranchMissingDirectory>(),
    );
    expect(missingRunner.arguments, isNull);
  });

  test("getCurrentBranch preserves unexpected git failures", () async {
    final api = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 2, stderr: "unexpected failure"),
      gitPathExists: ({required String gitPath}) => true,
    );

    await expectLater(
      api.getCurrentBranch(projectPath: "/project"),
      throwsA(isA<ProcessException>()),
    );
  });
}

class _RecordingProcessRunner({this.stdout = "", this.stderr = "", this.exitCode = 0}) implements ProcessRunner {
  final String stdout;
  final String stderr;
  final int exitCode;
  List<String>? arguments;
  String? workingDirectory;
  Map<String, String>? environment;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    expect(executable, "git");
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
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
