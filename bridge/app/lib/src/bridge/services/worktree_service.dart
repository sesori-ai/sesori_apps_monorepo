import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/worktree_repository.dart";
import "../worktree_types.dart";

export "../worktree_types.dart";

const _maxWorktreeCreationAttempts = 3;
const _branchPrefix = "session-";
const _worktreeDir = ".worktrees";

/// Orchestrates worktree lifecycle for sessions. Callers hand in the stable
/// project IDENTIFIER; this service resolves it to the project's live
/// directory before every git operation (a moved folder keeps its identity
/// but git must run where the folder actually is), while database writes
/// (base-branch override) stay keyed on the identifier.
class WorktreeService({required final WorktreeRepository _worktreeRepository}) {
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
        );
      }
    }

    final projectPath = await _worktreeRepository.resolveProjectPath(projectId: projectId);

    if (!await _worktreeRepository.isGitInitialized(projectPath: projectPath)) {
      Log.w("WorktreeService: not a git repository: $projectPath");
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "not a git repository",
      );
    }

    if (!await _worktreeRepository.hasAtLeastOneCommit(projectPath: projectPath)) {
      Log.w("WorktreeService: repository has no commits: $projectPath");
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "repository has no commits",
      );
    }

    final baseBranchAndCommit = await _worktreeRepository.resolveBaseBranchAndCommit(
      projectId: projectId,
      projectPath: projectPath,
      refreshOrigin: true,
    );
    if (baseBranchAndCommit == null) {
      Log.w(
        "WorktreeService: failed to resolve base branch/commit for: $projectPath",
      );
      return WorktreeFallback(
        originalPath: projectPath,
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
              projectPath: projectPath,
              branchName: preferredBranch,
            )
            ? "-${_randomSuffix()}"
            : "";
        final branchName = "$preferredBranch$suffix";
        final worktreeName = "$preferredWorktree$suffix";
        final worktreePath = "$projectPath/$_worktreeDir/$worktreeName";
        final created = await _worktreeRepository.createWorktree(
          projectPath: projectPath,
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
          );
        }
      }
    }

    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final branchName = "$_branchPrefix${_randomSuffix()}";
      final worktreePath = "$projectPath/$_worktreeDir/$branchName";

      if (await _worktreeRepository.branchExists(
        projectPath: projectPath,
        branchName: branchName,
      )) {
        continue;
      }

      final created = await _worktreeRepository.createWorktree(
        projectPath: projectPath,
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
        );
      }
    }

    Log.w(
      "WorktreeService: failed to create worktree after 3 attempts for: $projectPath",
    );
    return WorktreeFallback(
      originalPath: projectPath,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  Future<String?> resolveHeadCommit({
    required String projectId,
  }) async {
    return await _worktreeRepository.resolveHeadCommit(
      projectPath: await _worktreeRepository.resolveProjectPath(projectId: projectId),
    );
  }

  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
  }) async {
    return await _worktreeRepository.checkWorktreeSafety(
      worktreePath: worktreePath,
    );
  }

  Future<bool> removeWorktree({
    required String pluginId,
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async {
    final projectPath = await _worktreeRepository.resolveProjectPath(projectId: projectId);
    if (!_worktreeRepository.isValidWorktreePath(
      projectPath: projectPath,
      worktreePath: worktreePath,
    )) {
      return false;
    }
    return await _worktreeRepository.removeWorktree(
      pluginId: pluginId,
      projectPath: projectPath,
      worktreePath: worktreePath,
      force: force,
    );
  }

  Future<bool> branchExists({
    required String projectId,
    required String branchName,
  }) async {
    return await _worktreeRepository.branchExists(
      projectPath: await _worktreeRepository.resolveProjectPath(projectId: projectId),
      branchName: branchName,
    );
  }
}
