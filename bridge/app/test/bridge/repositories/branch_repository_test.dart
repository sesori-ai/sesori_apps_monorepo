import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:test/test.dart";

void main() {
  group("BranchRepository.listBranches", () {
    test("parses branches, deduplicates local vs remote, enriches with worktrees", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "main 1700000000\nfeature-a 1700000100\norigin/main 1700000050\norigin/feature-b 1700000200\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(
          0,
          0,
          "worktree /repo\nbranch refs/heads/main\n\n"
              "worktree /repo/.worktrees/feature-a\nbranch refs/heads/feature-a\n\n",
          "",
        ),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.currentBranch, equals("main"));
      // 3 branches: main (local), feature-a (local), feature-b (remote-only)
      expect(response.branches, hasLength(3));

      final mainBranch = response.branches.firstWhere((b) => b.name == "main");
      expect(mainBranch.isRemoteOnly, isFalse);
      expect(mainBranch.lastCommitTimestamp, equals(1700000000));
      expect(mainBranch.worktreePath, equals("/repo"));

      final featureA = response.branches.firstWhere((b) => b.name == "feature-a");
      expect(featureA.isRemoteOnly, isFalse);
      expect(featureA.worktreePath, equals("/repo/.worktrees/feature-a"));

      final featureB = response.branches.firstWhere((b) => b.name == "feature-b");
      expect(featureB.isRemoteOnly, isTrue);
      expect(featureB.lastCommitTimestamp, equals(1700000200));
      expect(featureB.worktreePath, isNull);
    });

    test("skips HEAD entries", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "HEAD -> main 1700000000\nmain 1700000000\norigin/HEAD -> origin/main 1700000000\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(1));
      expect(response.branches[0].name, equals("main"));
    });

    test("handles empty branch list", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, isEmpty);
      expect(response.currentBranch, isNull);
    });

    test("fetch failure is swallowed (best-effort)", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 128, "", "fatal: could not read from remote"),
        ["branch", "-a"]: ProcessResult(0, 0, "main 100\n", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(1));
      expect(response.branches[0].name, equals("main"));
    });

    test("worktree enrichment maps branch to path correctly", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "main 100\nsession-001 200\n", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(
          0,
          0,
          "worktree /repo\nbranch refs/heads/main\n\n"
              "worktree /repo/.worktrees/session-001\nbranch refs/heads/session-001\n\n",
          "",
        ),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      final s001 = response.branches.firstWhere((b) => b.name == "session-001");
      expect(s001.worktreePath, equals("/repo/.worktrees/session-001"));

      final main = response.branches.firstWhere((b) => b.name == "main");
      expect(main.worktreePath, equals("/repo"));
    });

    test("branches without timestamps have null lastCommitTimestamp", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "main\nfeature-x\n", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(2));
      expect(response.branches[0].lastCommitTimestamp, isNull);
    });
  });

  group("BranchRepository.getWorktreeForBranch", () {
    test("returns path when branch has a worktree", () async {
      final runner = _ScriptedProcessRunner({
        ["worktree", "list", "--porcelain"]: ProcessResult(
          0,
          0,
          "worktree /repo/.worktrees/feat-x\nbranch refs/heads/feat-x\n\n",
          "",
        ),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final path = await repo.getWorktreeForBranch(projectPath: "/repo", branchName: "feat-x");

      expect(path, equals("/repo/.worktrees/feat-x"));
    });

    test("returns null when branch has no worktree", () async {
      final runner = _ScriptedProcessRunner({
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
      });

      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      final path = await repo.getWorktreeForBranch(projectPath: "/repo", branchName: "missing");

      expect(path, isNull);
    });
  });
}

/// Process runner that matches commands by a subset of arguments.
class _ScriptedProcessRunner implements ProcessRunner {
  final Map<List<String>, ProcessResult> _responses;

  _ScriptedProcessRunner(this._responses);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (final entry in _responses.entries) {
      if (entry.key.every((k) => arguments.contains(k))) {
        return entry.value;
      }
    }
    return ProcessResult(0, 0, "", "");
  }
}
