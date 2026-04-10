part of "worktree_service.dart";

extension WorktreeBranchPreparation on WorktreeService {
  Future<WorktreeResult> prepareWorktreeForBranch({
    required WorktreeMode mode,
    required String? selectedBranch,
    required String projectPath,
    required String sessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    switch (mode) {
      case WorktreeMode.none:
        return WorktreeFallback(originalPath: projectPath, reason: "worktree mode is none");
      case WorktreeMode.stayOnBranch:
        return _prepareExistingBranchWorktree(
          projectPath: projectPath,
          selectedBranch: selectedBranch,
        );
      case WorktreeMode.newBranch:
        return _prepareNewBranchWorktree(
          projectPath: projectPath,
          selectedBranch: selectedBranch,
          sessionId: sessionId,
          preferredBranchAndWorktreeName: preferredBranchAndWorktreeName,
        );
    }
  }

  Future<WorktreeResult> _prepareExistingBranchWorktree({
    required String projectPath,
    required String? selectedBranch,
  }) async {
    if (!await _isRepositoryReady(projectPath: projectPath)) {
      return _repositoryUnavailableFallback(projectPath: projectPath);
    }
    if (selectedBranch == null || selectedBranch.isEmpty) {
      return WorktreeFallback(originalPath: projectPath, reason: "branch selection is required");
    }

    final startPoint = await _branchRepository.resolveStartPointForBranch(
      projectPath: projectPath,
      branchName: selectedBranch,
    );
    if (startPoint == null) {
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "failed to resolve selected branch",
      );
    }

    final existingPath = await _branchRepository.getWorktreeForBranch(
      projectPath: projectPath,
      branchName: selectedBranch,
    );
    if (existingPath != null) {
      return WorktreeSuccess(
        path: existingPath,
        branchName: selectedBranch,
        baseBranch: startPoint.ref,
        baseCommit: startPoint.commit,
      );
    }

    final worktreePath = "$projectPath/$_worktreeDir/${_branchWorktreeName(branchName: selectedBranch)}";
    final branchExistsLocally = await _branchRepository.branchExistsLocally(
      projectPath: projectPath,
      branchName: selectedBranch,
    );
    final success = branchExistsLocally
        ? await _branchRepository.addExistingBranchWorktree(
            workingDirectory: projectPath,
            worktreePath: worktreePath,
            branchName: selectedBranch,
          )
        : await _branchRepository.createTrackingBranchWorktree(
            workingDirectory: projectPath,
            worktreePath: worktreePath,
            localBranchName: selectedBranch,
            remoteBranch: startPoint.ref,
          );
    if (!success) {
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "failed to create worktree for selected branch",
      );
    }

    return WorktreeSuccess(
      path: worktreePath,
      branchName: selectedBranch,
      baseBranch: startPoint.ref,
      baseCommit: startPoint.commit,
    );
  }

  Future<WorktreeResult> _prepareNewBranchWorktree({
    required String projectPath,
    required String? selectedBranch,
    required String sessionId,
    required ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    if (!await _isRepositoryReady(projectPath: projectPath)) {
      return _repositoryUnavailableFallback(projectPath: projectPath);
    }
    if (selectedBranch == null || selectedBranch.isEmpty) {
      return WorktreeFallback(originalPath: projectPath, reason: "branch selection is required");
    }

    final startPoint = await _branchRepository.resolveStartPointForBranch(
      projectPath: projectPath,
      branchName: selectedBranch,
    );
    if (startPoint == null) {
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "failed to resolve selected branch",
      );
    }

    final preferredResult = await _tryCreatePreferredBranchWorktree(
      projectPath: projectPath,
      startPoint: startPoint.ref,
      baseBranch: startPoint.ref,
      baseCommit: startPoint.commit,
      preferredBranchAndWorktreeName: preferredBranchAndWorktreeName,
    );
    if (preferredResult != null) {
      return preferredResult;
    }

    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final counter = await _projectsDao.incrementAndGetWorktreeCounter(projectId: projectPath);
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      if (await _branchRepository.branchExistsLocally(projectPath: projectPath, branchName: branchName)) {
        continue;
      }

      final worktreePath = "$projectPath/$_worktreeDir/$branchName";
      final success = await _branchRepository.createWorktree(
        projectPath: projectPath,
        worktreePath: worktreePath,
        branchName: branchName,
        startPoint: startPoint.ref,
      );
      if (success) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: startPoint.ref,
          baseCommit: startPoint.commit,
        );
      }
    }

    return WorktreeFallback(
      originalPath: projectPath,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  Future<WorktreeSuccess?> _tryCreatePreferredBranchWorktree({
    required String projectPath,
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
    if (!WorktreeService._isSafeGitName(preferredBranch) || !WorktreeService._isSafeGitName(preferredWorktree)) {
      Log.w(
        "WorktreeService: rejected unsafe preferred names: branch=$preferredBranch worktree=$preferredWorktree",
      );
      return null;
    }

    final suffix =
        await _branchRepository.branchExistsLocally(
          projectPath: projectPath,
          branchName: preferredBranch,
        )
        ? "-${WorktreeService._randomSuffix()}"
        : "";
    final branchName = "$preferredBranch$suffix";
    final worktreeName = "$preferredWorktree$suffix";
    final worktreePath = "$projectPath/$_worktreeDir/$worktreeName";
    final success = await _branchRepository.createWorktree(
      projectPath: projectPath,
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
    );
  }

  Future<bool> _isRepositoryReady({required String projectPath}) async {
    return await isGitInitialized(projectPath: projectPath) && await hasAtLeastOneCommit(projectPath: projectPath);
  }

  WorktreeFallback _repositoryUnavailableFallback({required String projectPath}) {
    if (!_gitPathExists(gitPath: "$projectPath/.git")) {
      Log.w("WorktreeService: not a git repository: $projectPath");
      return WorktreeFallback(originalPath: projectPath, reason: "not a git repository");
    }
    Log.w("WorktreeService: repository has no commits: $projectPath");
    return WorktreeFallback(originalPath: projectPath, reason: "repository has no commits");
  }

  String _branchWorktreeName({required String branchName}) {
    final sanitized = branchName.replaceAll("/", "__").replaceAll(RegExp("[^A-Za-z0-9._-]"), "-");
    return sanitized.isEmpty ? "branch-${WorktreeService._randomSuffix()}" : sanitized;
  }
}
