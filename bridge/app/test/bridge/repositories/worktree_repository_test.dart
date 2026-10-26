import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
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
}

class _FakeProcessRunner() implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final List<ProcessResult> _queue = [];
  final List<_Invocation> invocations = [];

  void enqueue({required ProcessResult result}) {
    _queue.add(result);
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
