import "dart:io";

import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../helpers/fakes/fake_bridge_plugin.dart";
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

    setUp(() async {
      db = createTestDatabase();
      projectsDao = db.projectsDao;
      sessionDao = db.sessionDao;
      await projectsDao.insertProjectsIfMissing(projectIds: [_projectId]);
      processRunner = _FakeProcessRunner();
      gitDirectoryExists = true;
      final fakePlugin = _FakeBridgePluginApi();
      service = WorktreeService(
        worktreeRepository: singlePluginWorktreeRepository(
          projectsDao: projectsDao,
          sessionDao: sessionDao,
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
      // git fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch does not exist.
      processRunner.enqueue(result: _ok(stdout: ""));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      _expectColorAnimalSlug(success.branchName);
      expect(success.path, equals("$_projectId/.worktrees/${success.branchName}"));
      expect(success.baseBranch, equals("main"));
      expect(success.baseCommit, equals("abc123def456"));

      // Verify the worktree add command used "main" as base branch
      final worktreeAddCall = processRunner.invocations.last;
      expect(worktreeAddCall.arguments, contains("main"));
      expect(worktreeAddCall.arguments, contains(success.branchName));
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
      // git fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch does not exist.
      processRunner.enqueue(result: _ok(stdout: ""));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      _expectColorAnimalSlug(success.branchName);
      expect(success.path, equals("/moved/project/.worktrees/${success.branchName}"));
      for (final invocation in processRunner.invocations) {
        expect(invocation.workingDirectory, equals("/moved/project"));
      }
    });

    test("parent session: reuses parent worktree when mapping exists", () async {
      // Insert a mapping for the parent session.
      await projectsDao.insertProjectsIfMissing(projectIds: [_projectId]); // satisfy v5 FK constraint
      await sessionDao.insertSession(
        pluginId: "opencode",
        preservePullRequestScope: false,
        sessionId: "parent-001",
        backendSessionId: "parent-001",
        projectId: _projectId,
        isDedicated: true,
        createdAt: 123,
        worktreePath: "$_projectId/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "sha-parent",

        lastAgent: null,
        lastAgentModel: null,
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
      // git fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch does not exist.
      processRunner.enqueue(result: _ok(stdout: ""));
      // git worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: "nonexistent-parent",
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      _expectColorAnimalSlug(success.branchName);
      expect(success.path, equals("$_projectId/.worktrees/${success.branchName}"));
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
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // First generated branch collides; the second is free.
      processRunner.enqueue(result: _ok(stdout: "existing\n"));
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      _expectColorAnimalSlug(success.branchName);
      expect(success.path, equals("$_projectId/.worktrees/${success.branchName}"));
      final checkedBranches = processRunner.invocations
          .where(
            (invocation) =>
                invocation.arguments.length >= 2 &&
                invocation.arguments[0] == "branch" &&
                invocation.arguments[1] == "--list",
          )
          .map((invocation) => invocation.arguments.last)
          .toList(growable: false);
      expect(checkedBranches, hasLength(2));
      expect(checkedBranches.toSet(), hasLength(2));
      checkedBranches.forEach(_expectColorAnimalSlug);
      expect(success.branchName, checkedBranches.last);
    });

    test("occupied worktree path skips the name before Git creates its branch", () async {
      final projectDirectory = await Directory.systemTemp.createTemp("worktree_name_collision_");
      addTearDown(() => projectDirectory.delete(recursive: true));
      await projectsDao.recordOpenedProject(
        projectId: _projectId,
        path: projectDirectory.path,
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      processRunner
        ..generatedPathsToOccupy = 1
        ..enqueue(result: _ok())
        ..enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"))
        ..enqueue(result: _fail(exitCode: 1))
        ..enqueue(result: _ok(stdout: "abc123def456\n"))
        ..enqueue(result: _fail(exitCode: 128))
        ..enqueue(result: _ok(stdout: ""))
        ..enqueue(result: _ok(stdout: ""))
        ..enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final branchChecks = processRunner.invocations
          .where((invocation) => invocation.arguments.take(2).join(" ") == "branch --list")
          .toList(growable: false);
      final worktreeCreates = processRunner.invocations
          .where((invocation) => invocation.arguments.take(2).join(" ") == "worktree add")
          .toList(growable: false);
      expect(branchChecks, hasLength(2));
      expect(worktreeCreates, hasLength(1));
      expect(worktreeCreates.single.arguments, contains((result as WorktreeSuccess).branchName));
    });

    // -----------------------------------------------------------------------
    // Git failure fallback (all normal and suffixed attempts fail)
    // -----------------------------------------------------------------------

    test("git failure fallback: returns WorktreeFallback after final suffixed attempt", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Each generated branch is free, but worktree creation fails.
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));
      // Final secure-suffix attempt also fails.
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "error"));

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
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
      // fetch origin/develop → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse develop → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "deadbeef1234\n"));
      // git rev-parse origin/develop → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch is available.
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
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch is available.
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
    // Secure suffix fallback
    // -----------------------------------------------------------------------

    test("pair exhaustion appends a secure suffix to the last sampled pair", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // git rev-parse main → base commit SHA
      processRunner.enqueue(result: _ok(stdout: "abc123def456\n"));
      // git rev-parse origin/main → no remote tracking branch
      processRunner.enqueue(result: _fail(exitCode: 128));
      // All three normal pairs and the first suffix collide.
      processRunner.enqueue(result: _ok(stdout: "existing\n"));
      processRunner.enqueue(result: _ok(stdout: "existing\n"));
      processRunner.enqueue(result: _ok(stdout: "existing\n"));
      processRunner.enqueue(result: _ok(stdout: "existing\n"));
      // The second suffixed candidate is available and succeeds.
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.branchName, matches(RegExp(r"^[a-z]+-[a-z]+-[0-9a-f]{6}$")));
      final checkedBranches = processRunner.invocations
          .where(
            (invocation) =>
                invocation.arguments.length >= 2 &&
                invocation.arguments[0] == "branch" &&
                invocation.arguments[1] == "--list",
          )
          .map((invocation) => invocation.arguments.last)
          .toList(growable: false);
      expect(checkedBranches, hasLength(5));
      final normalCandidates = checkedBranches.take(3).toList(growable: false);
      final suffixCandidates = checkedBranches.skip(3).toList(growable: false);
      expect(normalCandidates.toSet(), hasLength(3));
      normalCandidates.forEach(_expectColorAnimalSlug);
      expect(suffixCandidates.toSet(), hasLength(2));
      expect(suffixCandidates, everyElement(matches(RegExp(r"^[a-z]+-[a-z]+-[0-9a-f]{6}$"))));
      expect(success.branchName, suffixCandidates.last);
      expect(success.branchName.substring(0, success.branchName.length - 7), normalCandidates.last);
      expect(success.path, equals("$_projectId/.worktrees/${success.branchName}"));
    });

    // -----------------------------------------------------------------------
    // Origin comparison scenarios
    // -----------------------------------------------------------------------

    test("freshly fetched origin ahead: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // fetch origin/main → refreshes the stale remote-tracking ref
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → newly fetched origin commit
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 1 (origin NOT ancestor of local)
      processRunner.enqueue(result: _fail(exitCode: 1));
      // Generated workspace branch is available.
      processRunner.enqueue(result: _ok(stdout: ""));
      // worktree add → success
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeSuccess>());
      final success = result as WorktreeSuccess;
      expect(success.baseBranch, equals("refs/remotes/origin/main"));
      expect(success.baseCommit, equals("origin222"));

      expect(
        processRunner.invocations[2].arguments,
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
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor origin222 local111 → exit 0 (origin IS ancestor of local)
      processRunner.enqueue(result: _ok());
      // Generated workspace branch is available.
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
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
      // rev-parse origin/main → same commit
      processRunner.enqueue(result: _ok(stdout: "samecommit\n"));
      // Generated workspace branch is available.
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
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "diverged-local\n"));
      // rev-parse origin/main → origin commit
      processRunner.enqueue(result: _ok(stdout: "diverged-origin\n"));
      // merge-base --is-ancestor diverged-origin diverged-local → exit 1 (not ancestor)
      processRunner.enqueue(result: _fail(exitCode: 1));
      // Generated workspace branch is available.
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
      expect(worktreeAddArgs.last, equals("refs/remotes/origin/main"));
    });

    test("no origin ref: worktree starts from local branch", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // fetch origin/main → unavailable; continue with existing refs
      processRunner.enqueue(result: _fail(exitCode: 1));
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → fail (no remote tracking branch)
      processRunner.enqueue(result: _fail(exitCode: 128));
      // Generated workspace branch is available.
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

    test("unexpected fetch error aborts worktree creation", () async {
      processRunner.enqueue(result: _ok()); // rev-parse HEAD
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n")); // symbolic-ref
      processRunner.enqueueError(error: StateError("broken process runner")); // fetch
      // These would let creation succeed if the unexpected error were swallowed.
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      processRunner.enqueue(result: _fail(exitCode: 128));
      processRunner.enqueue(result: _ok(stdout: ""));
      processRunner.enqueue(result: _ok());

      final result = await service.prepareWorktreeForSession(
        projectId: _projectId,
        parentSessionId: null,
      );

      expect(result, isA<WorktreeFallback>());
      expect((result as WorktreeFallback).reason, equals("failed to resolve base branch/commit"));
      expect(processRunner.invocations, hasLength(3));
    });

    test("merge-base fails: worktree starts from origin ref", () async {
      // rev-parse HEAD → ok
      processRunner.enqueue(result: _ok());
      // symbolic-ref → main
      processRunner.enqueue(result: _ok(stdout: "refs/remotes/origin/main\n"));
      // fetch origin/main → success
      processRunner.enqueue(result: _ok());
      // rev-parse main → local commit
      processRunner.enqueue(result: _ok(stdout: "local111\n"));
      // rev-parse origin/main → origin commit (different)
      processRunner.enqueue(result: _ok(stdout: "origin222\n"));
      // merge-base --is-ancestor → exit 128 (fatal error, e.g. shallow clone)
      processRunner.enqueue(result: _fail(exitCode: 128, stderr: "fatal"));
      // Generated workspace branch is available.
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
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
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

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
      );

      expect(result, isA<WorktreeSafe>());
      expect(processRunner.invocations, hasLength(1));
    });

    test("dirty worktree: returns WorktreeUnsafe with UnstagedChanges", () async {
      // git status --porcelain → non-empty (dirty)
      processRunner.enqueue(result: _ok(stdout: "M file.txt\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.first, isA<UnstagedChanges>());
    });

    test("different branch remains safe", () async {
      // git status --porcelain → empty (clean)
      processRunner.enqueue(result: _ok(stdout: ""));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
      );

      expect(result, isA<WorktreeSafe>());
    });

    test("dirty worktree on a different branch returns UnstagedChanges", () async {
      // git status --porcelain → non-empty (dirty)
      processRunner.enqueue(result: _ok(stdout: "M file.txt\nA new.dart\n"));

      final result = await service.checkWorktreeSafety(
        worktreePath: tempDir.path,
      );

      expect(result, isA<WorktreeUnsafe>());
      final unsafe = result as WorktreeUnsafe;
      expect(unsafe.issues, hasLength(1));
      expect(unsafe.issues.whereType<UnstagedChanges>(), hasLength(1));
    });

    test("non-existent path: returns WorktreeSafe (already cleaned up), no git commands called", () async {
      const nonExistentPath = "/tmp/this_path_does_not_exist_sesori_test_12345";

      final result = await service.checkWorktreeSafety(
        worktreePath: nonExistentPath,
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
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
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
        worktreePath: "/moved/project/.worktrees/session-001",
        force: false,
      );

      expect(result, isTrue);
      for (final invocation in processRunner.invocations) {
        expect(invocation.workingDirectory, equals("/moved/project"));
      }
      // The backend resolves the workspace by directory, so best-effort
      // cleanup must point at the live project root too.
      expect(plugin.lastDeleteWorkspaceProjectId, equals("/moved/project"));
      expect(plugin.lastDeleteWorkspaceWorktreePath, equals("/moved/project/.worktrees/session-001"));
    });

    test("removeWorktree(force: true): calls prune then remove with --force", () async {
      // git worktree prune
      processRunner.enqueue(result: _ok());
      // git worktree remove --force <path>
      processRunner.enqueue(result: _ok());

      final result = await service.removeWorktree(
        pluginId: plugin.id,
        projectId: _projectId,
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
        pluginId: plugin.id,
        projectId: _projectId,
        worktreePath: "$_projectId/.worktrees/session-001",
        force: false,
      );

      expect(result, isFalse);
    });
  });

  group("WorktreeService.renameGeneratedBranch", () {
    late _GeneratedRenameWorktreeRepository repository;
    late WorktreeService service;

    setUp(() {
      repository = _GeneratedRenameWorktreeRepository();
      service = WorktreeService(worktreeRepository: repository);
    });

    test("renames the still-current unpublished initial branch", () async {
      final result = await service.renameGeneratedBranch(
        worktreePath: "/repo/.worktrees/blue-otter",
        initialBranchName: "blue-otter",
        generatedBranchName: "fix-login-flow",
      );

      expect(result, isA<GeneratedBranchRenamed>());
      expect((result as GeneratedBranchRenamed).branchName, "fix-login-flow");
      expect(repository.renameCalls, [
        (oldBranchName: "blue-otter", newBranchName: "fix-login-flow"),
      ]);
      expect(repository.lastWorktreePath, "/repo/.worktrees/blue-otter");
    });

    test("skips invalid, switched, and published branches", () async {
      repository.validBranchName = false;
      expect(
        await service.renameGeneratedBranch(
          worktreePath: "/worktree",
          initialBranchName: "blue-otter",
          generatedBranchName: "invalid branch",
        ),
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.invalidGeneratedName,
        ),
      );

      repository
        ..validBranchName = true
        ..currentBranchName = "user-branch";
      expect(
        await service.renameGeneratedBranch(
          worktreePath: "/worktree",
          initialBranchName: "blue-otter",
          generatedBranchName: "fix-login-flow",
        ),
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.initialBranchChanged,
        ),
      );

      repository
        ..currentBranchName = "blue-otter"
        ..upstream = true;
      expect(
        await service.renameGeneratedBranch(
          worktreePath: "/worktree",
          initialBranchName: "blue-otter",
          generatedBranchName: "fix-login-flow",
        ),
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.initialBranchPublished,
        ),
      );

      repository
        ..upstream = false
        ..remoteBranches.add("blue-otter");
      expect(
        await service.renameGeneratedBranch(
          worktreePath: "/worktree",
          initialBranchName: "blue-otter",
          generatedBranchName: "fix-login-flow",
        ),
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.initialBranchPublished,
        ),
      );
      expect(repository.renameCalls, isEmpty);
    });

    test("adds a secure suffix when the generated target already exists", () async {
      repository.existingBranches.add("fix-login-flow");

      final result = await service.renameGeneratedBranch(
        worktreePath: "/worktree",
        initialBranchName: "blue-otter",
        generatedBranchName: "fix-login-flow",
      );

      final renamed = result as GeneratedBranchRenamed;
      expect(renamed.branchName, matches(RegExp(r"^fix-login-flow-[0-9a-f]{6}$")));
      expect(repository.renameCalls.single.newBranchName, renamed.branchName);
    });

    test("adds a secure suffix when only a matching remote target exists", () async {
      repository.remoteBranches.add("fix-login-flow");

      final result = await service.renameGeneratedBranch(
        worktreePath: "/worktree",
        initialBranchName: "blue-otter",
        generatedBranchName: "fix-login-flow",
      );

      final renamed = result as GeneratedBranchRenamed;
      expect(renamed.branchName, matches(RegExp(r"^fix-login-flow-[0-9a-f]{6}$")));
      expect(repository.renameCalls.single.newBranchName, renamed.branchName);
    });

    test("skips when collision suffixes are not valid branch names", () async {
      repository
        ..existingBranches.add("fix-login-flow")
        ..branchNameValidator = (branchName) => branchName == "fix-login-flow";

      final result = await service.renameGeneratedBranch(
        worktreePath: "/worktree",
        initialBranchName: "blue-otter",
        generatedBranchName: "fix-login-flow",
      );

      expect(
        result,
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.targetCollisions,
        ),
      );
      expect(repository.renameCalls, isEmpty);
    });

    test("restores the initial ref when current branch changes during rename", () async {
      repository.currentAfterRename = "user-branch";

      final result = await service.renameGeneratedBranch(
        worktreePath: "/worktree",
        initialBranchName: "blue-otter",
        generatedBranchName: "fix-login-flow",
      );

      expect(
        result,
        isA<GeneratedBranchRenameSkipped>().having(
          (result) => result.reason,
          "reason",
          GeneratedBranchRenameSkipReason.initialBranchChanged,
        ),
      );
      expect(repository.renameCalls, [
        (oldBranchName: "blue-otter", newBranchName: "fix-login-flow"),
        (oldBranchName: "fix-login-flow", newBranchName: "blue-otter"),
      ]);
    });

    test("restores the initial ref when post-rename confirmation fails", () async {
      repository.currentBranchReadErrorAfterRename = StateError("confirmation failed");

      await expectLater(
        service.renameGeneratedBranch(
          worktreePath: "/worktree",
          initialBranchName: "blue-otter",
          generatedBranchName: "fix-login-flow",
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.renameCalls, [
        (oldBranchName: "blue-otter", newBranchName: "fix-login-flow"),
        (oldBranchName: "fix-login-flow", newBranchName: "blue-otter"),
      ]);
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

void _expectColorAnimalSlug(String slug) {
  expect(slug, matches(RegExp(r"^[a-z]+-[a-z]+$")));
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
  int generatedPathsToOccupy = 0;

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

    if (generatedPathsToOccupy > 0 && arguments.take(2).join(" ") == "branch --list") {
      Directory("$workingDirectory/.worktrees/${arguments.last}").createSync(recursive: true);
      generatedPathsToOccupy--;
    }

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

class _GeneratedRenameWorktreeRepository() implements WorktreeRepository {
  bool validBranchName = true;
  bool Function(String branchName)? branchNameValidator;
  bool upstream = false;
  final Set<String> remoteBranches = <String>{};
  String? currentBranchName = "blue-otter";
  String? currentAfterRename;
  Object? currentBranchReadErrorAfterRename;
  final Set<String> existingBranches = <String>{};
  final List<({String oldBranchName, String newBranchName})> renameCalls = [];
  String? lastWorktreePath;

  @override
  Future<bool> isValidBranchName({required String branchName}) async {
    return branchNameValidator?.call(branchName) ?? validBranchName;
  }

  @override
  Future<String?> getCurrentBranchName({required String worktreePath}) async {
    lastWorktreePath = worktreePath;
    if (renameCalls.isNotEmpty) {
      if (currentBranchReadErrorAfterRename case final error?) throw error;
    }
    return currentBranchName;
  }

  @override
  Future<bool> hasUpstream({required String worktreePath, required String branchName}) async => upstream;

  @override
  Future<bool> hasRemoteBranch({required String worktreePath, required String branchName}) async {
    return remoteBranches.contains(branchName);
  }

  @override
  Future<bool> branchExists({required String projectPath, required String branchName}) async {
    lastWorktreePath = projectPath;
    return existingBranches.contains(branchName);
  }

  @override
  Future<void> renameBranch({
    required String worktreePath,
    required String oldBranchName,
    required String newBranchName,
  }) async {
    lastWorktreePath = worktreePath;
    renameCalls.add((oldBranchName: oldBranchName, newBranchName: newBranchName));
    currentBranchName = currentAfterRename ?? newBranchName;
    currentAfterRename = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridgePluginApi() extends FakeBridgePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
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
