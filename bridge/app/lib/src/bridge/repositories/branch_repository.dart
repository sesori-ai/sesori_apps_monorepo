import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../api/git_cli_api.dart";

class BranchRepository {
  final GitCliApi _gitCliApi;

  BranchRepository({required GitCliApi gitCliApi}) : _gitCliApi = gitCliApi;

  Future<BranchListResponse> listBranches({required String projectPath}) async {
    // Best-effort fetch — ignore errors
    try {
      await _gitCliApi.fetchRemotes(workingDirectory: projectPath);
    } on Object catch (e) {
      Log.w("[BranchRepository] fetchRemotes failed (best-effort): $e");
    }

    final branchResult = await _gitCliApi.listBranches(workingDirectory: projectPath);
    final branches = _parseBranches(stdout: branchResult.stdout.toString());

    final worktreeResult = await _gitCliApi.listWorktrees(workingDirectory: projectPath);
    final worktreeMap = _parseWorktrees(stdout: worktreeResult.stdout.toString());

    final currentBranchResult = await _gitCliApi.getCurrentBranch(workingDirectory: projectPath);
    final currentBranch = currentBranchResult.stdout.toString().trim();

    final enrichedBranches = branches.map((branch) {
      final worktreePath = worktreeMap[branch.name];
      if (worktreePath == null) return branch;
      return branch.copyWith(worktreePath: worktreePath);
    }).toList();

    return BranchListResponse(
      branches: enrichedBranches,
      currentBranch: currentBranch.isEmpty ? null : currentBranch,
    );
  }

  Future<String?> getWorktreeForBranch({
    required String projectPath,
    required String branchName,
  }) async {
    final result = await _gitCliApi.listWorktrees(workingDirectory: projectPath);
    final worktreeMap = _parseWorktrees(stdout: result.stdout.toString());
    return worktreeMap[branchName];
  }

  Future<bool> addExistingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String branchName,
  }) async {
    final result = await _gitCliApi.addExistingBranchWorktree(
      workingDirectory: workingDirectory,
      worktreePath: worktreePath,
      branchName: branchName,
    );
    return result.exitCode == 0;
  }

  Future<bool> createTrackingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String localBranchName,
    required String remoteBranch,
  }) async {
    final result = await _gitCliApi.createTrackingBranchWorktree(
      workingDirectory: workingDirectory,
      worktreePath: worktreePath,
      localBranchName: localBranchName,
      remoteBranch: remoteBranch,
    );
    return result.exitCode == 0;
  }

  Future<bool> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) async {
    final result = await _gitCliApi.createWorktree(
      workingDirectory: projectPath,
      worktreePath: worktreePath,
      branchName: branchName,
      startPoint: startPoint,
    );
    return result.exitCode == 0;
  }

  Future<bool> branchExistsLocally({
    required String projectPath,
    required String branchName,
  }) async {
    final result = await _gitCliApi.branchExistsLocally(
      workingDirectory: projectPath,
      branchName: branchName,
    );
    return result.stdout.toString().trim().isNotEmpty;
  }

  Future<({String ref, String commit})?> resolveStartPointForBranch({
    required String projectPath,
    required String branchName,
  }) async {
    final localResult = await _gitCliApi.revParse(
      workingDirectory: projectPath,
      ref: branchName,
    );
    if (localResult.exitCode != 0) {
      return _resolveRemoteOnlyStartPoint(
        projectPath: projectPath,
        branchName: branchName,
      );
    }

    final localCommit = localResult.stdout.toString().trim();
    if (localCommit.isEmpty) return null;

    final originRef = "origin/$branchName";
    final originResult = await _gitCliApi.revParse(
      workingDirectory: projectPath,
      ref: originRef,
    );
    if (originResult.exitCode != 0) {
      return (ref: branchName, commit: localCommit);
    }

    final originCommit = originResult.stdout.toString().trim();
    if (originCommit.isEmpty || originCommit == localCommit) {
      return (ref: branchName, commit: localCommit);
    }

    final mergeBaseResult = await _gitCliApi.isAncestor(
      workingDirectory: projectPath,
      ancestorRef: originCommit,
      descendantRef: localCommit,
    );
    if (mergeBaseResult.exitCode == 0) {
      return (ref: branchName, commit: localCommit);
    }

    return (ref: originRef, commit: originCommit);
  }

  Future<({String ref, String commit})?> _resolveRemoteOnlyStartPoint({
    required String projectPath,
    required String branchName,
  }) async {
    final originRef = "origin/$branchName";
    final originResult = await _gitCliApi.revParse(
      workingDirectory: projectPath,
      ref: originRef,
    );
    if (originResult.exitCode != 0) {
      return null;
    }

    final originCommit = originResult.stdout.toString().trim();
    if (originCommit.isEmpty) {
      return null;
    }

    return (ref: originRef, commit: originCommit);
  }

  /// Parses `git branch -a --sort=-committerdate --format='%(refname:short) %(committerdate:unix)'`
  /// into a deduplicated list of [BranchInfo].
  static List<BranchInfo> _parseBranches({required String stdout}) {
    final lines = stdout.split("\n").where((l) => l.trim().isNotEmpty).toList();

    // Collect raw entries: name → (timestamp, isRemote)
    final localBranches = <String, int?>{};
    final remoteBranches = <String, int?>{};

    for (final line in lines) {
      if (line.contains("HEAD ->")) continue;

      final parts = line.trim().split(" ");
      if (parts.isEmpty) continue;

      final rawName = parts[0];
      final timestamp = parts.length > 1 ? int.tryParse(parts[1]) : null;

      if (rawName.startsWith("origin/")) {
        final stripped = rawName.substring("origin/".length);
        remoteBranches[stripped] = timestamp;
      } else {
        localBranches[rawName] = timestamp;
      }
    }

    final result = <BranchInfo>[];

    // Local branches first — these win over remotes
    for (final entry in localBranches.entries) {
      result.add(
        BranchInfo(
          name: entry.key,
          isRemoteOnly: false,
          lastCommitTimestamp: entry.value,
          worktreePath: null,
        ),
      );
    }

    // Remote-only branches (not present locally)
    for (final entry in remoteBranches.entries) {
      if (!localBranches.containsKey(entry.key)) {
        result.add(
          BranchInfo(
            name: entry.key,
            isRemoteOnly: true,
            lastCommitTimestamp: entry.value,
            worktreePath: null,
          ),
        );
      }
    }

    return result;
  }

  /// Parses `git worktree list --porcelain` into a map of branchName → worktreePath.
  static Map<String, String> _parseWorktrees({required String stdout}) {
    final worktreeMap = <String, String>{};
    final blocks = stdout.split("\n\n");

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;

      String? path;
      String? branchName;

      for (final line in block.split("\n")) {
        if (line.startsWith("worktree ")) {
          path = line.substring("worktree ".length);
        } else if (line.startsWith("branch refs/heads/")) {
          branchName = line.substring("branch refs/heads/".length);
        }
      }

      if (path != null && branchName != null) {
        worktreeMap[branchName] = path;
      }
    }

    return worktreeMap;
  }
}
