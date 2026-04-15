import "dart:math";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/branch_repository.dart";
import "../repositories/worktree_repository.dart";
import "../worktree_types.dart";
import "worktree_branch_preparation_service.dart";
import "worktree_session_preparation_service.dart";

export "../worktree_types.dart";

class WorktreeService {
  final WorktreeRepository _worktreeRepository;
  final WorktreeBranchPreparationService _branchPreparationService;
  final WorktreeSessionPreparationService _sessionPreparationService;

  WorktreeService({
    required WorktreeRepository worktreeRepository,
    required BranchRepository branchRepository,
  }) : _worktreeRepository = worktreeRepository,
       _branchPreparationService = WorktreeBranchPreparationService(
         branchRepository: branchRepository,
         worktreeRepository: worktreeRepository,
         isSafeGitName: _isSafeGitName,
         randomSuffix: _randomSuffix,
       ),
       _sessionPreparationService = WorktreeSessionPreparationService(
         worktreeRepository: worktreeRepository,
         branchRepository: branchRepository,
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
  }) {
    return _sessionPreparationService.prepareWorktreeForSession(
      projectId: projectId,
      parentSessionId: parentSessionId,
      preferredBranchAndWorktreeName: preferredBranchAndWorktreeName,
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
