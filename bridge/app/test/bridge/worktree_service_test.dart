import "dart:io";

import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../helpers/fakes/fake_bridge_plugin.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/test_database.dart";

const _projectId = "/repo/project";
// `<project folder>-<first 8 hex of sha256(project path)>` under the test root.
const _projectWorktrees = "/worktrees/project-9a1fd19f";

void main() {
  group("WorktreeService.prepareWorktreeForSession", () {
    late _FakeProcessRunner processRunner;
    late bool gitDirectoryExists;
    late AppDatabase db;
    late ProjectsDao projectsDao;
    late WorktreeService service;

    setUp(() async {
      db = createTestDatabase();
      projectsDao = db.projectsDao;
      await projectsDao.insertProjectsIfMissing(projectIds: [_projectId]);
      processRunner = _FakeProcessRunner();
      gitDirectoryExists = true;
      final fakePlugin = _FakeBridgePluginApi();
      service = WorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          worktreesDirectory: "/worktrees",
          projectsDao: projectsDao,
          gitApi: GitCliApi(
            streamingProcessRunner: const StreamingProcessRunner(),
            processRunner: processRunner,
            gitPathExists: ({required String gitPath}) => gitDirectoryExists,
          ),
          plugin: fakePlugin,
        ),
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
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // git fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, matches(RegExp(r"^/worktrees/project-9a1fd19f/[a-z]+-[a-z]+$")));
      expect(success.baseBranch, equals("main"));
      expect(success.baseCommit, equals("abc123def456"));

      // The worktree starts on a detached HEAD at "main"; no branch is created.
      expect(processRunner.invocations.last.arguments, ["worktree", "add", "--detach", "--", success.path, "main"]);
    });

    test("moved project: git runs in the recorded live directory", () async {
      // The folder moved from _projectId to /moved/project and was re-opened
      // there; every git operation must run where the folder actually is.
      await projectsDao.recordOpenedProject(
        projectId: _projectId,
        path: "/moved/project",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      // git rev-parse HEAD → success
      processRunner.enqueue(result: _ok());
      // git symbolic-ref refs/remotes/origin/HEAD → "refs/remotes/origin/main"
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // git fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.path, matches(RegExp(r"^/worktrees/project-c4014039/[a-z]+-[a-z]+$")));
      for (final invocation in processRunner.invocations) {
        expect(invocation.workingDirectory, equals("/moved/project"));
      }
    });

    // -----------------------------------------------------------------------
    // Non-git fallback
    // -----------------------------------------------------------------------

    test("non-git fallback: returns WorktreeFallback when not a git repo", () async {
      gitDirectoryExists = false;

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
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
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.reason, equals("repository has no commits"));
      expect(processRunner.invocations, hasLength(1));
    });

    // -----------------------------------------------------------------------
    // Path collision retry
    // -----------------------------------------------------------------------

    test("occupied worktree path skips to the next name before Git runs", () async {
      final filesystemApi = _OccupyingFilesystemApi(occupiedCount: 1);
      service = WorktreeService(
        worktreeRepository: _worktreeRepository(
          projectsDao: projectsDao,
          processRunner: processRunner,
          filesystemApi: filesystemApi,
        ),
      );
      _enqueueResolvedMain(processRunner: processRunner);
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(projectId: _projectId);

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(filesystemApi.checkedPaths, hasLength(2));
      expect(filesystemApi.checkedPaths.toSet(), hasLength(2));
      expect(filesystemApi.checkedPaths, everyElement(matches(RegExp(r"^/worktrees/project-9a1fd19f/[a-z]+-[a-z]+$"))));
      expect(success.path, filesystemApi.checkedPaths.last);
      final worktreeCreates = processRunner.invocations
          .where((invocation) => invocation.arguments.take(2).join(" ") == "worktree add")
          .toList(growable: false);
      expect(worktreeCreates, hasLength(1));
      expect(worktreeCreates.single.arguments, contains(success.path));
    });

    // -----------------------------------------------------------------------
    // Git failure fallback (all normal and suffixed attempts fail)
    // -----------------------------------------------------------------------

    test("git failure fallback: returns WorktreeFallback after final suffixed attempt", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Every generated path is free, but worktree creation fails.
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      // Final secure-suffix attempt also fails.
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeFallback>());
      final fallback = result as WorktreeFallback;
      expect(fallback.originalPath, equals(_projectId));
      expect(fallback.reason, equals("failed to create worktree after 4 attempts"));
      expect(
        processRunner.invocations.where(
          (invocation) =>
              invocation.arguments.length >= 2 &&
              invocation.arguments[0] == "worktree" &&
              invocation.arguments[1] == "add",
        ),
        hasLength(4),
      );
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
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/develop → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse develop → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "deadbeef1234\n"));
      // git rev-parse origin/develop → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
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
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());

      // Worktree add should have used "main" (from resolved default branch)
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs, contains("main"));
      expect(worktreeAddArgs, isNot(contains("old-branch")));
    });

    // -----------------------------------------------------------------------
    // Secure suffix fallback
    // -----------------------------------------------------------------------

    test("pair exhaustion appends a secure suffix to the last sampled pair", () async {
      // All three normal pairs and the first suffix are occupied.
      final filesystemApi = _OccupyingFilesystemApi(occupiedCount: 4);
      service = WorktreeService(
        worktreeRepository: _worktreeRepository(
          projectsDao: projectsDao,
          processRunner: processRunner,
          filesystemApi: filesystemApi,
        ),
      );
      _enqueueResolvedMain(processRunner: processRunner);
      // The second suffixed candidate is available and succeeds.
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(projectId: _projectId);

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      final checkedPaths = filesystemApi.checkedPaths;
      expect(checkedPaths, hasLength(5));
      final normalCandidates = checkedPaths.take(3).toList(growable: false);
      final suffixCandidates = checkedPaths.skip(3).toList(growable: false);
      expect(normalCandidates.toSet(), hasLength(3));
      expect(normalCandidates, everyElement(matches(RegExp(r"^/worktrees/project-9a1fd19f/[a-z]+-[a-z]+$"))));
      expect(suffixCandidates.toSet(), hasLength(2));
      expect(
        suffixCandidates,
        everyElement(matches(RegExp(r"^/worktrees/project-9a1fd19f/[a-z]+-[a-z]+-[0-9a-f]{6}$"))),
      );
      expect(success.path, suffixCandidates.last);
      expect(success.path.substring(0, success.path.length - 7), normalCandidates.last);
    });

    // -----------------------------------------------------------------------
    // Origin comparison scenarios
    // -----------------------------------------------------------------------

    test("freshly fetched origin ahead: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → refreshes the stale remote-tracking ref
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → newly fetched origin commit
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 1 (origin NOT ancestor of local)
      processRunner.enqueue(result: _fail(exitCode: 1));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseBranch, equals("refs/remotes/origin/main"));
      expect(success.baseCommit, equals("origin222"));

      expect(
        processRunner.invocations[3].arguments,
        equals([
          "fetch",
          "--no-write-fetch-head",
          "--no-tags",
          "--no-recurse-submodules",
          "origin",
          "+refs/heads/main:refs/remotes/origin/main",
        ]),
      );

      // Verify worktree add used "origin/main" as start point
      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("refs/remotes/origin/main"));
    });

    test("local ahead: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 0 (origin IS ancestor of local)
      processRunner.enqueue(result: _ok());
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
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
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
      // rev-parse origin/main → same commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
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
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "diverged-local\n"));
      // rev-parse origin/main → origin commit
      processRunner.enqueue(result: _ok(stdout: "diverged-origin\n"));
      // merge-base --is-ancestor diverged-origin diverged-local → exit 1 (not ancestor)
      processRunner.enqueue(result: _fail(exitCode: 1));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseCommit, equals("diverged-origin"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("refs/remotes/origin/main"));
    });

    test("no origin ref: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → fail (no remote tracking branch)
      processRunner.enqueue(result: _fail(exitCode: 128));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseCommit, equals("local111"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("main"));
    });

    test("local-only repository creates a worktree without fetching", () async {
      await projectsDao.setBaseBranch(projectId: _projectId, baseBranch: "main");
      processRunner.enqueue(result: _ok()); // rev-parse HEAD
      processRunner.enqueue(result: _ok(stdout: "  main\n")); // branch --list main
      processRunner.enqueue(result: _ok()); // remote: none configured
      processRunner.enqueue(result: _ok(stdout: "local111\n")); // rev-parse main
      processRunner.enqueue(result: _fail(exitCode: 128)); // no origin/main ref
      processRunner.enqueue(result: _ok()); // worktree add

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseBranch, "main");
      expect(success.baseCommit, "local111");
      expect(processRunner.invocations[2].arguments, ["remote"]);
      expect(processRunner.invocations.any((invocation) => invocation.arguments.first == "fetch"), isFalse);
      expect(processRunner.invocations.last.arguments.take(2), ["worktree", "add"]);
      expect(processRunner.invocations.last.arguments.last, "main");
    });

    test("unexpected fetch error aborts worktree creation", () async {
      processRunner.enqueue(result: _ok()); // rev-parse HEAD
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n")); // symbolic-ref
      processRunner.enqueue(result: _ok(stdout: "origin\n")); // remote
      processRunner.enqueueError(error: StateError("broken process runner")); // fetch
      // These would let creation succeed if the unexpected error were swallowed.
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      processRunner.enqueue(result: _fail(exitCode: 128));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeFallback>());
      expect((result as WorktreeFallback).reason, equals("failed to resolve base branch/commit"));
      expect(processRunner.invocations, hasLength(4));
    });

    test("merge-base fails: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // git remote → origin is configured
      processRunner.enqueue(result: _ok(stdout: "origin\n"));
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor → exit 128 (fatal error, e.g. shallow clone)
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal"));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseCommit, equals("origin222"));

      final worktreeAddArgs = processRunner.invocations.last.arguments;
      expect(worktreeAddArgs.last, equals("refs/remotes/origin/main"));
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
        worktreeRepository: singlePluginWorktreeRepository(
          worktreesDirectory: "/worktrees",
          projectsDao: db.projectsDao,
          gitApi: GitCliApi(
            streamingProcessRunner: const StreamingProcessRunner(),
            processRunner: processRunner,
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: _FakeBridgePluginApi(),
        ),
      );
      tempDir = await Directory.systemTemp.createTemp("worktree_safety_test_");
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("clean worktree: returns WorktreeSafe", () async {
      // git status --porcelain → empty (clean)
      processRunner.enqueue(result: _ok(stdout: ""));
      // git rev-list → empty (every commit is on a branch)
      processRunner.enqueue(result: _ok(stdout: ""));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        baseCommit: "base123",
      );

      expect(result, isA<WorktreeSafe>());
      expect(processRunner.invocations, hasLength(2));
      expect(processRunner.invocations.last.arguments, contains("base123"));
    });

    test("dirty worktree: returns WorktreeUnsafe with UnstagedChanges", () async {
      // git status --porcelain → non-empty (dirty)
      processRunner.enqueue(result: _ok(stdout: "M file.txt\n"));
      processRunner.enqueue(result: _ok(stdout: ""));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        baseCommit: "base123",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.first, isA<UnstagedChanges>());
    });

    test("commits on no branch: returns WorktreeUnsafe with CommitsOnNoBranch", () async {
      processRunner.enqueue(result: _ok(stdout: ""));
      // git rev-list → a HEAD commit no branch, tag or remote reaches
      processRunner.enqueue(result: _ok(stdout: "def456\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        baseCommit: "base123",
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.single, isA<CommitsOnNoBranch>());
    });

    test("dirty worktree with commits on no branch reports both issues", () async {
      processRunner.enqueue(result: _ok(stdout: "M file.txt\nA new.dart\n"));
      processRunner.enqueue(result: _ok(stdout: "def456\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
        baseCommit: null,
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(2));
      expect(unsafe.issues.first, isA<UnstagedChanges>());
      expect(unsafe.issues.last, isA<CommitsOnNoBranch>());
    });

    test("non-existent path: returns WorktreeSafe (already cleaned up), no git commands called", () async {
      const nonExistentPath = "/tmp/this_path_does_not_exist_sesori_test_12345";

      final result = await service.checkWorktreeSafety(
        worktreePath: nonExistentPath,
        baseCommit: "base123",
      );

      expect(result, isA<WorktreeSafe>());
      // No git commands should have been called
      expect(processRunner.invocations, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // pruneWorktrees / removeWorktree
  // -------------------------------------------------------------------------

  group("WorktreeService lifecycle methods", () {
    late _FakeProcessRunner processRunner;
    late AppDatabase db;
    late _FakeBridgePluginApi plugin;
    late WorktreeService service;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: [_projectId]);
      processRunner = _FakeProcessRunner();
      plugin = _FakeBridgePluginApi();
      service = WorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          worktreesDirectory: "/worktrees",
          projectsDao: db.projectsDao,
          gitApi: GitCliApi(
            streamingProcessRunner: const StreamingProcessRunner(),
            processRunner: processRunner,
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: plugin,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    // removeWorktree (force: false)

    test("removeWorktree(force: false): calls prune then remove without --force", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectWorktrees/session-001",
        force: false,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final pruneInv = processRunner.invocations[0];
      expect(pruneInv.arguments, equals(["worktree", "prune"]));

      final removeInv = processRunner.invocations[1];
      expect(removeInv.arguments, equals(["worktree", "remove", "--", "$_projectWorktrees/session-001"]));
      expect(removeInv.arguments, isNot(contains("--force")));
      expect(removeInv.workingDirectory, equals(_projectId));
    });

    // removeWorktree (force: true)

    test("removeWorktree for a moved project: git and workspace cleanup target the live directory", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: _projectId,
        path: "/moved/project",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectWorktrees/session-001",
        force: false,
      );

      expect(result, isTrue);
      for (final invocation in processRunner.invocations) {
        expect(invocation.workingDirectory, equals("/moved/project"));
      }
      // The backend resolves the workspace by directory, so best-effort
      // cleanup must point at the live project root too.
      expect(plugin.lastDeleteWorkspaceProjectId, equals("/moved/project"));
      expect(plugin.lastDeleteWorkspaceWorktreePath, equals("$_projectWorktrees/session-001"));
    });

    test("removeWorktree(force: true): calls prune then remove with --force", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove --force <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectWorktrees/session-001",
        force: true,
      );

      expect(result, isTrue);
      expect(processRunner.invocations, hasLength(2));

      final removeInv = processRunner.invocations[1];
      expect(
        removeInv.arguments,
        equals(["worktree", "remove", "--force", "--", "$_projectWorktrees/session-001"]),
      );
    });

    test("removeWorktree still removes a worktree inside the project's legacy .worktrees folder", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        force: false,
      );

      expect(result, isTrue);
      expect(
        processRunner.invocations[1].arguments,
        equals(["worktree", "remove", "--", "$_projectId/.worktrees/session-001"]),
      );
    });

    test("removeWorktree refuses a path the bridge does not own without running git", () async {
      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "/elsewhere/session-001",
        force: true,
      );

      expect(result, isFalse);
      expect(processRunner.invocations, isEmpty);
    });

    // removeWorktree failure → returns false

    test("removeWorktree: returns false on non-zero exit code, does not throw", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove → failure
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal: not a worktree"));

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectWorktrees/session-001",
        force: false,
      );

      expect(result, isFalse);
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

