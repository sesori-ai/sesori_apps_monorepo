import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "persistence/daos/projects_dao.dart";
import "persistence/daos/session_worktrees_dao.dart";

typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

typedef GitDirectoryExistsChecker = bool Function({required String gitDirectoryPath});

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class WorktreeResult {}

class WorktreeSuccess extends WorktreeResult {
  final String path;
  final String branchName;

  WorktreeSuccess({required this.path, required this.branchName});
}

class WorktreeFallback extends WorktreeResult {
  final String originalPath;
  final String reason;

  WorktreeFallback({required this.originalPath, required this.reason});
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class WorktreeService {
  static const _maxWorktreeCreationAttempts = 3;
  static const _branchPrefix = "session-";
  static const _worktreeDir = ".worktrees";

  final ProcessRunner _processRunner;
  final GitDirectoryExistsChecker _gitDirectoryExists;
  final ProjectsDao _projectsDao;
  final SessionWorktreesDao _sessionWorktreesDao;

  WorktreeService({
    required ProjectsDao projectsDao,
    required SessionWorktreesDao sessionWorktreesDao,
    ProcessRunner processRunner = Process.run,
    GitDirectoryExistsChecker? gitDirectoryExists,
  }) : _processRunner = processRunner,
       _gitDirectoryExists = gitDirectoryExists ?? _defaultGitDirectoryExistsChecker,
       _projectsDao = projectsDao,
       _sessionWorktreesDao = sessionWorktreesDao;

  // -------------------------------------------------------------------------
  // Git primitives
  // -------------------------------------------------------------------------

  Future<bool> isGitInitialized({required String projectPath}) async {
    return _gitDirectoryExists(gitDirectoryPath: "$projectPath/.git");
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

  Future<bool> branchExists({required String projectPath, required String branchName}) async {
    final result = await _runGit(
      projectPath: projectPath,
      arguments: ["branch", "--list", branchName],
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
      arguments: ["worktree", "add", worktreePath, "-b", branchName, baseBranch],
    );
  }

  // -------------------------------------------------------------------------
  // Orchestration
  // -------------------------------------------------------------------------

  /// Prepares a worktree for a new or child session.
  ///
  /// Returns [WorktreeSuccess] with the path and branch when a worktree is
  /// ready (either reused from a parent session or freshly created).
  /// Returns [WorktreeFallback] when the project is not git-initialised, has
  /// no commits, or every creation attempt fails.
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
  }) async {
    // 1. If a parent session exists, reuse its worktree.
    if (parentSessionId != null) {
      final parentWorktree = await _sessionWorktreesDao.getWorktreeForSession(
        sessionId: parentSessionId,
      );
      if (parentWorktree != null) {
        return WorktreeSuccess(
          path: parentWorktree.worktreePath,
          branchName: parentWorktree.branchName,
        );
      }
      // Parent not found (pre-feature session) — fall through to create new.
    }

    // 2. Guard: must be a git repository.
    if (!await isGitInitialized(projectPath: projectId)) {
      Log.w("WorktreeService: not a git repository: $projectId");
      return WorktreeFallback(
        originalPath: projectId,
        reason: "not a git repository",
      );
    }

    // 3. Guard: must have at least one commit.
    if (!await hasAtLeastOneCommit(projectPath: projectId)) {
      Log.w("WorktreeService: repository has no commits: $projectId");
      return WorktreeFallback(
        originalPath: projectId,
        reason: "repository has no commits",
      );
    }

    // 4. Resolve the base branch to create the worktree from.
    final storedBranch = await _projectsDao.getBaseBranch(projectId: projectId);
    final String baseBranch;
    if (storedBranch != null && await branchExists(projectPath: projectId, branchName: storedBranch)) {
      baseBranch = storedBranch;
    } else {
      baseBranch = await resolveDefaultBranch(projectPath: projectId);
    }

    // 5. Try to create a worktree, retrying on branch collision.
    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final counter = await _projectsDao.incrementAndGetWorktreeCounter(
        projectId: projectId,
      );
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      final worktreePath = "$projectId/$_worktreeDir/$branchName";

      // Skip if branch already exists (counter collision).
      if (await branchExists(projectPath: projectId, branchName: branchName)) {
        continue;
      }

      final result = await createWorktree(
        projectPath: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: baseBranch,
      );

      if (result.exitCode == 0) {
        return WorktreeSuccess(path: worktreePath, branchName: branchName);
      }
      // git command failed — try next counter value.
    }

    Log.w("WorktreeService: failed to create worktree after 3 attempts for: $projectId");
    return WorktreeFallback(
      originalPath: projectId,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  /// Records the association between a session and its worktree in the DB.
  Future<void> recordSessionWorktree({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) async {
    await _sessionWorktreesDao.insertMapping(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
    );
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

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

bool _defaultGitDirectoryExistsChecker({required String gitDirectoryPath}) {
  return Directory(gitDirectoryPath).existsSync();
}
