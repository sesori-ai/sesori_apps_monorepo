import "dart:io";

import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
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

  test("listTrackedFiles parses the null-delimited tracked path list", () async {
    final processRunner = _RecordingProcessRunner(
      stdout: "README.md\u0000lib/src/SesoriClient.dart\u0000",
    );
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => true,
    );

    final paths = await api.listTrackedFiles(projectPath: "/project");

    expect(paths, ["README.md", "lib/src/SesoriClient.dart"]);
    expect(processRunner.workingDirectory, "/project");
    expect(processRunner.arguments, ["ls-files", "--cached", "-z", "--", "."]);
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

  test("isValidBranchName delegates to git check-ref-format", () async {
    for (final testCase in [
      (exitCode: 0, stdout: "generated-branch\n", expected: true),
      (exitCode: 1, stdout: "", expected: false),
      (exitCode: 128, stdout: "", expected: false),
      (exitCode: 0, stdout: "previous-branch\n", expected: false),
    ]) {
      final processRunner = _RecordingProcessRunner(exitCode: testCase.exitCode, stdout: testCase.stdout);
      final api = GitCliApi(
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => true,
      );

      expect(await api.isValidBranchName(branchName: "generated-branch"), testCase.expected);
      expect(processRunner.arguments, ["check-ref-format", "--branch", "generated-branch"]);
    }
  });

  test("hasUpstream reads the exact local branch ref", () async {
    final processRunner = _RecordingProcessRunner(stdout: "refs/remotes/origin/initial-branch\n");
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => true,
    );

    expect(
      await api.hasUpstream(projectPath: "/worktree", branchName: "initial-branch"),
      isTrue,
    );
    expect(processRunner.workingDirectory, "/worktree");
    expect(processRunner.arguments, [
      "for-each-ref",
      "--format=%(upstream)",
      "refs/heads/initial-branch",
    ]);
  });

  test("hasRemoteBranch finds the exact branch name under any remote", () async {
    final processRunner = _RecordingProcessRunner(
      results: [
        ProcessResult(1, 0, "origin\nteam/origin\n", ""),
        ProcessResult(
          1,
          0,
          "refs/remotes/origin/HEAD\nrefs/remotes/team/origin/initial-branch\n",
          "",
        ),
      ],
    );
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => true,
    );

    expect(
      await api.hasRemoteBranch(projectPath: "/worktree", branchName: "initial-branch"),
      isTrue,
    );
    expect(processRunner.workingDirectory, "/worktree");
    expect(processRunner.invocations, [
      ["remote"],
      ["for-each-ref", "--format=%(refname)", "refs/remotes"],
    ]);
  });

  test("renameBranch uses explicit old and new refs and preserves failures", () async {
    final processRunner = _RecordingProcessRunner();
    final api = GitCliApi(
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => true,
    );

    await api.renameBranch(
      projectPath: "/worktree",
      oldBranchName: "initial-branch",
      newBranchName: "generated-branch",
    );

    expect(processRunner.workingDirectory, "/worktree");
    expect(processRunner.arguments, [
      "branch",
      "-m",
      "--",
      "initial-branch",
      "generated-branch",
    ]);

    final failingApi = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 128, stderr: "rename failed"),
      gitPathExists: ({required String gitPath}) => true,
    );
    await expectLater(
      failingApi.renameBranch(
        projectPath: "/worktree",
        oldBranchName: "initial-branch",
        newBranchName: "generated-branch",
      ),
      throwsA(isA<ProcessException>()),
    );
  });
}

class _RecordingProcessRunner({
  final String stdout = "",
  final String stderr = "",
  final int exitCode = 0,
  final List<ProcessResult>? results,
}) implements ProcessRunner {
  List<String>? arguments;
  final List<List<String>> invocations = [];
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
    invocations.add(arguments);
    this.workingDirectory = workingDirectory;
    this.environment = environment;
    if (results case final results? when results.isNotEmpty) return results.removeAt(0);
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
