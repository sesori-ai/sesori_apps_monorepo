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
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
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
      expect(success.baseBranch, equals("main"));
      expect(success.baseCommit, equals("abc123def456"));

      // Verify the worktree add command used "main" as base branch
      final worktreeAddCall = processRunner.invocations.last;
      expect(worktreeAddCall.arguments, contains("main"));
      expect(worktreeAddCall.arguments, contains("session-001"));
    });

    test("parent session: reuses parent worktree when mapping exists", () async {
      // Insert a mapping for the parent session.
      await sessionDao.insertSession(
        sessionId: "parent-001",
        projectId: _projectId,
        isDedicated: true,
        createdAt: 123,
        worktreePath: "$_projectId/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "sha-parent",
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
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
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
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
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
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
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
      // git rev-parse develop → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "deadbeef1234\n"));
      // branch --list session-001 → empty
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseBranch, equals("develop"));
      expect(success.baseCommit, equals("deadbeef1234"));

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
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
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
  // checkWorktreeSafety
  // -------------------------------------------------------------------------

  group("WorktreeService.checkWorktreeSafety", () {
    late _FakeProcessRunner processRunner;
    late AppDatabase db;
    late WorktreeService service;
    late Directory tempDir;

    setUp(() async {
      db = createTestDatabase();
      processRunner = _FakeProcessRunner();
      service = WorktreeService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: processRunner.call,
        gitPathExists: ({required String gitPath}) => true,
      );
      tempDir = await Directory.systemTemp.createTemp("worktree_safety_test_");
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("clean worktree + correct branch: returns WorktreeSafe", () async {
      // git status --porcelain → empty (clean)
      processRunner.enqueue(result: _ok(stdout: ""));
      // git rev-parse --abbrev-ref HEAD → "session-001"
      processRunner.enqueue(result: _ok(stdout: "session-001\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeSafe>());
      expect(processRunner.invocations, hasLength(2));
    });

    test("dirty worktree: returns WorktreeUnsafe with UnstagedChanges", () async {
      // git status --porcelain → non-empty (dirty)
      processRunner.enqueue(result: _ok(stdout: "M file.txt\n"));
      // git rev-parse --abbrev-ref HEAD → "session-001"
      processRunner.enqueue(result: _ok(stdout: "session-001\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.first, isA<UnstagedChanges>());
    });

    test("wrong branch: returns WorktreeUnsafe with BranchMismatch", () async {
      // git status --porcelain → empty (clean)
      processRunner.enqueue(result: _ok(stdout: ""));
      // git rev-parse --abbrev-ref HEAD → "main" (wrong branch)
      processRunner.enqueue(result: _ok(stdout: "main\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      final issue = unsafe.issues.first;
      expect(issue, isA<BranchMismatch>());
      final mismatch = issue as BranchMismatch;
      expect(mismatch.expected, equals("session-001"));
      expect(mismatch.actual, equals("main"));
    });

    test("dirty + wrong branch: returns WorktreeUnsafe with both issues", () async {
      // git status --porcelain → non-empty (dirty)
      processRunner.enqueue(result: _ok(stdout: "M file.txt\nA new.dart\n"));
      // git rev-parse --abbrev-ref HEAD → "main" (wrong branch)
      processRunner.enqueue(result: _ok(stdout: "main\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(2));
      expect(unsafe.issues.whereType<UnstagedChanges>(), hasLength(1));
      expect(unsafe.issues.whereType<BranchMismatch>(), hasLength(1));
    });

    test("non-existent path: returns WorktreeUnsafe with WorktreeNotFound, no git commands called", () async {
      const nonExistentPath = "/tmp/this_path_does_not_exist_sesori_test_12345";

      final result = await service.checkWorktreeSafety(
        worktreePath: nonExistentPath,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.first, isA<WorktreeNotFound>());
      // No git commands should have been called
      expect(processRunner.invocations, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // pruneWorktrees / removeWorktree / deleteBranch / restoreWorktree
  // -------------------------------------------------------------------------

  group("WorktreeService lifecycle methods", () {
    late _FakeProcessRunner processRunner;
    late AppDatabase db;
    late WorktreeService service;

    setUp(() {
      db = createTestDatabase();
      processRunner = _FakeProcessRunner();
      service = WorktreeService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: processRunner.call,
        gitPathExists: ({required String gitPath}) => true,
      );
    });

    tearDown(() async {
      await db.close();
    });

    // pruneWorktrees

    test("pruneWorktrees: calls git worktree prune with projectPath", () async {
      processRunner.enqueue(result: _ok());

      await service.pruneWorktrees(projectPath: _projectId);

      expect(processRunner.invocations, hasLength(1));
      final inv = processRunner.invocations.first;
      expect(inv.arguments, equals(["worktree", "prune"]));
      expect(inv.workingDirectory, equals(_projectId));
    });

    // removeWorktree (force: false)

    test("removeWorktree(force: false): calls prune then remove without --force", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        projectPath: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        force: false,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final pruneInv = processRunner.invocations[0];
      expect(pruneInv.arguments, equals(["worktree", "prune"]));

      final removeInv = processRunner.invocations[1];
      expect(removeInv.arguments, equals(["worktree", "remove", "--", "$_projectId/.worktrees/session-001"]));
      expect(removeInv.arguments, isNot(contains("--force")));
      expect(removeInv.workingDirectory, equals(_projectId));
    });

    // removeWorktree (force: true)

    test("removeWorktree(force: true): calls prune then remove with --force", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove --force <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        projectPath: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        force: true,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final removeInv = processRunner.invocations[1];
      expect(
        removeInv.arguments,
        equals(["worktree", "remove", "--force", "--", "$_projectId/.worktrees/session-001"]),
      );
    });

    // removeWorktree failure → returns false

    test("removeWorktree: returns false on non-zero exit code, does not throw", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove → failure
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal: not a worktree"));

      final result = await service.removeWorktree(
        projectPath: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        force: false,
      );

      expect(result, isFalse);
    });

    // deleteBranch (force: false)

    test("deleteBranch(force: false): calls git branch -d <branch>", () async {
      processRunner.enqueue(result: _ok());

      final result = await service.deleteBranch(
        projectPath: _projectId,
        branchName: "session-001",
        force: false,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(1));
      final inv = processRunner.invocations.first;
      expect(inv.arguments, equals(["branch", "-d", "--", "session-001"]));
      expect(inv.workingDirectory, equals(_projectId));
    });

    // deleteBranch (force: true)

    test("deleteBranch(force: true): calls git branch -D <branch>", () async {
      processRunner.enqueue(result: _ok());

      final result = await service.deleteBranch(
        projectPath: _projectId,
        branchName: "session-001",
        force: true,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(1));
      final inv = processRunner.invocations.first;
      expect(inv.arguments, equals(["branch", "-D", "--", "session-001"]));
    });

    // restoreWorktree — branch exists

    test("restoreWorktree: branch exists → calls rev-parse then worktree add without -b", () async {
      // git rev-parse --verify refs/heads/session-001 → exit 0 (branch exists)
      processRunner.enqueue(result: _ok(stdout: "abc123\n"));
      // git worktree add <path> <branch>
      processRunner.enqueue(result: _ok());

      final result = await service.restoreWorktree(
        projectPath: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: null,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final verifyInv = processRunner.invocations[0];
      expect(verifyInv.arguments, equals(["rev-parse", "--verify", "--", "refs/heads/session-001"]));

      final addInv = processRunner.invocations[1];
      expect(addInv.arguments, equals(["worktree", "add", "--", "$_projectId/.worktrees/session-001", "session-001"]));
      expect(addInv.arguments, isNot(contains("-b")));
      expect(addInv.workingDirectory, equals(_projectId));
    });

    // restoreWorktree — branch does not exist

    test("restoreWorktree: branch missing → calls rev-parse then worktree add with -b and baseBranch", () async {
      // git rev-parse --verify refs/heads/session-001 → exit 128 (branch missing)
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal: Needed a single revision"));
      // git worktree add <path> -b <branch> <baseBranch>
      processRunner.enqueue(result: _ok());

      final result = await service.restoreWorktree(
        projectPath: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123def",
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final addInv = processRunner.invocations[1];
      expect(
        addInv.arguments,
        equals(["worktree", "add", "-b", "session-001", "--", "$_projectId/.worktrees/session-001", "abc123def"]),
      );
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
