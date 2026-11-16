import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/models/worktree_types.dart";
import "package:sesori_bridge/src/repositories/worktree_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("WorktreeRepository.resolveHeadCommit", () {
    late AppDatabase db;
    late _FakeProcessRunner processRunner;
    late _FakeBridgePlugin plugin;

    setUp(() {
      db = createTestDatabase();
      processRunner = _FakeProcessRunner();
      plugin = _FakeBridgePlugin();
    });

    tearDown(() async {
      await db.close();
    });

    WorktreeRepository repository({required bool isGitRepository}) => singlePluginWorktreeRepository(
      worktreesDirectory: "/worktrees",
      projectsDao: db.projectsDao,
      gitApi: GitCliApi(
        streamingProcessRunner: const StreamingProcessRunner(),
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => isGitRepository,
      ),
      plugin: plugin,
    );

    test("captures HEAD", () async {
      processRunner.enqueue(result: ProcessResult(0, 0, "abc123\n", ""));

      final result = await repository(isGitRepository: true).resolveHeadCommit(
        projectPath: "/repo",
      );

      expect(result, "abc123");
      expect(processRunner.invocations.single.arguments, ["rev-parse", "--verify", "--quiet", "HEAD^{commit}"]);
    });

    test("captures Git state when the project is nested inside a worktree", () async {
      processRunner.enqueue(result: ProcessResult(0, 0, "true\n", ""));
      processRunner.enqueue(result: ProcessResult(0, 0, "abc123\n", ""));

      final result = await repository(isGitRepository: false).resolveHeadCommit(
        projectPath: "/repo/packages/nested",
      );

      expect(result, "abc123");
      expect(processRunner.invocations[0].arguments, ["rev-parse", "--is-inside-work-tree"]);
    });

    test("returns no snapshot when the project is outside a Git worktree", () async {
      processRunner.enqueue(result: ProcessResult(0, 128, "", "fatal: not a git repository"));

      final result = await repository(isGitRepository: false).resolveHeadCommit(
        projectPath: "/plain-directory",
      );

      expect(result, isNull);
      expect(processRunner.invocations.single.arguments, ["rev-parse", "--is-inside-work-tree"]);
    });

    test("captures HEAD without inspecting existing working-tree changes", () async {
      processRunner.enqueue(result: ProcessResult(0, 0, "abc123\n", ""));

      final result = await repository(isGitRepository: true).resolveHeadCommit(
        projectPath: "/repo",
      );

      expect(result, "abc123");
      expect(processRunner.invocations.single.arguments, ["rev-parse", "--verify", "--quiet", "HEAD^{commit}"]);
    });

    test("returns no snapshot when Git snapshot capture fails", () async {
      final result = await repository(isGitRepository: true).resolveHeadCommit(
        projectPath: "/repo",
      );

      expect(result, isNull);
    });
  });

  group("WorktreeRepository.removeWorktree", () {
    late AppDatabase db;
    late _FakeProcessRunner processRunner;
    late _FakeBridgePlugin plugin;

    setUp(() {
      db = createTestDatabase();
      processRunner = _FakeProcessRunner();
      plugin = _FakeBridgePlugin();
    });

    tearDown(() async {
      await db.close();
    });

    WorktreeRepository repository() => singlePluginWorktreeRepository(
      worktreesDirectory: "/worktrees",
      projectsDao: db.projectsDao,
      gitApi: GitCliApi(
        streamingProcessRunner: const StreamingProcessRunner(),
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => true,
      ),
      plugin: plugin,
    );

    test("calls plugin.deleteWorkspace when git removal succeeds", () async {
      processRunner.enqueue(result: _ok()); // prune
      processRunner.enqueue(result: _ok()); // remove

      final repo = repository();
      await repo.removeWorktree(
        pluginId: plugin.id,
        projectPath: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        force: false,
      );

      expect(plugin.deleteWorkspaceCallCount, equals(1));
      expect(plugin.lastDeleteWorkspaceProjectId, equals("/repo"));
      expect(plugin.lastDeleteWorkspaceWorktreePath, equals("/repo/.worktrees/session-001"));
    });

    test("does not call plugin.deleteWorkspace when git removal fails", () async {
      processRunner.enqueue(result: _ok()); // prune
      processRunner.enqueue(result: _error("worktree not found")); // remove fails

      final repo = repository();
      await repo.removeWorktree(
        pluginId: plugin.id,
        projectPath: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        force: false,
      );

      expect(plugin.deleteWorkspaceCallCount, equals(0));
    });

    test("does not propagate plugin.deleteWorkspace errors", () async {
      processRunner.enqueue(result: _ok()); // prune
      processRunner.enqueue(result: _ok()); // remove
      plugin.throwOnDeleteWorkspace = true;

      final repo = repository();
      // Should not throw
      await repo.removeWorktree(
        pluginId: plugin.id,
        projectPath: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        force: false,
      );

      expect(plugin.deleteWorkspaceCallCount, equals(1));
    });

    test("drops the project's worktree folder once its last worktree is removed", () async {
      final worktreesDirectory = await Directory.systemTemp.createTemp("worktree_repository_root_");
      addTearDown(() => worktreesDirectory.delete(recursive: true));
      final repo = singlePluginWorktreeRepository(
        worktreesDirectory: worktreesDirectory.path,
        projectsDao: db.projectsDao,
        gitApi: GitCliApi(
          streamingProcessRunner: const StreamingProcessRunner(),
          processRunner: processRunner,
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      );
      final worktreePath = repo.worktreePathFor(projectPath: "/repo", slug: "session-001");
      Directory(worktreePath).createSync(recursive: true);
      processRunner.enqueue(result: _ok()); // prune
      processRunner.enqueue(result: _ok()); // remove

      await repo.removeWorktree(pluginId: plugin.id, projectPath: "/repo", worktreePath: worktreePath, force: false);

      expect(worktreesDirectory.listSync(), isEmpty);
    });
  });

  group("WorktreeRepository worktree layout", () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    WorktreeRepository repository() => singlePluginWorktreeRepository(
      worktreesDirectory: "/worktrees",
      projectsDao: db.projectsDao,
      gitApi: GitCliApi(
        streamingProcessRunner: const StreamingProcessRunner(),
        processRunner: _FakeProcessRunner(),
        gitPathExists: ({required String gitPath}) => true,
      ),
      plugin: _FakeBridgePlugin(),
    );

    test("groups worktrees under the project folder name plus a path hash", () {
      final repo = repository();

      expect(
        repo.worktreePathFor(projectPath: "/repo/project", slug: "blue-otter"),
        "/worktrees/project-9a1fd19f/blue-otter",
      );
      expect(
        repo.worktreePathFor(projectPath: "/moved/project", slug: "blue-otter"),
        "/worktrees/project-c4014039/blue-otter",
      );
    });

    test("accepts the worktree root and the legacy in-project folder, nothing else", () {
      final repo = repository();
      bool valid(String worktreePath) => repo.isValidWorktreePath(projectPath: "/repo", worktreePath: worktreePath);

      expect(valid("/worktrees/other-12345678/blue-otter"), isTrue);
      expect(valid("/repo/.worktrees/blue-otter"), isTrue);
      expect(valid("/repo/blue-otter"), isFalse);
      expect(valid("/worktrees-other/blue-otter"), isFalse);
      expect(valid("/repo/.worktrees/../../elsewhere"), isFalse);
      expect(valid("/worktrees/../elsewhere"), isFalse);
    });
  });

  group("WorktreeRepository recreating a removed worktree, in a real repository", () {
    late AppDatabase db;
    late Directory root;
    late String repoPath;
    late String worktreePath;
    late String baseBranch;
    late String baseCommit;
    late WorktreeRepository repo;

    Future<String> git({required String cwd, required List<String> args}) async {
      final result = await Process.run(
        "git",
        ["-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgSign=false", ...args],
        workingDirectory: cwd,
      );
      if (result.exitCode != 0) fail("git ${args.join(" ")} failed: ${result.stderr}");
      return result.stdout.toString().trim();
    }

    Future<String> head() => git(cwd: worktreePath, args: ["rev-parse", "HEAD"]);

    Future<String?> headBranch() async {
      final result = await Process.run("git", [
        "symbolic-ref",
        "-q",
        "--short",
        "HEAD",
      ], workingDirectory: worktreePath);
      return result.exitCode == 0 ? result.stdout.toString().trim() : null;
    }

    Future<WorktreeRecreation> recreate({required String? branchName, required bool fromBase}) => repo.recreateWorktree(
      projectPath: repoPath,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      fromBase: fromBase,
    );

    setUp(() async {
      db = createTestDatabase();
      root = await Directory.systemTemp.createTemp("worktree_recreate_test_");
      repoPath = "${root.path}/repo";
      // A parent folder that no longer exists, as after the last worktree of a
      // project is removed.
      worktreePath = "${root.path}/worktrees/project/blue-otter";
      await git(cwd: root.path, args: ["init", "--quiet", repoPath]);
      await git(cwd: repoPath, args: ["commit", "--quiet", "--allow-empty", "-m", "base"]);
      baseBranch = await git(cwd: repoPath, args: ["rev-parse", "--abbrev-ref", "HEAD"]);
      baseCommit = await git(cwd: repoPath, args: ["rev-parse", "HEAD"]);
      repo = singlePluginWorktreeRepository(
        worktreesDirectory: "${root.path}/worktrees",
        projectsDao: db.projectsDao,
        gitApi: GitCliApi(
          streamingProcessRunner: const StreamingProcessRunner(),
          processRunner: ProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: _FakeBridgePlugin(),
      );
    });

    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    test("checks out the kept branch with its last commit", () async {
      await git(cwd: repoPath, args: ["worktree", "add", "--quiet", "-b", "sesori/task", worktreePath, baseCommit]);
      await git(cwd: worktreePath, args: ["commit", "--quiet", "--allow-empty", "-m", "work"]);
      final workCommit = await head();
      await git(cwd: repoPath, args: ["worktree", "remove", worktreePath]);
      expect(await repo.worktreeExists(worktreePath: worktreePath), isFalse);

      expect(await recreate(branchName: "sesori/task", fromBase: false), isA<WorktreeRecreated>());

      expect(await repo.worktreeExists(worktreePath: worktreePath), isTrue);
      expect(await headBranch(), "sesori/task");
      expect(await head(), workCommit);
    });

    test("prunes a worktree whose folder was deleted behind git's back", () async {
      await git(cwd: repoPath, args: ["worktree", "add", "--quiet", "-b", "sesori/task", worktreePath, baseCommit]);
      await Directory(worktreePath).delete(recursive: true);

      expect(await recreate(branchName: "sesori/task", fromBase: false), isA<WorktreeRecreated>());

      expect(await headBranch(), "sesori/task");
    });

    test("a missing branch is reported until recreating from the base is asked for", () async {
      expect(await recreate(branchName: "sesori/gone", fromBase: false), isA<WorktreeRecreationBranchMissing>());
      expect(Directory(worktreePath).existsSync(), isFalse);

      await git(cwd: repoPath, args: ["commit", "--quiet", "--allow-empty", "-m", "later"]);
      expect(await recreate(branchName: "sesori/gone", fromBase: true), isA<WorktreeRecreated>());

      expect(await headBranch(), "sesori/gone");
      expect(await head(), baseCommit);
    });

    test("a detached worktree kept no branch, so it is recreated detached at the base commit", () async {
      expect(await recreate(branchName: null, fromBase: false), isA<WorktreeRecreationBranchMissing>());

      expect(await recreate(branchName: null, fromBase: true), isA<WorktreeRecreated>());

      expect(await headBranch(), isNull);
      expect(await head(), baseCommit);
      expect(await git(cwd: repoPath, args: ["for-each-ref", "--format=%(refname:short)", "refs/heads"]), baseBranch);
    });

    test("a branch checked out elsewhere fails without touching the path", () async {
      await git(cwd: repoPath, args: ["branch", "sesori/task"]);
      await git(cwd: repoPath, args: ["checkout", "--quiet", "sesori/task"]);

      expect(await recreate(branchName: "sesori/task", fromBase: false), isA<WorktreeRecreationFailed>());

      expect(Directory(worktreePath).existsSync(), isFalse);
    });

    test("a plain folder at the path is not a worktree", () async {
      Directory(worktreePath).createSync(recursive: true);

      expect(await repo.worktreeExists(worktreePath: worktreePath), isFalse);
      expect(repo.worktreePathExists(worktreePath: worktreePath), isTrue);
    });
  });
}

class _FakeProcessRunner() implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
  }) async {
    throw UnimplementedError();
  }

  final List<ProcessResult> _queue = [];
  final List<_Invocation> invocations = [];

  void enqueue({required ProcessResult result}) {
    _queue.add(result);
  }

  @override
  Future<ProcessResult> run({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
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

class _Invocation({
  required final String command,
  required final List<String> arguments,
  required final String? workingDirectory,
});

class _FakeBridgePlugin() implements NativeProjectsPluginApi {
  int deleteWorkspaceCallCount = 0;
  String? lastDeleteWorkspaceProjectId;
  String? lastDeleteWorkspaceWorktreePath;
  bool throwOnDeleteWorkspace = false;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    deleteWorkspaceCallCount++;
    lastDeleteWorkspaceProjectId = projectId;
    lastDeleteWorkspaceWorktreePath = worktreePath;
    if (throwOnDeleteWorkspace) {
      throw Exception("OpenCode unavailable");
    }
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProcessResult _ok() => ProcessResult(0, 0, "", "");
ProcessResult _error(String stderr) => ProcessResult(0, 1, "", stderr);
