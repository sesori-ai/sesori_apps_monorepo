import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "worktree_service.dart";

sealed class CleanupResult {}

class CleanupSuccess extends CleanupResult {}

class CleanupRejected extends CleanupResult {
  final SessionCleanupRejection rejection;

  CleanupRejected({required this.rejection});
}

class SessionCleanupService {
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;

  SessionCleanupService({
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
  }) : _worktreeService = worktreeService,
       _sessionRepository = sessionRepository;

  Future<CleanupResult> cleanup({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (!(deleteWorktree || deleteBranch) ||
        storedSession == null ||
        storedSession.worktreePath == null ||
        storedSession.branchName == null) {
      return CleanupSuccess();
    }

    final projectId = storedSession.projectId;
    final worktreePath = storedSession.worktreePath!;
    final branchName = storedSession.branchName!;

    // Shared-worktree cleanup is forceable so the user can resolve a stalemate
    // when multiple sessions point at the same worktree or branch.
    if (!force) {
      final hasSharing = await _sessionRepository.hasOtherActiveSessionsSharing(
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
      final safety = await _worktreeService.checkWorktreeSafety(
        worktreePath: worktreePath,
        expectedBranch: branchName,
      );
      if (safety case WorktreeUnsafe(:final issues)) {
        return CleanupRejected(
          rejection: SessionCleanupRejection(
            issues: _mapSafetyIssues(issues: issues),
          ),
        );
      }
    }

    if (deleteWorktree) {
      final removed = await _worktreeService.removeWorktree(
        projectId: projectId,
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
      final deleted = await _worktreeService.deleteBranch(
        projectId: projectId,
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

  List<CleanupIssue> _mapSafetyIssues({required List<SafetyIssue> issues}) {
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
}
