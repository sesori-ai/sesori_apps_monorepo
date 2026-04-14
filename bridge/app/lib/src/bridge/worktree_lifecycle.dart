part of "worktree_service.dart";

class _WorktreeLifecycleService {
  final WorktreeService _service;

  _WorktreeLifecycleService({required WorktreeService service}) : _service = service;

  Future<void> pruneWorktrees({required String projectPath}) async {
    await _service._runGit(projectPath: projectPath, arguments: const ["worktree", "prune"]);
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
    final result = await _service._runGit(projectPath: projectPath, arguments: arguments);
    return result.exitCode == 0;
  }

  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    final result = await _service._runGit(
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

    final verifyResult = await _service._runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", "--", "refs/heads/$branchName"],
    );

    final addArguments = verifyResult.exitCode == 0
        ? ["worktree", "add", "--", worktreePath, branchName]
        : ["worktree", "add", "-b", branchName, "--", worktreePath, baseCommit ?? baseBranch];

    final addResult = await _service._runGit(projectPath: projectPath, arguments: addArguments);
    return addResult.exitCode == 0;
  }

  bool _isValidWorktreePath({
    required String projectPath,
    required String worktreePath,
  }) {
    final expectedPrefix = "$projectPath/.worktrees/";
    return worktreePath.startsWith(expectedPrefix);
  }
}