WorktreeRepository _worktreeRepository({
  required ProjectsDao projectsDao,
  required _FakeProcessRunner processRunner,
  required FilesystemApi filesystemApi,
}) {
  return WorktreeRepository(
    worktreesDirectory: "/worktrees",
    projectsDao: projectsDao,
    filesystemApi: filesystemApi,
    gitApi: GitCliApi(
      streamingProcessRunner: const StreamingProcessRunner(),
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => true,
    ),
    runtime: createTestPluginRuntime(plugins: [_FakeBridgePluginApi()]),
  );
}

/// Queues the git results that resolve `main` as the base with no origin ref.
void _enqueueResolvedMain({required _FakeProcessRunner processRunner}) {
  processRunner
    ..enqueue(result: _ok()) // rev-parse HEAD
    ..enqueue(result: _ok(stdout: "refs/remotes/origin/main\n")) // symbolic-ref
    ..enqueue(result: _ok(stdout: "origin\n")) // remote
    ..enqueue(result: _fail(exitCode: 1)) // fetch origin/main
    ..enqueue(result: _ok(stdout: "abc123def456\n")) // rev-parse main
    ..enqueue(result: _fail(exitCode: 128)); // rev-parse origin/main
}

/// Reports the first [_occupiedCount] checked paths as taken, as if folders
/// already sat there.
class _OccupyingFilesystemApi({required final int _occupiedCount}) extends FilesystemApi {
  final List<String> checkedPaths = <String>[];

  @override
  FileSystemEntityType entityType(String path) {
    checkedPaths.add(path);
    return checkedPaths.length <= _occupiedCount ? FileSystemEntityType.directory : FileSystemEntityType.notFound;
  }
}

class const _Invocation({
  required final String command,
  required final List<String> arguments,
  required final String? workingDirectory,
});

class _FakeProcessRunner() implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final List<_Invocation> invocations = <_Invocation>[];
  final List<Object> _queue = <Object>[];

  void enqueue({required ProcessResult result}) {
    _queue.add(result);
  }

  void enqueueError({required Object error}) {
    _queue.add(error);
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
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

    final next = _queue.removeAt(0);
    if (next is ProcessResult) {
      return next;
    }
    throw next;
  }
}

class _FakeBridgePluginApi() extends FakeBridgePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) => throw UnimplementedError();
}
