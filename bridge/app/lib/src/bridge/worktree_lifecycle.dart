part of "worktree_service.dart";

extension WorktreeLifecycle on WorktreeService {
  Future<void> pruneWorktrees({required String projectPath}) async {
    await _runGit(projectPath: projectPath, arguments: const ["worktree", "prune"]);
  }

  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    if (!_isValidWorktreePath(projectPath: projectPath, worktreePath: worktreePath)) {
      return false;
    }
    await pruneWorktrees(projectPath: projectPath);
    final arguments = ["worktree", "remove", if (force) "--force", "--", worktreePath];
    final result = await _runGit(projectPath: projectPath, arguments: arguments);
    return result.exitCode == 0;
  }

  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    final result = await _runGit(
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
    if (!_isValidWorktreePath(projectPath: projectPath, worktreePath: worktreePath)) {
      return false;
    }

    final verifyResult = await _runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", "--", "refs/heads/$branchName"],
    );

    final List<String> addArguments;
    if (verifyResult.exitCode == 0) {
      addArguments = ["worktree", "add", "--", worktreePath, branchName];
    } else {
      final startPoint = baseCommit ?? baseBranch;
      addArguments = ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint];
    }

    final addResult = await _runGit(projectPath: projectPath, arguments: addArguments);
    return addResult.exitCode == 0;
  }

  /// Validates that [worktreePath] is under `<projectPath>/.worktrees/` to
  /// prevent path-traversal attacks via stored database values.
  bool _isValidWorktreePath({
    required String projectPath,
    required String worktreePath,
  }) {
    final expectedPrefix = "$projectPath/.worktrees/";
    return worktreePath.startsWith(expectedPrefix);
  }
}
