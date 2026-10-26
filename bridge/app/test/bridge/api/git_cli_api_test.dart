import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:test/test.dart";

void main() {
  test("commitAll disables signing for the command-scoped identity", () async {
    final processRunner = _RecordingProcessRunner();
    final api = GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
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
      "--allow-empty",
      "-m",
      "Initial commit",
    ]);
  });

  test("isInsideGitWorkTree queries Git membership", () async {
    final processRunner = _RecordingProcessRunner(stdout: "true\n");
    final api = GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => false,
    );

    final isInside = await api.isInsideGitWorkTree(projectPath: "/project/child");

    expect(isInside, isTrue);
    expect(processRunner.workingDirectory, "/project/child");
    expect(processRunner.arguments, ["rev-parse", "--is-inside-work-tree"]);
    expect(processRunner.environment, const {"LC_ALL": "C"});
  });

  test("isInsideGitWorkTree distinguishes non-repositories from operational failures", () async {
    final nonRepositoryApi = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 128, stderr: "fatal: not a git repository"),
      streamingProcessRunner: const StreamingProcessRunner(),
      gitPathExists: ({required String gitPath}) => false,
    );
    final failingApi = GitCliApi(
      processRunner: _RecordingProcessRunner(exitCode: 128, stderr: "fatal: detected dubious ownership"),
      streamingProcessRunner: const StreamingProcessRunner(),
      gitPathExists: ({required String gitPath}) => true,
    );

    expect(await nonRepositoryApi.isInsideGitWorkTree(projectPath: "/plain"), isFalse);
    await expectLater(
      failingApi.isInsideGitWorkTree(projectPath: "/mounted"),
      throwsA(isA<ProcessException>()),
    );
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
        streamingProcessRunner: const StreamingProcessRunner(),
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
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: _RecordingProcessRunner(exitCode: 1),
      gitPathExists: ({required String gitPath}) => true,
    );
    final nonGitApi = GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: _RecordingProcessRunner(exitCode: 128, stderr: "fatal: not a git repository"),
      gitPathExists: ({required String gitPath}) => true,
    );
    final missingRunner = _RecordingProcessRunner();
    final missingApi = GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
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
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: _RecordingProcessRunner(exitCode: 2, stderr: "unexpected failure"),
      gitPathExists: ({required String gitPath}) => true,
    );

    await expectLater(
      api.getCurrentBranch(projectPath: "/project"),
      throwsA(isA<ProcessException>()),
    );
  });

  test("streams only the requested tracked-file prefix through the injected process boundary", () async {
    final process = _FakeStreamingProcess(
      stdoutChunks: [utf8.encode("a.dart\u0000b."), utf8.encode("dart\u0000c.dart\u0000")],
    );
    final runner = _FakeStreamingProcessRunner(process);
    final api = GitCliApi(
      processRunner: _RecordingProcessRunner(),
      streamingProcessRunner: runner,
      gitPathExists: ({required String gitPath}) => true,
    );

    final paths = await api.listTrackedFiles(projectPath: "/project", maximumPaths: 2);

    expect(paths, ["a.dart", "b.dart"]);
    expect(runner.executable, "git");
    expect(runner.arguments, ["ls-files", "--cached", "-z", "--", "."]);
    expect(runner.workingDirectory, "/project");
    expect(runner.environment, const {"LC_ALL": "C"});
  });

  test("tolerates malformed UTF-8 bytes in tracked filenames", () async {
    final process = _FakeStreamingProcess(
      stdoutChunks: [
        [...utf8.encode("good.dart\u0000bad_"), 0xff, ...utf8.encode(".dart\u0000")],
      ],
    );
    final api = GitCliApi(
      processRunner: _RecordingProcessRunner(),
      streamingProcessRunner: _FakeStreamingProcessRunner(process),
      gitPathExists: ({required String gitPath}) => true,
    );

    final paths = await api.listTrackedFiles(projectPath: "/project", maximumPaths: 10);

    expect(paths, ["good.dart", "bad_\uFFFD.dart"]);
  });

  test("checks Git failure after reaching the tracked-file limit", () async {
    final runner = _FakeStreamingProcessRunner(
      _FakeStreamingProcess(
        stdoutChunks: [utf8.encode("a.dart\u0000ignored.dart\u0000")],
        stderrChunks: [utf8.encode("fatal: index read failed")],
        exitCode: 128,
      ),
    );
    final api = GitCliApi(
      processRunner: _RecordingProcessRunner(),
      streamingProcessRunner: runner,
      gitPathExists: ({required String gitPath}) => true,
    );

    await expectLater(
      api.listTrackedFiles(projectPath: "/project", maximumPaths: 1),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.errorCode, "errorCode", 128)
            .having((error) => error.message, "message", contains("index read failed")),
      ),
    );
  });

  test("rejects a non-positive tracked-file bound before starting Git", () async {
    final runner = _FakeStreamingProcessRunner(_FakeStreamingProcess(stdoutChunks: const []));
    final api = GitCliApi(
      processRunner: _RecordingProcessRunner(),
      streamingProcessRunner: runner,
      gitPathExists: ({required String gitPath}) => true,
    );

    await expectLater(
      () => api.listTrackedFiles(projectPath: "/unused", maximumPaths: 0),
      throwsArgumentError,
    );

    expect(runner.runCount, 0);
  });

  group("worktrees in a real repository", () {
    final api = GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: ProcessRunner(),
      gitPathExists: ({required String gitPath}) => true,
    );
    late Directory root;
    late String repoPath;
    late String worktreePath;
    late String baseCommit;

    Future<String> git({required String cwd, required List<String> args}) async {
      final result = await Process.run(
        "git",
        ["-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgSign=false", ...args],
        workingDirectory: cwd,
      );
      if (result.exitCode != 0) fail("git ${args.join(" ")} failed: ${result.stderr}");
      return result.stdout.toString().trim();
    }

    Future<void> commit({required String cwd, required String message}) =>
        git(cwd: cwd, args: ["commit", "--quiet", "--allow-empty", "-m", message]);

    setUp(() async {
      root = await Directory.systemTemp.createTemp("git_no_branch_test_");
      repoPath = "${root.path}/repo";
      worktreePath = "${root.path}/worktree";
      await git(cwd: root.path, args: ["init", "--quiet", repoPath]);
      await commit(cwd: repoPath, message: "base");
      baseCommit = await git(cwd: repoPath, args: ["rev-parse", "HEAD"]);
    });

    tearDown(() => root.delete(recursive: true));

    test("createWorktree starts a detached HEAD at the start point without creating a branch", () async {
      final baseBranch = await git(cwd: repoPath, args: ["rev-parse", "--abbrev-ref", "HEAD"]);
      await commit(cwd: repoPath, message: "tip");
      final tipCommit = await git(cwd: repoPath, args: ["rev-parse", "HEAD"]);

      final created = await api.createWorktree(
        projectPath: repoPath,
        worktreePath: worktreePath,
        startPoint: baseBranch,
      );

      expect(created, isTrue);
      final symbolicRef = await Process.run("git", ["symbolic-ref", "-q", "HEAD"], workingDirectory: worktreePath);
      expect(symbolicRef.exitCode, isNot(0), reason: "HEAD must be detached");
      expect(await git(cwd: worktreePath, args: ["rev-parse", "HEAD"]), tipCommit);
      expect(await git(cwd: repoPath, args: ["for-each-ref", "--format=%(refname:short)", "refs/heads"]), baseBranch);
    });

    test("flags a commit made on a detached HEAD", () async {
      await git(cwd: repoPath, args: ["worktree", "add", "--quiet", "--detach", worktreePath, baseCommit]);
      await commit(cwd: worktreePath, message: "detached work");

      final snapshot = await api.inspectWorktreeSafety(worktreePath: worktreePath, baseCommit: baseCommit);

      expect(snapshot.hasCommitsOnNoBranch, isTrue);
      expect(snapshot.hasUnstagedChanges, isFalse);
    });

    test("a detached HEAD at the base commit stays clean after the base branch is rewritten", () async {
      await git(cwd: repoPath, args: ["worktree", "add", "--quiet", "--detach", worktreePath, baseCommit]);
      // No branch reaches the base commit any more; only its exclusion keeps it clean.
      await git(cwd: repoPath, args: ["commit", "--quiet", "--allow-empty", "--amend", "-m", "rewritten base"]);

      final snapshot = await api.inspectWorktreeSafety(worktreePath: worktreePath, baseCommit: baseCommit);

      expect(snapshot.hasCommitsOnNoBranch, isFalse);
    });

    test("new commits on a branch are clean", () async {
      await git(cwd: repoPath, args: ["worktree", "add", "--quiet", "-b", "sesori/task", worktreePath, baseCommit]);
      await commit(cwd: worktreePath, message: "branch work");

      final snapshot = await api.inspectWorktreeSafety(worktreePath: worktreePath, baseCommit: baseCommit);

      expect(snapshot.hasCommitsOnNoBranch, isFalse);
    });
  });
}

class _RecordingProcessRunner({
  final String stdout = "",
  final String stderr = "",
  final int exitCode = 0,
}) implements ProcessRunner {
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

class _FakeStreamingProcessRunner(final StreamingProcess process) extends StreamingProcessRunner {
  int runCount = 0;
  String? executable;
  List<String>? arguments;
  String? workingDirectory;
  Map<String, String>? environment;

  @override
  Future<T> run<T>({
    required String executable,
    required List<String> arguments,
    required Future<T> Function({required StreamingProcess process}) operation,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) {
    runCount++;
    this.executable = executable;
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
    this.environment = environment;
    return operation(process: process);
  }
}

class _FakeStreamingProcess({
  required final List<List<int>> stdoutChunks,
  final List<List<int>> stderrChunks = const [],
  final int _exitCode = 0,
}) implements StreamingProcess {
  @override
  Stream<List<int>> get stdout => Stream.fromIterable(stdoutChunks);

  @override
  Stream<List<int>> get stderr => Stream.fromIterable(stderrChunks);

  @override
  Future<int> get exitCode async => _exitCode;

  @override
  bool kill() => true;
}
