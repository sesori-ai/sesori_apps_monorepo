import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../worktree_service.dart";

/// Result of a worktree cleanup attempt.
sealed class CleanupResult {}

/// Cleanup completed successfully.
class CleanupSuccess extends CleanupResult {}

/// Cleanup rejected due to safety check failure.
class CleanupRejected extends CleanupResult {
  final SessionCleanupRejection rejection;

  CleanupRejected({required this.rejection});
}

/// Performs worktree and branch cleanup with safety checks.
///
/// Returns [CleanupRejected] if safety checks fail (and [force] is false).
/// Returns [CleanupSuccess] if cleanup completed.
Future<CleanupResult> performWorktreeCleanup({
  required WorktreeService worktreeService,
  required SessionRepository sessionRepository,
  required String sessionId,
  required String projectId,
  required String worktreePath,
  required String branchName,
  required bool deleteWorktree,
  required bool deleteBranch,
  required bool force,
}) async {
  // Shared-worktree check — bypassable with force=true so the user can resolve
  // the stalemate when multiple sessions point at the same worktree/branch.
  if ((deleteWorktree || deleteBranch) && !force) {
    final hasSharing = await sessionRepository.hasOtherActiveSessionsSharing(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: deleteWorktree ? worktreePath : null,
      branchName: deleteBranch ? branchName : null,
    );
    if (hasSharing) {
      return CleanupRejected(
        rejection: const SessionCleanupRejection(
          issues: [CleanupIssue.sharedWorktree()],
        ),
      );
    }
  }

  if (deleteWorktree && !force) {
    final safety = await worktreeService.checkWorktreeSafety(
      worktreePath: worktreePath,
      expectedBranch: branchName,
    );
    if (safety case WorktreeUnsafe(:final issues)) {
      return CleanupRejected(
        rejection: SessionCleanupRejection(
          issues: mapSafetyIssues(issues: issues),
        ),
      );
    }
  }

  if (deleteWorktree) {
    final removed = await worktreeService.removeWorktree(
      projectPath: projectId,
      worktreePath: worktreePath,
      force: force,
    );
    if (!removed) {
      Log.w(
        "worktree cleanup: failed to remove worktree for session $sessionId at $worktreePath",
      );
    }
  }

  if (deleteBranch) {
    final deleted = await worktreeService.deleteBranch(
      projectPath: projectId,
      branchName: branchName,
      force: deleteWorktree || force,
    );
    if (!deleted) {
      Log.w(
        "worktree cleanup: failed to delete branch $branchName for session $sessionId",
      );
    }
  }

  return CleanupSuccess();
}

/// Maps internal safety issues to shared cleanup issue types.
List<CleanupIssue> mapSafetyIssues({required List<SafetyIssue> issues}) {
  return issues
      .map(
        (issue) => switch (issue) {
          UnstagedChanges() => const CleanupIssue.unstagedChanges(),
          BranchMismatch(:final expected, :final actual) => CleanupIssue.branchMismatch(
            expected: expected,
            actual: actual,
          ),
        },
      )
      .toList();
}
