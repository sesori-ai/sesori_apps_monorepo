part of "git_cli_api.dart";

extension GitCliApiCommands on GitCliApi {
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
}
