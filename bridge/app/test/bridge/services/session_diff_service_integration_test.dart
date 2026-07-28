import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_diff_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_diff_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

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
      final sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final gitCliApi = GitCliApi(
        processRunner: processRunner,
        gitPathExists: ({required String gitPath}) => true,
      );
      service = SessionDiffService(
        sessionRepository: sessionRepository,
        sessionDiffRepository: SessionDiffRepository(
          gitCliApi: gitCliApi,
          outputMapper: const GitDiffOutputMapper(),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        worktreeRepository: singlePluginWorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: gitCliApi,
          plugin: plugin,
        ),
      );
      repoDir = await Directory.systemTemp.createTemp("compute_session_diffs_repo_");
      worktreeDir = Directory("${repoDir.path}/session-wt");

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["init"]);
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["config", "user.email", "test@example.com"],
      );
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["config", "user.name", "Test"]);

      File("${repoDir.path}/tracked.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("base tracked\n");
      File("${repoDir.path}/untouched.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("untouched\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "."]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "base"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-M", "main"]);
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["worktree", "add", worktreeDir.path, "-b", "session-branch"],
      );

      File("${worktreeDir.path}/tracked.txt").writeAsStringSync("committed tracked\n");
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["add", "tracked.txt"]);
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["commit", "-m", "session commit"]);

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
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["worktree", "remove", "--force", worktreeDir.path],
      );
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

    test("in-place session on its starting branch compares against the start commit", () async {
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-same-branch",
        projectId: repoDir.path,
        startingBranch: "main",
        startCommit: startCommit,
      );

      File("${repoDir.path}/tracked.txt").writeAsStringSync("committed in-place\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "tracked.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "in-place commit"]);
      File("${repoDir.path}/tracked.txt").writeAsStringSync("local in-place\n");

      final diffs = await service.getDiffs(sessionId: "in-place-same-branch");

      final tracked = diffs.singleWhere((diff) => diff.file == "tracked.txt") as FileDiffContent;
      expect(tracked.before, "base tracked\n");
      expect(tracked.after, "local in-place\n");
    });

    test("same-name tag does not change the current branch identity", () async {
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-tagged-current",
        projectId: repoDir.path,
        startingBranch: "main",
        startCommit: startCommit,
      );

      File("${repoDir.path}/tagged-current.txt").writeAsStringSync("session work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "tagged-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "tagged current"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["tag", "main", startCommit]);

      final diffs = await service.getDiffs(sessionId: "in-place-tagged-current");

      expect(diffs.map((diff) => diff.file), contains("tagged-current.txt"));
    });

    test("rewritten starting branch falls back to the project base", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "rewritten-same"]);
      File("${repoDir.path}/old-history.txt").writeAsStringSync("old history\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "old-history.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "old history"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-rewritten-same",
        projectId: repoDir.path,
        startingBranch: "rewritten-same",
        startCommit: startCommit,
      );

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["reset", "--hard", "main"]);
      File("${repoDir.path}/rewritten-current.txt").writeAsStringSync("committed current\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "rewritten-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "rewritten current"]);
      File("${repoDir.path}/rewritten-current.txt").writeAsStringSync("local current\n");

      final diffs = await service.getDiffs(sessionId: "in-place-rewritten-same");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("rewritten-current.txt"));
      expect(byFile.keys, isNot(contains("old-history.txt")));
      expect((byFile["rewritten-current.txt"]! as FileDiffContent).before, isEmpty);
    });

    test("pruned start commit falls back to the project base", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "pruned-start"]);
      File("${repoDir.path}/pruned-history.txt").writeAsStringSync("pruned history\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "pruned-history.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "pruned history"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-pruned",
        projectId: repoDir.path,
        startingBranch: "pruned-start",
        startCommit: startCommit,
      );

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["reset", "--hard", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["reflog", "expire", "--expire=now", "--all"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["gc", "--prune=now"]);
      File("${repoDir.path}/tracked.txt").writeAsStringSync("after prune\n");

      final diffs = await service.getDiffs(sessionId: "in-place-pruned");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("tracked.txt"));
      expect(byFile.keys, isNot(contains("pruned-history.txt")));
    });

    test("renamed starting branch keeps the start commit baseline", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "before-rename"]);
      File("${repoDir.path}/before-session.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "before-session.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "before session"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-renamed",
        projectId: repoDir.path,
        startingBranch: "before-rename",
        startCommit: startCommit,
      );

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-m", "after-rename"]);
      File("${repoDir.path}/after-session.txt").writeAsStringSync("after session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "after-session.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "after session"]);

      final diffs = await service.getDiffs(sessionId: "in-place-renamed");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("after-session.txt"));
      expect(byFile.keys, isNot(contains("before-session.txt")));
    });

    test("saved branch is resolved through refs heads when a tag has the same name", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "tagged-start"]);
      File("${repoDir.path}/before-tagged-session.txt").writeAsStringSync("before tagged session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "before-tagged-session.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "before tagged session"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "tagged-current"]);
      File("${repoDir.path}/after-tagged-session.txt").writeAsStringSync("after tagged session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "after-tagged-session.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "after tagged session"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["tag", "tagged-start", "main"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-tagged",
        projectId: repoDir.path,
        startingBranch: "tagged-start",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-tagged");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("after-tagged-session.txt"));
      expect(byFile.keys, isNot(contains("before-tagged-session.txt")));
    });

    test("divergent starting branch keeps an ancestral start commit baseline", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "rescued-start"]);
      File("${repoDir.path}/before-rescue.txt").writeAsStringSync("before rescue\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "before-rescue.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "before rescue"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "rescued-current"]);
      File("${repoDir.path}/after-rescue.txt").writeAsStringSync("after rescue\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "after-rescue.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "after rescue"]);
      final tree = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD^{tree}"],
      )).stdout.toString().trim();
      final divergentCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["commit-tree", tree, "-m", "divergent root"],
      )).stdout.toString().trim();
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["branch", "-f", "rescued-start", divergentCommit],
      );
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-rescued",
        projectId: repoDir.path,
        startingBranch: "rescued-start",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-rescued");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("after-rescue.txt"));
      expect(byFile.keys, isNot(contains("before-rescue.txt")));
    });

    test("related custom branches use the saved branch merge base", () async {
      final mainCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "main"],
      )).stdout.toString().trim();
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "release"]);
      File("${repoDir.path}/release-only.txt").writeAsStringSync("release only\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "release-only.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "release only"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["checkout", "-b", "custom-current", mainCommit],
      );
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-D", "main"]);
      File("${repoDir.path}/custom-current.txt").writeAsStringSync("custom current\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "custom-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "custom current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-custom-base",
        projectId: repoDir.path,
        startingBranch: "release",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-custom-base");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("custom-current.txt"));
      expect(byFile.keys, isNot(contains("release-only.txt")));
    });

    test("missing custom branch uses the surviving start commit merge base", () async {
      final mainCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "main"],
      )).stdout.toString().trim();
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "deleted-start"]);
      File("${repoDir.path}/deleted-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "deleted-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "deleted start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["checkout", "-b", "deleted-current", mainCommit],
      );
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-D", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-D", "deleted-start"]);
      File("${repoDir.path}/deleted-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "deleted-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "deleted current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-deleted-start",
        projectId: repoDir.path,
        startingBranch: "deleted-start",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-deleted-start");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("deleted-current.txt"));
      expect(byFile.keys, isNot(contains("deleted-start.txt")));
    });

    test("detached start uses the surviving commit merge base", () async {
      final mainCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "main"],
      )).stdout.toString().trim();
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "detached-related-start"]);
      File("${repoDir.path}/detached-related-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "detached-related-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "detached related start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "--detach", startCommit]);

      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["checkout", "-b", "detached-related-current", mainCommit],
      );
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-D", "main"]);
      File("${repoDir.path}/detached-related-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "detached-related-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "detached related current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-detached-related",
        projectId: repoDir.path,
        startingBranch: null,
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-detached-related");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("detached-related-current.txt"));
      expect(byFile.keys, isNot(contains("detached-related-start.txt")));
    });

    test("sibling branch prefers the configured project base", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "sibling-start"]);
      File("${repoDir.path}/sibling-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "sibling-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "sibling start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      File("${repoDir.path}/upstream-after-start.txt").writeAsStringSync("upstream\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "upstream-after-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "upstream update"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "sibling-current"]);
      File("${repoDir.path}/sibling-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "sibling-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "sibling current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-sibling",
        projectId: repoDir.path,
        startingBranch: "sibling-start",
        startCommit: startCommit,
      );
      await db.projectsDao.setBaseBranch(projectId: repoDir.path, baseBranch: "main");

      final diffs = await service.getDiffs(sessionId: "in-place-sibling");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("sibling-current.txt"));
      expect(byFile.keys, isNot(contains("upstream-after-start.txt")));
      expect(byFile.keys, isNot(contains("sibling-start.txt")));
    });

    test("non-origin remote default is used as the project base", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "upstream-start"]);
      File("${repoDir.path}/upstream-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "upstream-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "upstream start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      File("${repoDir.path}/upstream-update.txt").writeAsStringSync("upstream update\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "upstream-update.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "upstream update"]);
      final upstreamCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["remote", "add", "upstream", repoDir.path]);
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["update-ref", "refs/remotes/upstream/main", upstreamCommit],
      );
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["symbolic-ref", "refs/remotes/upstream/HEAD", "refs/remotes/upstream/main"],
      );
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "upstream-current"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-D", "main"]);
      File("${repoDir.path}/upstream-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "upstream-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "upstream current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-upstream-base",
        projectId: repoDir.path,
        startingBranch: "upstream-start",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-upstream-base");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("upstream-current.txt"));
      expect(byFile.keys, isNot(contains("upstream-update.txt")));
      expect(byFile.keys, isNot(contains("upstream-start.txt")));
    });

    test("stored project base reconciles a newer origin tracking ref", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "stored-tracking-start"]);
      File("${repoDir.path}/stored-tracking-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "stored-tracking-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "stored tracking start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "remote-main", "main"]);
      File("${repoDir.path}/stored-tracking-upstream.txt").writeAsStringSync("upstream\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "stored-tracking-upstream.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "stored tracking upstream"]);
      final remoteMainCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["update-ref", "refs/remotes/origin/main", remoteMainCommit],
      );
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["checkout", "-b", "stored-tracking-current", remoteMainCommit],
      );
      File("${repoDir.path}/stored-tracking-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "stored-tracking-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "stored tracking current"]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-stored-tracking",
        projectId: repoDir.path,
        startingBranch: "stored-tracking-start",
        startCommit: startCommit,
      );
      await db.projectsDao.setBaseBranch(projectId: repoDir.path, baseBranch: "main");

      final diffs = await service.getDiffs(sessionId: "in-place-stored-tracking");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("stored-tracking-current.txt"));
      expect(byFile.keys, isNot(contains("stored-tracking-upstream.txt")));
      expect(byFile.keys, isNot(contains("stored-tracking-start.txt")));
    });

    test("stored project base is resolved through refs heads", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "tagged-base-start"]);
      File("${repoDir.path}/tagged-base-start.txt").writeAsStringSync("before session\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "tagged-base-start.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "tagged base start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      File("${repoDir.path}/tagged-base-upstream.txt").writeAsStringSync("upstream\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "tagged-base-upstream.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "tagged base upstream"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "tagged-base-current"]);
      File("${repoDir.path}/tagged-base-current.txt").writeAsStringSync("current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "tagged-base-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "tagged base current"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["tag", "main", startCommit]);
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-tagged-base",
        projectId: repoDir.path,
        startingBranch: null,
        startCommit: startCommit,
      );
      await db.projectsDao.setBaseBranch(projectId: repoDir.path, baseBranch: "main");

      final diffs = await service.getDiffs(sessionId: "in-place-tagged-base");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("tagged-base-current.txt"));
      expect(byFile.keys, isNot(contains("tagged-base-upstream.txt")));
      expect(byFile.keys, isNot(contains("tagged-base-start.txt")));
    });

    test("nested project diffs stay inside the opened directory", () async {
      final nestedDir = Directory("${repoDir.path}/packages/opened")..createSync(recursive: true);
      final siblingDir = Directory("${repoDir.path}/packages/private")..createSync(recursive: true);
      File("${nestedDir.path}/tracked.txt").writeAsStringSync("nested before\n");
      File("${siblingDir.path}/secret.txt").writeAsStringSync("secret before\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "packages"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "nested baseline"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: nestedDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-nested",
        projectId: nestedDir.path,
        startingBranch: "main",
        startCommit: startCommit,
      );

      File("${nestedDir.path}/tracked.txt").writeAsStringSync("nested after\n");
      File("${nestedDir.path}/new.txt").writeAsStringSync("nested new\n");
      File("${siblingDir.path}/secret.txt").deleteSync();
      File("${siblingDir.path}/untracked-secret.txt").writeAsStringSync("private\n");

      final diffs = await service.getDiffs(sessionId: "in-place-nested");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, unorderedEquals(["tracked.txt", "new.txt"]));
      final tracked = byFile["tracked.txt"]! as FileDiffContent;
      expect(tracked.before, "nested before\n");
      expect(tracked.after, "nested after\n");
    });

    test("rebased stacked branch compares against the rewritten starting branch", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "stack-base"]);
      File("${repoDir.path}/old-base.txt").writeAsStringSync("old base\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "old-base.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "original stack base"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "stack-session"]);
      File("${repoDir.path}/session-change.txt").writeAsStringSync("committed session change\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "session-change.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "stacked session change"]);

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["branch", "-f", "stack-base", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "stack-base"]);
      File("${repoDir.path}/rebased-base.txt").writeAsStringSync("rewritten base\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "rebased-base.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "rewritten stack base"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "stack-session"]);
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rebase", "--onto", "stack-base", startCommit],
      );

      File("${repoDir.path}/session-change.txt").writeAsStringSync("local session change\n");
      File("${repoDir.path}/local-untracked.txt").writeAsStringSync("local only\n");
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-stacked",
        projectId: repoDir.path,
        startingBranch: "stack-base",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-stacked");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, containsAll(["session-change.txt", "local-untracked.txt"]));
      expect(byFile.keys, isNot(contains("old-base.txt")));
      expect(byFile.keys, isNot(contains("rebased-base.txt")));
      expect((byFile["session-change.txt"]! as FileDiffContent).after, "local session change\n");
    });

    test("unrelated branch compares against the project's base branch", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "session-start"]);
      File("${repoDir.path}/starting-branch-only.txt").writeAsStringSync("not part of current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "starting-branch-only.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "starting branch"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "unrelated"]);
      File("${repoDir.path}/unrelated-branch.txt").writeAsStringSync("committed unrelated work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "unrelated-branch.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "unrelated work"]);
      File("${repoDir.path}/unrelated-branch.txt").writeAsStringSync("local unrelated work\n");
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-unrelated",
        projectId: repoDir.path,
        startingBranch: "session-start",
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-unrelated");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("unrelated-branch.txt"));
      expect(byFile.keys, isNot(contains("starting-branch-only.txt")));
      final unrelated = byFile["unrelated-branch.txt"]! as FileDiffContent;
      expect(unrelated.before, isEmpty);
      expect(unrelated.after, "local unrelated work\n");
      expect(unrelated.status, FileDiffStatus.added);
    });

    test("unrelated detached HEAD compares against the project's base branch", () async {
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "detached-start"]);
      File("${repoDir.path}/detached-start-only.txt").writeAsStringSync("starting history\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "detached-start-only.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "detached start"]);
      final startCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();

      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "main"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["checkout", "-b", "detached-unrelated"]);
      File("${repoDir.path}/detached-current.txt").writeAsStringSync("committed current work\n");
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["add", "detached-current.txt"]);
      await _runGit(runner: processRunner, cwd: repoDir.path, args: ["commit", "-m", "detached current"]);
      final currentCommit = (await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["rev-parse", "HEAD"],
      )).stdout.toString().trim();
      await _runGit(
        runner: processRunner,
        cwd: repoDir.path,
        args: ["checkout", "--detach", currentCommit],
      );
      File("${repoDir.path}/detached-current.txt").writeAsStringSync("local current work\n");
      await db.projectsDao.setBaseBranch(projectId: repoDir.path, baseBranch: "main");
      await _insertInPlaceStoredSession(
        db: db,
        sessionId: "in-place-detached-unrelated",
        projectId: repoDir.path,
        startingBranch: null,
        startCommit: startCommit,
      );

      final diffs = await service.getDiffs(sessionId: "in-place-detached-unrelated");
      final byFile = {for (final diff in diffs) diff.file: diff};

      expect(byFile.keys, contains("detached-current.txt"));
      expect(byFile.keys, isNot(contains("detached-start-only.txt")));
      expect((byFile["detached-current.txt"]! as FileDiffContent).before, isEmpty);
    });

    test("shows replacement content when a deleted file is recreated untracked", () async {
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["rm", "-f", "tracked.txt"]);
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["commit", "-m", "delete tracked"]);
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
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["checkout", "--", "."]);
      await _runGit(runner: processRunner, cwd: worktreeDir.path, args: ["clean", "-fd"]);

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
        await _runGit(
          runner: processRunner,
          cwd: deletionRepo.path,
          args: ["worktree", "remove", "--force", deletionWorktree.path],
        );
        if (deletionRepo.existsSync()) {
          await deletionRepo.delete(recursive: true);
        }
      });

      await _runGit(runner: processRunner, cwd: deletionRepo.path, args: ["init"]);
      await _runGit(
        runner: processRunner,
        cwd: deletionRepo.path,
        args: ["config", "user.email", "test@example.com"],
      );
      await _runGit(runner: processRunner, cwd: deletionRepo.path, args: ["config", "user.name", "Test"]);
      File("${deletionRepo.path}/tracked.txt")
        ..createSync(recursive: true)
        ..writeAsStringSync("line one\nline two\n");
      await _runGit(runner: processRunner, cwd: deletionRepo.path, args: ["add", "."]);
      await _runGit(runner: processRunner, cwd: deletionRepo.path, args: ["commit", "-m", "base"]);
      await _runGit(runner: processRunner, cwd: deletionRepo.path, args: ["branch", "-M", "main"]);
      await _runGit(
        runner: processRunner,
        cwd: deletionRepo.path,
        args: [
          "worktree",
          "add",
          deletionWorktree.path,
          "-b",
          "session-branch",
        ],
      );
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

Future<void> _insertInPlaceStoredSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String? startingBranch,
  required String startCommit,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: startingBranch,
    baseCommit: startCommit,
    lastAgent: null,
    lastAgentModel: null,
  );
}

Future<ProcessResult> _runGit({
  required ProcessRunner runner,
  required String cwd,
  required List<String> args,
}) async {
  final result = await runner.run("git", args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail("git ${args.join(" ")} failed: ${result.stderr}");
  }
  return result;
}
