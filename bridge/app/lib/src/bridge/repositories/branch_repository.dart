import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../api/git_cli_api.dart";

class BranchRepository {
  final GitCliApi _gitCliApi;
  BranchRepository({required GitCliApi gitCliApi}) : _gitCliApi = gitCliApi;

  Future<BranchListResponse> listBranches({required String projectPath}) async {
    try {
      await _gitCliApi.fetchRemotes(workingDirectory: projectPath);
    } on Object catch (e) {
      Log.w("[BranchRepository] fetchRemotes failed (best-effort): $e");
    }

    final (remoteNames, branchResult, worktreeResult, currentBranchResult) = await (
      _listRemotes(projectPath: projectPath),
      _gitCliApi.listBranches(workingDirectory: projectPath),
      _gitCliApi.listWorktrees(workingDirectory: projectPath),
      _gitCliApi.getCurrentBranch(workingDirectory: projectPath),
    ).wait;
    final branches = _parseBranches(stdout: branchResult.stdout.toString(), remoteNames: remoteNames);
    final worktreeMap = _parseWorktrees(stdout: worktreeResult.stdout.toString());
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

  Future<Set<String>> _listRemotes({required String projectPath}) async {
    final result = await _gitCliApi.listRemotes(workingDirectory: projectPath);
    return result.stdout.toString().split("\n").map((line) => line.trim()).where((line) => line.isNotEmpty).toSet();
  }

  static List<BranchInfo> _parseBranches({
    required String stdout,
    required Set<String> remoteNames,
  }) {
    final lines = stdout.split("\n").where((line) => line.trim().isNotEmpty).toList();
    final localBranches = <String, int?>{};
    final remoteBranches = <String, int?>{};

    for (final line in lines) {
      if (line.contains("HEAD ->")) continue;
      final parts = line.trim().split(" ");
      if (parts.isEmpty) continue;
      final rawName = parts[0];
      if (!_isSelectableBranchRef(rawName: rawName, remoteNames: remoteNames)) continue;
      final timestamp = parts.length > 1 ? int.tryParse(parts[1]) : null;

      final remoteBranchName = _extractRemoteBranchName(rawName: rawName, remoteNames: remoteNames);
      if (remoteBranchName != null) {
        remoteBranches[remoteBranchName] = timestamp;
      } else {
        localBranches[rawName] = timestamp;
      }
    }

    final result = <BranchInfo>[];
    for (final entry in localBranches.entries) {
      result.add(
        BranchInfo(name: entry.key, isRemoteOnly: false, lastCommitTimestamp: entry.value, worktreePath: null),
      );
    }

    for (final entry in remoteBranches.entries) {
      if (!localBranches.containsKey(entry.key)) {
        result.add(
          BranchInfo(name: entry.key, isRemoteOnly: true, lastCommitTimestamp: entry.value, worktreePath: null),
        );
      }
    }
    return result;
  }

  static String? _extractRemoteBranchName({
    required String rawName,
    required Set<String> remoteNames,
  }) {
    final sortedRemoteNames = remoteNames.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final remoteName in sortedRemoteNames) {
      final prefix = "$remoteName/";
      if (!rawName.startsWith(prefix)) continue;
      final branchName = rawName.substring(prefix.length);
      if (branchName.isEmpty || branchName == "HEAD") return null;
      return branchName;
    }
    return null;
  }

  static bool _isSelectableBranchRef({
    required String rawName,
    required Set<String> remoteNames,
  }) {
    if (rawName.isEmpty || rawName == "HEAD" || rawName.startsWith("(")) {
      return false;
    }
    return !rawName.endsWith("/HEAD");
  }

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
