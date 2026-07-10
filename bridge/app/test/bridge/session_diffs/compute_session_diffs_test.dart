import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/session_diffs/compute_session_diffs.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("computeSessionDiffs", () {
    late Directory repoDir;
    late Directory worktreeDir;
    late ProcessRunner processRunner;

    setUp(() async {
      processRunner = ProcessRunner();
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
    });

    tearDown(() async {
      await _runGit(processRunner, repoDir.path, ["worktree", "remove", "--force", worktreeDir.path]);
      if (repoDir.existsSync()) {
        await repoDir.delete(recursive: true);
      }
    });

    test("includes committed, uncommitted, and untracked file changes", () async {
      final diffs = await computeSessionDiffs(
        worktreePath: worktreeDir.path,
        baseBranch: "main",
        processRunner: processRunner,
      );

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
  });
}

Future<void> _runGit(ProcessRunner runner, String cwd, List<String> args) async {
  final result = await runner.run("git", args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail("git ${args.join(" ")} failed: ${result.stderr}");
  }
}
