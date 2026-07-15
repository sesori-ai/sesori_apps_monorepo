import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

typedef GitPathExistsChecker = bool Function({required String gitPath});

class GitWorktreeSafetySnapshot {
  final bool worktreeExists;
  final bool hasUnstagedChanges;
  final String actualBranch;

  GitWorktreeSafetySnapshot({
    required this.worktreeExists,
    required this.hasUnstagedChanges,
    required this.actualBranch,
  });
}

class GitCliApi {
  final ProcessRunner _processRunner;
  final GitPathExistsChecker _gitPathExists;

  GitCliApi({
    required ProcessRunner processRunner,
    required GitPathExistsChecker gitPathExists,
  }) : _processRunner = processRunner,
       _gitPathExists = gitPathExists;

  Future<bool> isGitInitialized({required String projectPath}) async {
    return _gitPathExists(gitPath: "$projectPath/.git");
  }

  /// Initializes a new git repository at [path]. Returns `true` on success.
  Future<bool> initRepository({required String path}) async {
    final result = await _processRunner.run("git", ["init", path]);
    return result.exitCode == 0;
  }

  /// Stages all changes in [projectPath]. Returns `true` on success.
  Future<bool> stageAll({required String projectPath}) async {
    final result = await runGit(projectPath: projectPath, arguments: const ["add", "."]);
    return result.exitCode == 0;
  }

  /// Creates a commit with [message] in [projectPath]. Returns `true` on success.
  Future<bool> commitAll({required String projectPath, required String message}) async {
    final result = await runGit(projectPath: projectPath, arguments: ["commit", "-m", message]);
    return result.exitCode == 0;
  }

  Future<bool> hasAtLeastOneCommit({required String projectPath}) async {
    final result = await runGit(projectPath: projectPath, arguments: const ["rev-parse", "HEAD"]);
    return result.exitCode == 0;
  }

