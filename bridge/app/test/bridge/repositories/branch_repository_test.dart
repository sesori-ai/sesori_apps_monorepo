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
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
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

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
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
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "HEAD -> main 1700000000\nmain 1700000000\norigin/HEAD -> origin/main 1700000000\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(1));
      expect(response.branches[0].name, equals("main"));
    });

    test("handles empty branch list", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, isEmpty);
      expect(response.currentBranch, isNull);
    });

    test("fetch failure is swallowed (best-effort)", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 128, "", "fatal: could not read from remote"),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "main 100\n", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(1));
      expect(response.branches[0].name, equals("main"));
    });

    test("worktree enrichment maps branch to path correctly", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
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

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      final s001 = response.branches.firstWhere((b) => b.name == "session-001");
      expect(s001.worktreePath, equals("/repo/.worktrees/session-001"));

      final main = response.branches.firstWhere((b) => b.name == "main");
      expect(main.worktreePath, equals("/repo"));
    });

    test("branches without timestamps have null lastCommitTimestamp", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(0, 0, "main\nfeature-x\n", ""),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(2));
      expect(response.branches[0].lastCommitTimestamp, isNull);
    });

    test("supports remote-only branches from non-origin remotes", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "upstream\n", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "main 1700000000\nupstream/feature-b 1700000200\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches, hasLength(2));
      final featureB = response.branches.firstWhere((b) => b.name == "feature-b");
      expect(featureB.isRemoteOnly, isTrue);
    });

    test("filters remote HEAD pseudo refs", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "main 1700000000\norigin/HEAD 1700000050\norigin/feature-b 1700000200\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches.map((branch) => branch.name), isNot(contains("HEAD")));
      expect(response.branches.map((branch) => branch.name), contains("feature-b"));
    });

    test("supports remotes whose names contain slashes", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "foo/bar\n", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "main 1700000000\nfoo/bar/feature-b 1700000200\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "main\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      final featureB = response.branches.firstWhere((b) => b.name == "feature-b");
      expect(featureB.isRemoteOnly, isTrue);
    });

    test("keeps a local branch even when it matches a remote name", () async {
      final runner = _ScriptedProcessRunner({
        ["fetch", "--all"]: ProcessResult(0, 0, "", ""),
        ["remote"]: ProcessResult(0, 0, "origin\n", ""),
        ["branch", "-a"]: ProcessResult(
          0,
          0,
          "origin 1700000000\norigin/feature-b 1700000200\norigin/HEAD -> origin/main 1700000300\n",
          "",
        ),
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
        ["rev-parse", "--abbrev-ref", "HEAD"]: ProcessResult(0, 0, "origin\n", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final response = await repo.listBranches(projectPath: "/repo");

      expect(response.branches.map((branch) => branch.name), contains("origin"));
      final originBranch = response.branches.firstWhere((branch) => branch.name == "origin");
      expect(originBranch.isRemoteOnly, isFalse);
      expect(response.branches.map((branch) => branch.name), contains("feature-b"));
      expect(response.branches.map((branch) => branch.name), isNot(contains("HEAD")));
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

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
      final path = await repo.getWorktreeForBranch(projectPath: "/repo", branchName: "feat-x");

      expect(path, equals("/repo/.worktrees/feat-x"));
    });

    test("returns null when branch has no worktree", () async {
      final runner = _ScriptedProcessRunner({
        ["worktree", "list", "--porcelain"]: ProcessResult(0, 0, "", ""),
      });

      final repo = BranchRepository(
        gitCliApi: GitCliApi(processRunner: runner, gitPathExists: ({required String gitPath}) => true),
      );
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
