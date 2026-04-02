part of "worktree_service.dart";

extension WorktreeGitQueries on WorktreeService {
  // -------------------------------------------------------------------------
  // Git primitives
  // -------------------------------------------------------------------------

  Future<bool> isGitInitialized({required String projectPath}) async {
    return _gitPathExists(gitPath: "$projectPath/.git");
  }

  Future<bool> hasAtLeastOneCommit({required String projectPath}) async {
    final result = await _runGit(
      projectPath: projectPath,
      arguments: const ["rev-parse", "HEAD"],
    );
    return result.exitCode == 0;
  }

  Future<String> resolveDefaultBranch({required String projectPath}) async {
    final originHeadResult = await _runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "refs/remotes/origin/HEAD"],
    );
    final originHeadBranch = _extractBranchName(
      output: originHeadResult.stdout,
      prefix: "refs/remotes/origin/",
    );
    if (originHeadResult.exitCode == 0 && originHeadBranch != null) {
      return originHeadBranch;
    }

    final localHeadResult = await _runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "HEAD"],
    );
    final localHeadBranch = _extractBranchName(
      output: localHeadResult.stdout,
      prefix: "refs/heads/",
    );
    if (localHeadResult.exitCode == 0 && localHeadBranch != null) {
      return localHeadBranch;
    }

    final configuredDefaultBranchResult = await _runGit(
      projectPath: projectPath,
      arguments: const ["config", "init.defaultBranch"],
    );
    final configuredDefaultBranch = configuredDefaultBranchResult.stdout.toString().trim();
    if (configuredDefaultBranchResult.exitCode == 0 && configuredDefaultBranch.isNotEmpty) {
      return configuredDefaultBranch;
    }

    return "main";
  }

  Future<bool> branchExists({
    required String projectPath,
    required String branchName,
  }) async {
    final result = await _runGit(
      projectPath: projectPath,
      arguments: ["branch", "--list", "--", branchName],
    );
    return result.stdout.toString().trim().isNotEmpty;
  }

  Future<ProcessResult> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
  }) {
    return _runGit(
      projectPath: projectPath,
      arguments: ["worktree", "add", "-b", branchName, "--", worktreePath, baseBranch],
    );
  }

  Future<ProcessResult> _runGit({
    required String projectPath,
    required List<String> arguments,
  }) {
    return _processRunner("git", arguments, workingDirectory: projectPath);
  }

  String? _extractBranchName({required Object? output, required String prefix}) {
    final trimmedOutput = output.toString().trim();
    if (!trimmedOutput.startsWith(prefix)) {
      return null;
    }
    final branchName = trimmedOutput.substring(prefix.length).trim();
    if (branchName.isEmpty) {
      return null;
    }
    return branchName;
  }
}
