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

  Future<String?> resolveCommit({required String projectPath, required String ref}) async {
    final result = await runGit(projectPath: projectPath, arguments: ["rev-parse", ref]);
    if (result.exitCode != 0) {
      return null;
    }

    final commit = result.stdout.toString().trim();
    return commit.isEmpty ? null : commit;
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

  Future<ProcessResult> fetchRemotes({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["fetch", "--all"],
      workingDirectory: workingDirectory,
      timeout: const Duration(seconds: 30),
    );
  }

  Future<ProcessResult> listBranches({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["branch", "-a", "--sort=-committerdate", "--format=%(refname:short) %(committerdate:unix)"],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> listRemotes({required String workingDirectory}) {
    return _processRunner.run("git", const ["remote"], workingDirectory: workingDirectory);
  }

  Future<ProcessResult> listWorktrees({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["worktree", "list", "--porcelain"],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> addExistingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String branchName,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "--", worktreePath, branchName],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> createTrackingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String localBranchName,
    required String remoteBranch,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "-b", localBranchName, "--", worktreePath, remoteBranch],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> createWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> branchExistsLocally({
    required String workingDirectory,
    required String branchName,
  }) {
    return _processRunner.run(
      "git",
      ["branch", "--list", "--", branchName],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> revParse({
    required String workingDirectory,
    required String ref,
  }) {
    return _processRunner.run(
      "git",
      ["rev-parse", ref],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> isAncestor({
    required String workingDirectory,
    required String ancestorRef,
    required String descendantRef,
  }) {
    return _processRunner.run(
      "git",
      ["merge-base", "--is-ancestor", ancestorRef, descendantRef],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> getCurrentBranch({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: workingDirectory,
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
    return result.exitCode == 0;
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
