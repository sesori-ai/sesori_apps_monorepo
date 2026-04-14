import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_shared/sesori_shared.dart";
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
        branchRepository: BranchRepository(gitCliApi: GitCliApi(processRunner: processRunner)),
        projectsDao: projectsDao,
        sessionDao: sessionDao,
        processRunner: processRunner,
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
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      await projectsDao.insertProjectsIfMissing(projectIds: [_projectId]); // satisfy v5 FK constraint
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
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      // git rev-parse origin/develop → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
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

    // -----------------------------------------------------------------------
    // Preferred branch name
    // -----------------------------------------------------------------------

    test("preferred branch name succeeds: creates worktree with preferred name", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // branch --list my-feature → empty (preferred name available)
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
        preferredBranchAndWorktreeName: (branchName: "my-feature", worktreeName: "my-feature"),
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, equals("my-feature"));
      expect(success.path, equals("$_projectId/.worktrees/my-feature"));
      expect(success.baseBranch, equals("main"));
      expect(success.baseCommit, equals("abc123def456"));
    });

    test("preferred branch name collides: retries with random suffix", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // branch --list my-feature → non-empty (collision!)
      processRunner.enqueue(result: _ok(stdout: "  my-feature\n"));
      // worktree add with suffixed name → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
        preferredBranchAndWorktreeName: (branchName: "my-feature", worktreeName: "my-feature"),
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, startsWith("my-feature-"));
      expect(success.branchName.length, equals("my-feature-".length + 6));
      expect(success.path, startsWith("$_projectId/.worktrees/my-feature-"));
    });

    test("preferred branch name git fails: falls through to numbered naming", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // branch --list my-feature → empty (available)
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → failure
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      // branch --list session-001 → empty (free)
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
        preferredBranchAndWorktreeName: (branchName: "my-feature", worktreeName: "my-feature"),
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, equals("session-001"));
    });

    test("no preferred branch name: uses numbered naming", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // branch --list session-001 → empty
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
        preferredBranchAndWorktreeName: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, equals("session-001"));
    });

    test("preferred branch name with parent session: ignored, reuses parent worktree", () async {
      // Insert a mapping for the parent session.
      await projectsDao.insertProjectsIfMissing(projectIds: [_projectId]); // satisfy v5 FK constraint
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
        preferredBranchAndWorktreeName: (branchName: "my-feature", worktreeName: "my-feature"),
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/session-001"));
      expect(success.branchName, equals("session-001"));
      // No git commands should have been called — worktree already exists.
      expect(processRunner.invocations, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Origin comparison scenarios
    // -----------------------------------------------------------------------

    test("origin ahead: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 1 (origin NOT ancestor of local)
      processRunner.enqueue(result: _fail(exitCode: 1));
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
      expect(success.baseBranch, equals("origin/main"));
      expect(success.baseCommit, equals("origin222"));

      // Verify worktree add used "origin/main" as start point
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("origin/main"));
    });

    test("local ahead: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 0 (origin IS ancestor of local)
      processRunner.enqueue(result: _ok());
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
      expect(success.baseBranch, equals("main"));
      expect(success.baseCommit, equals("local111"));

      // Verify worktree add used "main" as start point
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("main"));
    });

    test("same commit: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
      // rev-parse origin/main → same commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
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
      expect(success.baseCommit, equals("samecommit"));

      // Verify worktree add used "main" as start point
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("main"));
    });

    test("diverged: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "diverged-local\n"));
      // rev-parse origin/main → origin commit
      processRunner.enqueue(result: _ok(stdout: "diverged-origin\n"));
      // merge-base --is-ancestor diverged-origin diverged-local → exit 1 (not ancestor)
      processRunner.enqueue(result: _fail(exitCode: 1));
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
      expect(success.baseCommit, equals("diverged-origin"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("origin/main"));
    });

    test("no origin ref: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → fail (no remote tracking branch)
      processRunner.enqueue(result: _fail(exitCode: 128));
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
      expect(success.baseCommit, equals("local111"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("main"));
    });

    test("merge-base fails: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor → exit 128 (fatal error, e.g. shallow clone)
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal"));
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
      expect(success.baseCommit, equals("origin222"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("origin/main"));
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
        branchRepository: BranchRepository(gitCliApi: GitCliApi(processRunner: processRunner)),
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: processRunner,
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

    test("non-existent path: returns WorktreeSafe (already cleaned up), no git commands called", () async {
      const nonExistentPath = "/tmp/this_path_does_not_exist_sesori_test_12345";

      final result = await service.checkWorktreeSafety(
        worktreePath: nonExistentPath,
        expectedBranch: "session-001",
      );

      expect(result, isA<WorktreeSafe>());
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
        branchRepository: BranchRepository(gitCliApi: GitCliApi(processRunner: processRunner)),
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: processRunner,
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

  group("WorktreeService.prepareWorktreeForBranch", () {
    late _FakeProcessRunner processRunner;
    late AppDatabase db;
    late WorktreeService service;

    setUp(() {
      db = createTestDatabase();
      processRunner = _FakeProcessRunner();
      service = WorktreeService(
        branchRepository: BranchRepository(gitCliApi: GitCliApi(processRunner: processRunner)),
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => true,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("none mode returns project directory fallback", () async {
      final result = await service.prepareWorktreeForBranch(
        mode: WorktreeMode.none,
        selectedBranch: null,
        projectPath: _projectId,
        sessionId: "ses-1",
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.originalPath, equals(_projectId));
      expect(fallback.reason, equals("worktree mode is none"));
      expect(processRunner.invocations, isEmpty);
    });

    test("stayOnBranch reuses existing project checkout", () async {
      processRunner.enqueue(result: _ok());
      processRunner.enqueue(result: _ok(stdout: "branch-sha\n"));
      processRunner.enqueue(result: _ok(stdout: "\n"));
      processRunner.enqueue(
        result: _ok(stdout: "worktree $_projectId\nHEAD branch-sha\nbranch refs/heads/feature/test\n\n"),
      );

      final result = await service.prepareWorktreeForBranch(
        mode: WorktreeMode.stayOnBranch,
        selectedBranch: "feature/test",
        projectPath: _projectId,
        sessionId: "ses-2",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals(_projectId));
      expect(success.branchName, equals("feature/test"));
      expect(success.baseBranch, equals("feature/test"));
      expect(success.baseCommit, equals("branch-sha"));
    });

    test("stayOnBranch creates tracking worktree for remote-only branch", () async {
      processRunner.enqueue(result: _ok());
      processRunner.enqueue(result: _fail(exitCode: 128));
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      processRunner.enqueue(result: _ok(stdout: "remote-sha\n"));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForBranch(
        mode: WorktreeMode.stayOnBranch,
        selectedBranch: "feature/test",
        projectPath: _projectId,
        sessionId: "ses-3",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/feature__test"));
      expect(success.baseBranch, equals("origin/feature/test"));
      expect(success.baseCommit, equals("remote-sha"));
      expect(
        processRunner.invocations.last.arguments,
        equals([
          "worktree",
          "add",
          "-b",
          "feature/test",
          "--",
          "$_projectId/.worktrees/feature__test",
          "origin/feature/test",
        ]),
      );
    });

    test("stayOnBranch recreates a missing prunable worktree", () async {
      processRunner.enqueue(result: _ok());
      processRunner.enqueue(result: _ok(stdout: "branch-sha\n"));
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      processRunner.enqueue(result: _fail(exitCode: 128));
      processRunner.enqueue(
        result: _ok(
          stdout: "worktree $_projectId/.worktrees/feature__test\nHEAD branch-sha\nbranch refs/heads/feature/test\n\n",
        ),
      );
      processRunner.enqueue(result: _ok());
      processRunner.enqueue(result: _ok(stdout: "  feature/test\n"));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForBranch(
        mode: WorktreeMode.stayOnBranch,
        selectedBranch: "feature/test",
        projectPath: _projectId,
        sessionId: "ses-prunable",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/feature__test"));
      expect(
        processRunner.invocations.map((invocation) => invocation.arguments),
        contains(
          predicate<List<String>>(
            (arguments) => arguments.length == 2 && arguments[0] == "worktree" && arguments[1] == "prune",
          ),
        ),
      );
    });

    test("newBranch creates dedicated worktree from selected branch", () async {
      processRunner.enqueue(result: _ok());
      processRunner.enqueue(result: _ok(stdout: "branch-sha\n"));
      processRunner.enqueue(result: _ok(stdout: "\n"));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForBranch(
        mode: WorktreeMode.newBranch,
        selectedBranch: "develop",
        projectPath: _projectId,
        sessionId: "ses-4",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, equals("$_projectId/.worktrees/session-001"));
      expect(success.branchName, equals("session-001"));
      expect(success.baseBranch, equals("develop"));
      expect(success.baseCommit, equals("branch-sha"));
      expect(
        processRunner.invocations.last.arguments,
        equals([
          "worktree",
          "add",
          "-b",
          "session-001",
          "--",
          "$_projectId/.worktrees/session-001",
          "develop",
        ]),
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

class _FakeProcessRunner implements ProcessRunner {
  final List<_Invocation> invocations = <_Invocation>[];
  final List<ProcessResult> _queue = <ProcessResult>[];

  void enqueue({required ProcessResult result}) {
    _queue.add(result);
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

    if (_queue.isEmpty) {
      throw StateError("No ProcessResult queued for: $executable $arguments");
    }

    return _queue.removeAt(0);
  }
}
