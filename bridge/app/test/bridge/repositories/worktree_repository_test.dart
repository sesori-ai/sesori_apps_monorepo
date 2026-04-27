import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
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

    WorktreeRepository repository() => WorktreeRepository(
      projectsDao: db.projectsDao,
      sessionDao: db.sessionDao,
      gitApi: GitCliApi(
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
        projectId: "/repo",
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
        projectId: "/repo",
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
        projectId: "/repo",
        projectPath: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        force: false,
      );

      expect(plugin.deleteWorkspaceCallCount, equals(1));
    });
  });
}

class _FakeProcessRunner implements ProcessRunner {
  final List<ProcessResult> _queue = [];
  final List<_Invocation> invocations = [];

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

class _Invocation {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;

  _Invocation({required this.command, required this.arguments, required this.workingDirectory});
}

class _FakeBridgePlugin implements BridgePluginApi {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProcessResult _ok() => ProcessResult(0, 0, "", "");
ProcessResult _error(String stderr) => ProcessResult(0, 1, "", stderr);
