import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_diff_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_diff_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("SessionDiffService", () {
    late AppDatabase db;
    late FakeBridgePlugin plugin;
    late Directory repoDir;
    late Directory worktreeDir;
    late ProcessRunner processRunner;
    late SessionDiffService service;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      processRunner = ProcessRunner();
      final sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        gitCliApi: FakeGitCliApi(),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      service = SessionDiffService(
        sessionRepository: sessionRepository,
        sessionDiffRepository: SessionDiffRepository(
          gitCliApi: GitCliApi(
            processRunner: processRunner,
            gitPathExists: ({required String gitPath}) => true,
          ),
          outputMapper: const GitDiffOutputMapper(),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );
      repoDir = await Directory.systemTemp.createTemp("compute_session_diffs_repo_");
      worktreeDir = Directory("${repoDir.path}/session-wt");

      await _runGit(processRunner, repoDir.path, ["init"]);
      await _runGit(processRunner, repoDir.path, ["config", "user.email", "test@example.com"]);
      await _runGit(processRunner, repoDir.path, ["config", "user.name", "Test"]);

      File("${repoDir.path}/tracked.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("base tracked\n");
      File("${repoDir.path}/untouched.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("untouched\n");
      await _runGit(processRunner, repoDir.path, ["add", "."]);
      await _runGit(processRunner, repoDir.path, ["commit", "-m", "base"]);
      await _runGit(processRunner, repoDir.path, ["branch", "-M", "main"]);
      await _runGit(processRunner, repoDir.path, ["worktree", "add", worktreeDir.path, "-b", "session-branch"]);

      File("${worktreeDir.path}/tracked.txt").writeAsStringSync("committed tracked\n");
      await _runGit(processRunner, worktreeDir.path, ["add", "tracked.txt"]);
      await _runGit(processRunner, worktreeDir.path, ["commit", "-m", "session commit"]);

      File("${worktreeDir.path}/tracked.txt").writeAsStringSync("uncommitted tracked\n");
      File("${worktreeDir.path}/lib/new_untracked.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync("class New {}\n");
      await _insertStoredSession(
        db: db,
        sessionId: "session-1",
        projectId: repoDir.path,
        worktreePath: worktreeDir.path,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
      await _runGit(processRunner, repoDir.path, ["worktree", "remove", "--force", worktreeDir.path]);
      if (repoDir.existsSync()) {
        await repoDir.delete(recursive: true);
      }
    });

    test("includes committed, uncommitted, and untracked file changes", () async {
      final diffs = await service.getDiffs(sessionId: "session-1");

      final byFile = <String, FileDiff>{
        for (final diff in diffs) diff.file: diff,
      };

      expect(byFile.keys, containsAll(["tracked.txt", "lib/new_untracked.dart"]));
      expect(byFile["tracked.txt"], isA<FileDiffContent>());
      final tracked = byFile["tracked.txt"]! as FileDiffContent;
      expect(tracked.before, contains("base tracked"));
      expect(tracked.after, equals("uncommitted tracked\n"));

      expect(byFile["lib/new_untracked.dart"], isA<FileDiffContent>());
      final untracked = byFile["lib/new_untracked.dart"]! as FileDiffContent;
      expect(untracked.before, isEmpty);
      expect(untracked.after, equals("class New {}\n"));
      expect(untracked.status, FileDiffStatus.added);
      expect(untracked.additions, equals(1));
    });

    test("shows replacement content when a deleted file is recreated untracked", () async {
      await _runGit(processRunner, worktreeDir.path, ["rm", "-f", "tracked.txt"]);
      await _runGit(processRunner, worktreeDir.path, ["commit", "-m", "delete tracked"]);
      File("${worktreeDir.path}/tracked.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("replacement tracked\n");

      final diffs = await service.getDiffs(sessionId: "session-1");

      final replacement = diffs.singleWhere((diff) => diff.file == "tracked.txt");
      expect(replacement, isA<FileDiffContent>());
      final content = replacement as FileDiffContent;
      expect(content.status, FileDiffStatus.modified);
      expect(content.after, equals("replacement tracked\n"));
      expect(content.additions, equals(1));
      expect(content.deletions, greaterThan(0));
    });

    test("reads raw untracked filenames containing tabs and newlines", () async {
      const relativePath = "lib/tab\tand\nnewline.dart";
      File("${worktreeDir.path}/$relativePath")
        ..createSync(recursive: true)
        ..writeAsStringSync("special content\n");

      final diffs = await service.getDiffs(sessionId: "session-1");

      final special = diffs.singleWhere((diff) => diff.file == relativePath);
      expect(special, isA<FileDiffContent>());
      expect((special as FileDiffContent).after, equals("special content\n"));
    });

    test("keeps zero line counts for mode-only tracked changes", () async {
      await _runGit(processRunner, worktreeDir.path, ["checkout", "--", "."]);
      await _runGit(processRunner, worktreeDir.path, ["clean", "-fd"]);

      await Process.run("chmod", ["711", "${worktreeDir.path}/untouched.txt"]);

      final diffs = await service.getDiffs(sessionId: "session-1");

      final modeOnly = diffs.singleWhere((diff) => diff.file == "untouched.txt");
      expect(modeOnly, isA<FileDiffContent>());
      final content = modeOnly as FileDiffContent;
      expect(content.status, FileDiffStatus.modified);
      expect(content.additions, equals(0));
      expect(content.deletions, equals(0));
    });

    test("does not inflate additions for deletion-only tracked changes", () async {
      final deletionRepo = await Directory.systemTemp.createTemp("compute_session_diffs_deletion_");
      final deletionWorktree = Directory("${deletionRepo.path}/session-wt");
      addTearDown(() async {
        await _runGit(processRunner, deletionRepo.path, ["worktree", "remove", "--force", deletionWorktree.path]);
        if (deletionRepo.existsSync()) {
          await deletionRepo.delete(recursive: true);
        }
      });

      await _runGit(processRunner, deletionRepo.path, ["init"]);
      await _runGit(processRunner, deletionRepo.path, ["config", "user.email", "test@example.com"]);
      await _runGit(processRunner, deletionRepo.path, ["config", "user.name", "Test"]);
      File("${deletionRepo.path}/tracked.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("line one\nline two\n");
      await _runGit(processRunner, deletionRepo.path, ["add", "."]);
      await _runGit(processRunner, deletionRepo.path, ["commit", "-m", "base"]);
      await _runGit(processRunner, deletionRepo.path, ["branch", "-M", "main"]);
      await _runGit(processRunner, deletionRepo.path, [
        "worktree",
        "add",
        deletionWorktree.path,
        "-b",
        "session-branch",
      ]);
      File("${deletionWorktree.path}/tracked.txt").writeAsStringSync("line one\n");
      await _insertStoredSession(
        db: db,
        sessionId: "deletion-session",
        projectId: deletionRepo.path,
        worktreePath: deletionWorktree.path,
      );

      final diffs = await service.getDiffs(sessionId: "deletion-session");

      final tracked = diffs.singleWhere((diff) => diff.file == "tracked.txt");
      expect(tracked, isA<FileDiffContent>());
      final content = tracked as FileDiffContent;
      expect(content.after, equals("line one\n"));
      expect(content.additions, equals(0));
      expect(content.deletions, equals(1));
    });
  });
}

Future<void> _insertStoredSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String worktreePath,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    isDedicated: true,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: "session-branch",
    baseBranch: "main",
    baseCommit: "main",
    lastAgent: null,
    lastAgentModel: null,
  );
}

Future<void> _runGit(ProcessRunner runner, String cwd, List<String> args) async {
  final result = await runner.run("git", args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail("git ${args.join(" ")} failed: ${result.stderr}");
  }
}
