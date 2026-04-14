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

    test("resolveDefaultBranch uses origin HEAD symbolic-ref when available", () async {
      processRunner.enqueue(
        result: _processResult(exitCode: 0, stdout: "refs/remotes/origin/main\n"),
      );

      final defaultBranch = await service.resolveDefaultBranch(projectPath: "/repo/project");

      expect(defaultBranch, equals("main"));
      expect(processRunner.invocations, hasLength(1));
      expect(
        processRunner.invocations.single.arguments,
        equals(["symbolic-ref", "refs/remotes/origin/HEAD"]),
      );
    });

    test("resolveDefaultBranch falls back to local HEAD symbolic-ref", () async {
      processRunner
        ..enqueue(result: _processResult(exitCode: 1, stderr: "no origin"))
        ..enqueue(result: _processResult(exitCode: 0, stdout: "refs/heads/develop\n"));

      final defaultBranch = await service.resolveDefaultBranch(projectPath: "/repo/project");

      expect(defaultBranch, equals("develop"));
      expect(processRunner.invocations, hasLength(2));
      expect(
        processRunner.invocations.first.arguments,
        equals(["symbolic-ref", "refs/remotes/origin/HEAD"]),
      );
      expect(processRunner.invocations.last.arguments, equals(["symbolic-ref", "HEAD"]));
    });

    test("resolveDefaultBranch falls back to init.defaultBranch config", () async {
      processRunner
        ..enqueue(result: _processResult(exitCode: 1))
        ..enqueue(result: _processResult(exitCode: 1))
        ..enqueue(result: _processResult(exitCode: 0, stdout: "trunk\n"));

      final defaultBranch = await service.resolveDefaultBranch(projectPath: "/repo/project");

      expect(defaultBranch, equals("trunk"));
      expect(processRunner.invocations, hasLength(3));
      expect(processRunner.invocations[2].arguments, equals(["config", "init.defaultBranch"]));
    });

    test("resolveDefaultBranch returns main when all fallbacks fail", () async {
      processRunner
        ..enqueue(result: _processResult(exitCode: 1))
        ..enqueue(result: _processResult(exitCode: 1))
        ..enqueue(result: _processResult(exitCode: 1));

      final defaultBranch = await service.resolveDefaultBranch(projectPath: "/repo/project");

      expect(defaultBranch, equals("main"));
      expect(processRunner.invocations, hasLength(3));
    });

    test("branchExists returns true for non-empty git branch --list output", () async {
      processRunner.enqueue(result: _processResult(exitCode: 0, stdout: "  main\n"));

      final exists = await service.branchExists(
        projectPath: "/repo/project",
        branchName: "main",
      );

      expect(exists, isTrue);
      expect(processRunner.invocations.single.arguments, equals(["branch", "--list", "--", "main"]));
    });

    test("branchExists returns false for empty git branch --list output", () async {
      processRunner.enqueue(result: _processResult(exitCode: 0, stdout: "  \n"));

      final exists = await service.branchExists(
        projectPath: "/repo/project",
        branchName: "feature/missing",
      );

      expect(exists, isFalse);
    });

    test("createWorktree runs git worktree add and returns success", () async {
      processRunner.enqueue(result: _processResult(exitCode: 0, stdout: "prepared"));

      final result = await service.createWorktree(
        projectPath: "/repo/project",
        worktreePath: "/repo/.worktrees/feature-x",
        branchName: "feature/x",
        startPoint: "main",
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.single.command, equals("git"));
      expect(
        processRunner.invocations.single.arguments,
        equals(["worktree", "add", "-b", "feature/x", "--", "/repo/.worktrees/feature-x", "main"]),
      );
      expect(processRunner.invocations.single.workingDirectory, equals("/repo/project"));
    });

    group("inspectWorktreeSafety", () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp("git_worktree_safety_test_");
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test("returns non-existent snapshot when worktree path is missing", () async {
        final snapshot = await service.inspectWorktreeSafety(
          worktreePath: "${tempDir.path}/missing",
        );

        expect(snapshot.worktreeExists, isFalse);
        expect(snapshot.hasUnstagedChanges, isFalse);
        expect(snapshot.actualBranch, isEmpty);
        expect(processRunner.invocations, isEmpty);
      });

      test("returns raw git status and branch details for existing worktree", () async {
        processRunner
          ..enqueue(result: _processResult(exitCode: 0, stdout: "M file.txt\n"))
          ..enqueue(result: _processResult(exitCode: 0, stdout: "main\n"));

        final snapshot = await service.inspectWorktreeSafety(
          worktreePath: tempDir.path,
        );

        expect(snapshot.worktreeExists, isTrue);
        expect(snapshot.hasUnstagedChanges, isTrue);
        expect(snapshot.actualBranch, equals("main"));
        expect(processRunner.invocations, hasLength(2));
        expect(processRunner.invocations.first.arguments, equals(["status", "--porcelain"]));
        expect(
          processRunner.invocations.last.arguments,
          equals(["rev-parse", "--abbrev-ref", "HEAD"]),
        );
      });
    });

    group("resolveStartPointForBranch", () {
      test("returns local when origin ref does not exist", () async {
        processRunner.enqueue(result: _processResult(exitCode: 128, stderr: "fatal"));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "abc123",
        );

        expect(result.ref, equals("main"));
        expect(result.commit, equals("abc123"));
        expect(processRunner.invocations, hasLength(1));
        expect(processRunner.invocations.single.arguments, equals(["rev-parse", "origin/main"]));
        expect(processRunner.invocations.single.workingDirectory, equals("/repo/project"));
      });

      test("returns local when commits are the same", () async {
        processRunner.enqueue(result: _processResult(exitCode: 0, stdout: "abc123\n"));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "abc123",
        );

        expect(result.ref, equals("main"));
        expect(result.commit, equals("abc123"));
        expect(processRunner.invocations, hasLength(1));
        expect(processRunner.invocations.single.arguments, equals(["rev-parse", "origin/main"]));
      });

      test("returns local when local is strictly ahead", () async {
        processRunner
          ..enqueue(result: _processResult(exitCode: 0, stdout: "def456\n"))
          ..enqueue(result: _processResult(exitCode: 0));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "abc123",
        );

        expect(result.ref, equals("main"));
        expect(result.commit, equals("abc123"));
        expect(processRunner.invocations, hasLength(2));
        expect(processRunner.invocations[0].arguments, equals(["rev-parse", "origin/main"]));
        expect(
          processRunner.invocations[1].arguments,
          equals(["merge-base", "--is-ancestor", "def456", "abc123"]),
        );
      });

      test("returns origin when origin is strictly ahead", () async {
        processRunner
          ..enqueue(result: _processResult(exitCode: 0, stdout: "def456\n"))
          ..enqueue(result: _processResult(exitCode: 1));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "abc123",
        );

        expect(result.ref, equals("origin/main"));
        expect(result.commit, equals("def456"));
        expect(processRunner.invocations, hasLength(2));
        expect(processRunner.invocations[0].arguments, equals(["rev-parse", "origin/main"]));
        expect(
          processRunner.invocations[1].arguments,
          equals(["merge-base", "--is-ancestor", "def456", "abc123"]),
        );
      });

      test("returns origin when branches have diverged", () async {
        processRunner
          ..enqueue(result: _processResult(exitCode: 0, stdout: "diverged-origin\n"))
          ..enqueue(result: _processResult(exitCode: 1));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "diverged-local",
        );

        expect(result.ref, equals("origin/main"));
        expect(result.commit, equals("diverged-origin"));
        expect(processRunner.invocations, hasLength(2));
      });

      test("returns origin when merge-base command fails", () async {
        processRunner
          ..enqueue(result: _processResult(exitCode: 0, stdout: "def456\n"))
          ..enqueue(result: _processResult(exitCode: 128, stderr: "fatal"));

        final result = await service.resolveStartPointForBranch(
          projectPath: "/repo/project",
          baseBranch: "main",
          localCommit: "abc123",
        );

        expect(result.ref, equals("origin/main"));
        expect(result.commit, equals("def456"));
        expect(processRunner.invocations, hasLength(2));
      });
    });
  });
}

ProcessResult _processResult({
  required int exitCode,
  String stdout = "",
  String stderr = "",
}) {
  return ProcessResult(1, exitCode, stdout, stderr);
}

class _Invocation {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;

  const _Invocation({
    required this.command,
    required this.arguments,
    required this.workingDirectory,
  });
}

class _FakeProcessRunner implements ProcessRunner {
  final List<_Invocation> invocations = <_Invocation>[];
  final List<ProcessResult> _results = <ProcessResult>[];

  void enqueue({required ProcessResult result}) {
    _results.add(result);
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(
      _Invocation(
        command: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );

    if (_results.isEmpty) {
      throw StateError("No ProcessResult queued for invocation: $executable $arguments");
    }

    return _results.removeAt(0);
  }
}
