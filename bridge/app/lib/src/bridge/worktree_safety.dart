part of "worktree_service.dart";

extension WorktreeSafety on WorktreeService {
  /// Returns [WorktreeSafe] when the directory does not exist — a missing
  /// worktree is treated as already cleaned up.
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    if (!Directory(worktreePath).existsSync()) {
      return WorktreeSafe();
    }

    final issues = <SafetyIssue>[];

    final statusResult = await _processRunner.run(
      "git",
      ["status", "--porcelain"],
      workingDirectory: worktreePath,
    );
    if (statusResult.stdout.toString().trim().isNotEmpty) {
      issues.add(UnstagedChanges());
    }

    final headResult = await _processRunner.run(
      "git",
      ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: worktreePath,
    );
    final actualBranch = headResult.stdout.toString().trim();
    if (actualBranch != expectedBranch) {
      issues.add(BranchMismatch(expected: expectedBranch, actual: actualBranch));
    }

    if (issues.isEmpty) return WorktreeSafe();
    return WorktreeUnsafe(issues: issues);
  }
}
