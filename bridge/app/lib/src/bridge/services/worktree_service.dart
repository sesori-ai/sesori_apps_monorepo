import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/branch_repository.dart";
import "../repositories/worktree_repository.dart";
import "../worktree_types.dart";
import "worktree_branch_preparation_service.dart";

export "../worktree_types.dart";

const _maxWorktreeCreationAttempts = 3;
const _branchPrefix = "session-";
const _worktreeDir = ".worktrees";

class WorktreeService {
  final WorktreeRepository _worktreeRepository;
  final WorktreeBranchPreparationService _branchPreparationService;

  WorktreeService({
    required WorktreeRepository worktreeRepository,
    required BranchRepository branchRepository,
  }) : _worktreeRepository = worktreeRepository,
       _branchPreparationService = WorktreeBranchPreparationService(
         branchRepository: branchRepository,
         worktreeRepository: worktreeRepository,
         isSafeGitName: _isSafeGitName,
         randomSuffix: _randomSuffix,
       );

  static final _random = Random.secure();
  static final _safeNamePattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

  static String _randomSuffix() => _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, "0");

  static bool _isSafeGitName(String name) =>
      name.isNotEmpty &&
      name.length <= 60 &&
      !name.contains("..") &&
      !name.contains("/") &&
      !name.contains(r"\") &&
      _safeNamePattern.hasMatch(name);

  Future<WorktreeResult> prepareWorktreeForBranch({
    required WorktreeMode mode,
    required String? selectedBranch,
    required String projectPath,
    required String sessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) {
    return _branchPreparationService.prepareWorktreeForBranch(
      mode: mode,
      selectedBranch: selectedBranch,
      projectPath: projectPath,
      preferredBranchAndWorktreeName: preferredBranchAndWorktreeName,
    );
  }

  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    if (parentSessionId != null) {
      final parentWorktree = await _worktreeRepository.getParentWorktree(
        parentSessionId: parentSessionId,
      );
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
      return WorktreeFallback(
        originalPath: projectId,
        reason: "not a git repository",
      );
    }

    if (!await _worktreeRepository.hasAtLeastOneCommit(projectPath: projectId)) {
      Log.w("WorktreeService: repository has no commits: $projectId");
      return WorktreeFallback(
        originalPath: projectId,
        reason: "repository has no commits",
      );
    }

    final baseBranchAndCommit = await _worktreeRepository.resolveBaseBranchAndCommit(
      projectPath: projectId,
    );
    if (baseBranchAndCommit == null) {
      Log.w(
        "WorktreeService: failed to resolve base branch/commit for: $projectId",
      );
      return WorktreeFallback(
        originalPath: projectId,
        reason: "failed to resolve base branch/commit",
      );
    }
    final baseBranch = baseBranchAndCommit.baseBranch;
    final baseCommit = baseBranchAndCommit.baseCommit;
    final startPoint = baseBranchAndCommit.startPoint;

    if (preferredBranchAndWorktreeName != null && parentSessionId == null) {
      final preferredBranch = preferredBranchAndWorktreeName.branchName;
      final preferredWorktree = preferredBranchAndWorktreeName.worktreeName;
      if (!_isSafeGitName(preferredBranch) || !_isSafeGitName(preferredWorktree)) {
        Log.w(
          "WorktreeService: rejected unsafe preferred names: branch=$preferredBranch worktree=$preferredWorktree",
        );
      } else {
        final suffix =
            await _worktreeRepository.branchExists(
              projectPath: projectId,
              branchName: preferredBranch,
            )
            ? "-${_randomSuffix()}"
            : "";
        final branchName = "$preferredBranch$suffix";
        final worktreeName = "$preferredWorktree$suffix";
        final worktreePath = "$projectId/$_worktreeDir/$worktreeName";
        final created = await _worktreeRepository.createWorktree(
          projectPath: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          startPoint: startPoint,
        );
        if (created) {
          return WorktreeSuccess(
            path: worktreePath,
            branchName: branchName,
            baseBranch: baseBranch,
            baseCommit: baseCommit,
            isDedicated: true,
          );
        }
      }
    }

    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final counter = await _worktreeRepository.incrementAndGetWorktreeCounter(
        projectId: projectId,
      );
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      final worktreePath = "$projectId/$_worktreeDir/$branchName";

      if (await _worktreeRepository.branchExists(
        projectPath: projectId,
        branchName: branchName,
      )) {
        continue;
      }

      final created = await _worktreeRepository.createWorktree(
        projectPath: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
        startPoint: startPoint,
      );

      if (created) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
          isDedicated: true,
        );
      }
    }

    Log.w(
      "WorktreeService: failed to create worktree after 3 attempts for: $projectId",
    );
    return WorktreeFallback(
      originalPath: projectId,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectPath,
  }) async {
    return _worktreeRepository.resolveBaseBranchAndCommit(projectPath: projectPath);
  }

  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    return _worktreeRepository.checkWorktreeSafety(
      worktreePath: worktreePath,
      expectedBranch: expectedBranch,
    );
  }

  Future<void> pruneWorktrees({required String projectPath}) async {
    await _worktreeRepository.pruneWorktrees(projectPath: projectPath);
  }

  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    if (!_worktreeRepository.isValidWorktreePath(
      projectPath: projectPath,
      worktreePath: worktreePath,
    )) {
      return false;
    }
    return _worktreeRepository.removeWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      force: force,
    );
  }

  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    return _worktreeRepository.deleteBranch(
      projectPath: projectPath,
      branchName: branchName,
      force: force,
    );
  }

  Future<bool> restoreWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    if (!_worktreeRepository.isValidWorktreePath(
      projectPath: projectPath,
      worktreePath: worktreePath,
    )) {
      return false;
    }
    return _worktreeRepository.restoreWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
    );
  }
}
