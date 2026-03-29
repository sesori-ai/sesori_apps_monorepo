import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

const _projectId = "/repo/project";

void main() {
  group("WorktreeService.prepareWorktreeForSession", () {
    late _FakeProcessRunner processRunner;
    late bool gitDirectoryExists;
    late AppDatabase db;
    late ProjectsDao projectsDao;
    late SessionDao sessionDao;
    late WorktreeService service;

    setUp(() {
      db = createTestDatabase();
      projectsDao = db.projectsDao;
      sessionDao = db.sessionDao;
      processRunner = _FakeProcessRunner();
      gitDirectoryExists = true;
      service = WorktreeService(
        projectsDao: projectsDao,
        sessionDao: sessionDao,
        processRunner: processRunner.call,
        gitPathExists: ({required String gitPath}) => gitDirectoryExists,
      );
    });

    tearDown(() async {
      await db.close();
    });

    // -----------------------------------------------------------------------
    // Happy path
    // -----------------------------------------------------------------------

    test("happy path: creates worktree from resolved default branch", () async {
      // git rev-parse HEAD → success
      processRunner.enqueue(result: _ok());
      // git symbolic-ref refs/remotes/origin/HEAD → "refs/remotes/origin/main"
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git branch --list session-001 → empty (branch does not exist)
      processRunner.enqueue(result: _ok(stdout: ""));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/session-001"));
      expect(success.branchName, equals("session-001"));

      // Verify the worktree add command used "main" as base branch
      final worktreeAddCall = processRunner.invocations.last;
      expect(worktreeAddCall.arguments, contains("main"));
      expect(worktreeAddCall.arguments, contains("session-001"));
    });

    test("parent session: reuses parent worktree when mapping exists", () async {
      // Insert a mapping for the parent session.
      await sessionDao.insertMapping(
        sessionId: "parent-001",
        projectId: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        branchName: "session-001",
      );

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: "parent-001",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/session-001"));
      expect(success.branchName, equals("session-001"));
      // No git commands should have been called — worktree already exists.
      expect(processRunner.invocations, isEmpty);
    });

    test("parent session: falls through to create new when parent has no mapping", () async {
      // git rev-parse HEAD → success
      processRunner.enqueue(result: _ok());
      // git symbolic-ref refs/remotes/origin/HEAD → "refs/remotes/origin/main"
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git branch --list session-001 → empty
      processRunner.enqueue(result: _ok(stdout: ""));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: "nonexistent-parent",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, contains("session-001"));
    });

    // -----------------------------------------------------------------------
    // Non-git fallback
    // -----------------------------------------------------------------------

    test("non-git fallback: returns WorktreeFallback when not a git repo", () async {
      gitDirectoryExists = false;

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.originalPath, equals(_projectId));
      expect(fallback.reason, equals("not a git repository"));
      expect(processRunner.invocations, isEmpty);
    });

    // -----------------------------------------------------------------------
    // No commits fallback
    // -----------------------------------------------------------------------

    test("no commits fallback: returns WorktreeFallback when no commits", () async {
      // git rev-parse HEAD → failure
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal: ambiguous argument"));

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.reason, equals("repository has no commits"));
      expect(processRunner.invocations, hasLength(1));
    });

    // -----------------------------------------------------------------------
    // Branch collision retry
    // -----------------------------------------------------------------------

    test("branch collision retry: skips existing branch, succeeds on second attempt", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // branch --list session-001 → non-empty (collision!)
      processRunner.enqueue(result: _ok(stdout: "  session-001\n"));
      // branch --list session-002 → empty (free)
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, equals("session-002"));
      expect(success.path, equals("$_projectId/.worktrees/session-002"));
    });

    // -----------------------------------------------------------------------
    // Git failure fallback (all 3 attempts fail)
    // -----------------------------------------------------------------------

    test("git failure fallback: returns WorktreeFallback after 3 failed attempts", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // Attempt 1: branch --list session-001 → empty, worktree add → fail
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      // Attempt 2: branch --list session-002 → empty, worktree add → fail
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      // Attempt 3: branch --list session-003 → empty, worktree add → fail
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.originalPath, equals(_projectId));
      expect(fallback.reason, equals("failed to create worktree after 3 attempts"));
    });

    // -----------------------------------------------------------------------
    // Stored base branch used
    // -----------------------------------------------------------------------

    test("stored base branch: uses stored branch when it exists", () async {
      await projectsDao.setBaseBranch(
        projectId: _projectId,
        baseBranch: "develop",
      );

      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // branch --list develop → non-empty (exists)
      processRunner.enqueue(result: _ok(stdout: "  develop\n"));
      // branch --list session-001 → empty
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());

      // Verify worktree add used "develop" as base branch
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs, contains("develop"));
      // Should NOT have called symbolic-ref (no need to resolve default branch)
      expect(
        processRunner.invocations.any(
          (inv) => inv.arguments.contains("symbolic-ref"),
        ),
        isFalse,
      );
    });

    // -----------------------------------------------------------------------
    // Stored base branch invalid (branch does not exist)
    // -----------------------------------------------------------------------

    test("stored base branch invalid: falls back to resolveDefaultBranch", () async {
      await projectsDao.setBaseBranch(
        projectId: _projectId,
        baseBranch: "old-branch",
      );

      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // branch --list old-branch → empty (does not exist)
      processRunner.enqueue(result: _ok(stdout: ""));
      // symbolic-ref refs/remotes/origin/HEAD → "refs/remotes/origin/main"
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // branch --list session-001 → empty
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());

      // Worktree add should have used "main" (from resolved default branch)
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs, contains("main"));
      expect(worktreeAddArgs, isNot(contains("old-branch")));
    });
  });

  // -------------------------------------------------------------------------
  // recordSessionWorktree
  // -------------------------------------------------------------------------

  group("WorktreeService.recordSessionWorktree", () {
    late AppDatabase db;
    late WorktreeService service;

    setUp(() {
      db = createTestDatabase();
      service = WorktreeService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: _FakeProcessRunner().call,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("stores session-to-worktree mapping in the database", () async {
      await service.recordSessionWorktree(
        sessionId: "ses-42",
        projectId: _projectId,
        worktreePath: "$_projectId/.worktrees/session-042",
        branchName: "session-042",
      );

      final stored = await db.sessionDao.getWorktreeForSession(
        sessionId: "ses-42",
      );

      expect(stored, isNotNull);
      expect(stored!.sessionId, equals("ses-42"));
      expect(stored.projectId, equals(_projectId));
      expect(stored.worktreePath, equals("$_projectId/.worktrees/session-042"));
      expect(stored.branchName, equals("session-042"));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProcessResult _ok({String stdout = "", String stderr = ""}) {
  return ProcessResult(1, 0, stdout, stderr);
}

ProcessResult _fail({required int exitCode, String stderr = ""}) {
  return ProcessResult(1, exitCode, "", stderr);
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

class _FakeProcessRunner {
  final List<_Invocation> invocations = <_Invocation>[];
  final List<ProcessResult> _queue = <ProcessResult>[];

  void enqueue({required ProcessResult result}) {
    _queue.add(result);
  }

  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    invocations.add(
      _Invocation(
        command: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );

    if (_queue.isEmpty) {
      throw StateError("No ProcessResult queued for: $executable $arguments");
    }

    return _queue.removeAt(0);
  }
}