  Future<String> resolveDefaultBranch({required String projectPath}) async {
    final originHeadResult = await runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "refs/remotes/origin/HEAD"],
    );
    final originHeadBranch = _extractBranchName(
      output: originHeadResult.stdout,
      prefix: "refs/remotes/origin/",
    );
    if (originHeadResult.exitCode == 0 && originHeadBranch != null) {
      return originHeadBranch;
    }

    final localHeadResult = await runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "HEAD"],
    );
    final localHeadBranch = _extractBranchName(
      output: localHeadResult.stdout,
      prefix: "refs/heads/",
    );
    if (localHeadResult.exitCode == 0 && localHeadBranch != null) {
      return localHeadBranch;
    }

    final configuredDefaultBranchResult = await runGit(
      projectPath: projectPath,
      arguments: const ["config", "init.defaultBranch"],
    );
    final configuredDefaultBranch = configuredDefaultBranchResult.stdout.toString().trim();
    if (configuredDefaultBranchResult.exitCode == 0 && configuredDefaultBranch.isNotEmpty) {
      return configuredDefaultBranch;
    }

    return "main";
  }

  Future<bool> branchExists({
    required String projectPath,
    required String branchName,
  }) async {
    final result = await runGit(projectPath: projectPath, arguments: ["branch", "--list", "--", branchName]);
    return result.stdout.toString().trim().isNotEmpty;
  }

  Future<bool> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint],
    );
    return result.exitCode == 0;
  }

  Future<String?> resolveCommit({required String projectPath, required String ref}) async {
    final result = await runGit(projectPath: projectPath, arguments: ["rev-parse", ref]);
    if (result.exitCode != 0) {
      return null;
    }

    final commit = result.stdout.toString().trim();
    return commit.isEmpty ? null : commit;
  }

  Future<ProcessResult> verifyRevision({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", revision],
    );
  }

  Future<ProcessResult> findMergeBase({
    required String projectPath,
    required String baseRevision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["merge-base", baseRevision, "HEAD"],
    );
  }

  Future<ProcessResult> diffNameStatus({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: [
        "diff",
        "--no-ext-diff",
        "--no-color",
        "--no-renames",
        "--name-status",
        revision,
      ],
    );
  }

  Future<ProcessResult> diffNumstat({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: [
        "diff",
        "--no-ext-diff",
        "--no-color",
        "--no-renames",
        "--numstat",
        revision,
      ],
    );
  }

  Future<ProcessResult> listUntrackedFiles({required String projectPath}) {
    return runGit(
      projectPath: projectPath,
      arguments: const ["ls-files", "--others", "--exclude-standard"],
    );
  }

  Future<ProcessResult> readFileAtRevision({
    required String projectPath,
    required String revision,
    required String file,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["show", "$revision:$file"],
    );
  }

  Future<({String ref, String commit})> resolveStartPointForBranch({
    required String projectPath,
    required String baseBranch,
    required String localCommit,
  }) async {
    final originRef = "origin/$baseBranch";
    final originResult = await runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", originRef],
    );
    if (originResult.exitCode != 0) {
      return (ref: baseBranch, commit: localCommit);
    }

    final originCommit = originResult.stdout.toString().trim();
    if (originCommit == localCommit) {
      return (ref: baseBranch, commit: localCommit);
    }

    final mergeBaseResult = await runGit(
      projectPath: projectPath,
      arguments: ["merge-base", "--is-ancestor", originCommit, localCommit],
    );
    if (mergeBaseResult.exitCode == 0) {
      return (ref: baseBranch, commit: localCommit);
    }

    return (ref: originRef, commit: originCommit);
  }

  Future<GitWorktreeSafetySnapshot> inspectWorktreeSafety({required String worktreePath}) async {
    if (!Directory(worktreePath).existsSync()) {
      return GitWorktreeSafetySnapshot(worktreeExists: false, hasUnstagedChanges: false, actualBranch: "");
    }

    final statusResult = await _processRunner.run(
      "git",
      ["status", "--porcelain"],
      workingDirectory: worktreePath,
    );
    final hasUnstagedChanges = statusResult.stdout.toString().trim().isNotEmpty;

    final headResult = await _processRunner.run(
      "git",
      ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: worktreePath,
    );

    return GitWorktreeSafetySnapshot(
      worktreeExists: true,
      hasUnstagedChanges: hasUnstagedChanges,
      actualBranch: headResult.stdout.toString().trim(),
    );
  }

  Future<bool> hasGitHubRemote({required String projectPath}) async {
    try {
      final result = await _processRunner.run(
        "git",
        ["config", "--get", "remote.origin.url"],
        workingDirectory: projectPath,
        timeout: const Duration(seconds: 5),
      );

      if (result.exitCode != 0) return false;

      final output = result.stdout.toString().trim();
      return output.isNotEmpty && output.toLowerCase().contains("github.com");
    } on Object catch (e) {
      Log.w("[GitCli] failed to detect remote: $e");
      return false;
    }
  }

  Future<void> pruneWorktrees({required String projectPath}) async {
    await runGit(projectPath: projectPath, arguments: const ["worktree", "prune"]);
  }

  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: ["worktree", "remove", if (force) "--force", "--", worktreePath],
    );
    final removed = result.exitCode == 0;

    // Git worktree remove may leave the directory behind if it contains
    // untracked files or build artifacts. Only clean up when the git command
    // succeeded, to avoid bypassing Git's safety checks (e.g. dirty worktree).
    if (removed) {
      final worktreeDir = Directory(worktreePath);
      if (worktreeDir.existsSync()) {
        try {
          worktreeDir.deleteSync(recursive: true);
        } on FileSystemException catch (e) {
          Log.w("[GitCli] failed to delete worktree directory $worktreePath: $e");
        }
      }

      // If the parent .worktrees/ directory is now empty, clean it up too.
      final parentDir = worktreeDir.parent;
      if (parentDir.existsSync() && parentDir.path.split(Platform.pathSeparator).last == ".worktrees") {
        try {
          if (parentDir.listSync().isEmpty) {
            parentDir.deleteSync();
          }
        } on FileSystemException catch (e) {
          Log.w("[GitCli] failed to delete empty .worktrees directory ${parentDir.path}: $e");
        }
      }
    }

    return removed;
  }

  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: ["branch", force ? "-D" : "-d", "--", branchName],
    );
    return result.exitCode == 0;
  }

  Future<bool> restoreWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    final startPoint = baseCommit ?? baseBranch;
    final verifyResult = await runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", "--", "refs/heads/$branchName"],
    );

    final addResult = await runGit(
      projectPath: projectPath,
      arguments: verifyResult.exitCode == 0
          ? ["worktree", "add", "--", worktreePath, branchName]
          : ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint],
    );
    return addResult.exitCode == 0;
  }

  Future<ProcessResult> runGit({required String projectPath, required List<String> arguments}) {
    return _processRunner.run("git", arguments, workingDirectory: projectPath);
  }

  String? _extractBranchName({required Object? output, required String prefix}) {
    final trimmedOutput = output.toString().trim();
    if (!trimmedOutput.startsWith(prefix)) {
      return null;
    }
    final branchName = trimmedOutput.substring(prefix.length).trim();
    if (branchName.isEmpty) {
      return null;
    }
    return branchName;
  }
}
