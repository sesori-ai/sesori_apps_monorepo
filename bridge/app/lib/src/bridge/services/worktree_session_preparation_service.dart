import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/branch_repository.dart";
import "../repositories/worktree_repository.dart";
import "../worktree_types.dart";

const _maxWorktreeCreationAttempts = 3;
const _branchPrefix = "session-";
const _worktreeDir = ".worktrees";

class WorktreeSessionPreparationService {
  final WorktreeRepository _worktreeRepository;
  final BranchRepository _branchRepository;
  final bool Function(String name) _isSafeGitName;
  final String Function() _randomSuffix;

  WorktreeSessionPreparationService({
    required WorktreeRepository worktreeRepository,
    required BranchRepository branchRepository,
    required bool Function(String name) isSafeGitName,
    required String Function() randomSuffix,
  }) : _worktreeRepository = worktreeRepository,
       _branchRepository = branchRepository,
       _isSafeGitName = isSafeGitName,
       _randomSuffix = randomSuffix;

  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    if (parentSessionId != null) {
      final parentWorktree = await _worktreeRepository.getParentWorktree(parentSessionId: parentSessionId);
      if (parentWorktree != null) {
        return WorktreeSuccess(
          path: parentWorktree.path,
          branchName: parentWorktree.branchName,
          baseBranch: parentWorktree.baseBranch,
          baseCommit: parentWorktree.baseCommit,
          isDedicated: true,
        );
      }
    }

    if (!await _worktreeRepository.isGitInitialized(projectPath: projectId)) {
      Log.w("WorktreeService: not a git repository: $projectId");
      return WorktreeFallback(originalPath: projectId, reason: "not a git repository");
    }

    if (!await _worktreeRepository.hasAtLeastOneCommit(projectPath: projectId)) {
      Log.w("WorktreeService: repository has no commits: $projectId");
      return WorktreeFallback(originalPath: projectId, reason: "repository has no commits");
    }

    final baseBranchAndCommit = await _worktreeRepository.resolveBaseBranchAndCommit(projectPath: projectId);
    if (baseBranchAndCommit == null) {
      Log.w("WorktreeService: failed to resolve base branch/commit for: $projectId");
      return WorktreeFallback(originalPath: projectId, reason: "failed to resolve base branch/commit");
    }

    final preferredResult = await _tryCreatePreferredBranchWorktree(
      projectId: projectId,
      startPoint: baseBranchAndCommit.startPoint,
      baseBranch: baseBranchAndCommit.baseBranch,
      baseCommit: baseBranchAndCommit.baseCommit,
      preferredBranchAndWorktreeName: preferredBranchAndWorktreeName,
    );
    if (preferredResult != null) {
      return preferredResult;
    }

    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final counter = await _worktreeRepository.incrementAndGetWorktreeCounter(projectId: projectId);
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      if (await _branchRepository.branchExistsLocally(projectPath: projectId, branchName: branchName)) {
        continue;
      }

      final worktreePath = "$projectId/$_worktreeDir/$branchName";
      final success = await _branchRepository.createWorktree(
        projectPath: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
        startPoint: baseBranchAndCommit.startPoint,
      );
      if (success) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranchAndCommit.baseBranch,
          baseCommit: baseBranchAndCommit.baseCommit,
          isDedicated: true,
        );
      }
    }

    Log.w("WorktreeService: failed to create worktree after 3 attempts for: $projectId");
    return WorktreeFallback(originalPath: projectId, reason: "failed to create worktree after 3 attempts");
  }

  Future<WorktreeSuccess?> _tryCreatePreferredBranchWorktree({
    required String projectId,
    required String startPoint,
    required String baseBranch,
    required String baseCommit,
    required ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    if (preferredBranchAndWorktreeName == null) {
      return null;
    }

    final preferredBranch = preferredBranchAndWorktreeName.branchName;
    final preferredWorktree = preferredBranchAndWorktreeName.worktreeName;
    if (!_isSafeGitName(preferredBranch) || !_isSafeGitName(preferredWorktree)) {
      Log.w("WorktreeService: rejected unsafe preferred names: branch=$preferredBranch worktree=$preferredWorktree");
      return null;
    }

    final suffix = await _branchRepository.branchExistsLocally(projectPath: projectId, branchName: preferredBranch)
        ? "-${_randomSuffix()}"
        : "";
    final branchName = "$preferredBranch$suffix";
    final worktreeName = "$preferredWorktree$suffix";
    final worktreePath = "$projectId/$_worktreeDir/$worktreeName";
    final success = await _branchRepository.createWorktree(
      projectPath: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
      startPoint: startPoint,
    );
    if (!success) {
      return null;
    }

    return WorktreeSuccess(
      path: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      isDedicated: true,
    );
  }
}
