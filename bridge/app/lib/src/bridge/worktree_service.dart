import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "persistence/daos/projects_dao.dart";
import "persistence/daos/session_dao.dart";

typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

typedef GitPathExistsChecker = bool Function({required String gitPath});

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class WorktreeSafetyResult {}

class WorktreeSafe extends WorktreeSafetyResult {}

class WorktreeUnsafe extends WorktreeSafetyResult {
  final List<SafetyIssue> issues;
  WorktreeUnsafe({required this.issues});
}

sealed class SafetyIssue {}

class UnstagedChanges extends SafetyIssue {}

class BranchMismatch extends SafetyIssue {
  final String expected;
  final String actual;
  BranchMismatch({required this.expected, required this.actual});
}

class WorktreeNotFound extends SafetyIssue {}

sealed class WorktreeResult {}

class WorktreeSuccess extends WorktreeResult {
  final String path;
  final String branchName;
  final String baseBranch;
  final String baseCommit;

  WorktreeSuccess({
    required this.path,
    required this.branchName,
    required this.baseBranch,
    required this.baseCommit,
  });
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
  final GitPathExistsChecker _gitPathExists;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;

  WorktreeService({
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    ProcessRunner processRunner = Process.run,
    GitPathExistsChecker? gitPathExists,
  }) : _processRunner = processRunner,
       _gitPathExists = gitPathExists ?? _defaultGitPathExistsChecker,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao;

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
      final parentWorktree = await _sessionDao.getSession(
        sessionId: parentSessionId,
      );
      if (parentWorktree?.worktreePath != null && parentWorktree?.branchName != null) {
        return WorktreeSuccess(
          path: parentWorktree!.worktreePath!,
          branchName: parentWorktree.branchName!,
          baseBranch: parentWorktree.baseBranch ?? "",
          baseCommit: parentWorktree.baseCommit ?? "",
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

    // 5. Capture the base commit SHA before creating the worktree.
    final revParseResult = await _runGit(
      projectPath: projectId,
      arguments: ["rev-parse", baseBranch],
    );
    final baseCommit = revParseResult.stdout.toString().trim();

    // 6. Try to create a worktree, retrying on branch collision.
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
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
        );
      }
      // git command failed — try next counter value.
    }

    Log.w("WorktreeService: failed to create worktree after 3 attempts for: $projectId");
    return WorktreeFallback(
      originalPath: projectId,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  /// Checks whether a worktree is safe to resume (no unstaged changes, correct branch).
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    if (!Directory(worktreePath).existsSync()) {
      return WorktreeUnsafe(issues: [WorktreeNotFound()]);
    }

    final issues = <SafetyIssue>[];

    final statusResult = await _processRunner(
      "git",
      ["status", "--porcelain"],
      workingDirectory: worktreePath,
    );
    if (statusResult.stdout.toString().trim().isNotEmpty) {
      issues.add(UnstagedChanges());
    }

    final headResult = await _processRunner(
      "git",
      ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: worktreePath,
    );
    final actualBranch = headResult.stdout.toString().trim();
    if (actualBranch != expectedBranch) {
      issues.add(BranchMismatch(expected: expectedBranch, actual: actualBranch));
    }

    if (issues.isEmpty) {
      return WorktreeSafe();
    }
    return WorktreeUnsafe(issues: issues);
  }

  /// Prunes stale worktree administrative files (best-effort, fire-and-forget).
  Future<void> pruneWorktrees({required String projectPath}) async {
    await _runGit(
      projectPath: projectPath,
      arguments: const ["worktree", "prune"],
    );
  }

  /// Removes a worktree. Returns true on success, false on failure.
  ///
  /// Calls [pruneWorktrees] first to clean up stale entries, then runs
  /// `git worktree remove [--force] <worktreePath>`.
  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    if (!_isValidWorktreePath(projectPath: projectPath, worktreePath: worktreePath)) {
      return false;
    }

    await pruneWorktrees(projectPath: projectPath);

    final arguments = [
      "worktree",
      "remove",
      if (force) "--force",
      "--",
      worktreePath,
    ];
    final result = await _runGit(
      projectPath: projectPath,
      arguments: arguments,
    );
    return result.exitCode == 0;
  }

  /// Deletes a branch. Returns true on success, false on failure.
  ///
  /// Uses `-D` (force) or `-d` (safe) depending on [force].
  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    final result = await _runGit(
      projectPath: projectPath,
      arguments: ["branch", force ? "-D" : "-d", "--", branchName],
    );
    return result.exitCode == 0;
  }

  /// Restores (or creates) a worktree at [worktreePath] on [branchName].
  ///
  /// If [branchName] already exists, runs `git worktree add <path> <branch>`.
  /// Otherwise creates a new branch from [baseCommit] (or [baseBranch] if
  /// [baseCommit] is null) via `git worktree add <path> -b <branch> <ref>`.
  ///
  /// Returns true on success, false on failure.
  Future<bool> restoreWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    if (!_isValidWorktreePath(projectPath: projectPath, worktreePath: worktreePath)) {
      return false;
    }

    final verifyResult = await _runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", "--", "refs/heads/$branchName"],
    );

    final List<String> addArguments;
    if (verifyResult.exitCode == 0) {
      // Branch exists — check it out directly.
      addArguments = ["worktree", "add", "--", worktreePath, branchName];
    } else {
      // Branch does not exist — create from baseCommit (preferred) or baseBranch.
      final startPoint = baseCommit ?? baseBranch;
      addArguments = ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint];
    }

    final addResult = await _runGit(
      projectPath: projectPath,
      arguments: addArguments,
    );
    return addResult.exitCode == 0;
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

  /// Validates that [worktreePath] is under `<projectPath>/.worktrees/` to
  /// prevent path-traversal attacks via stored database values.
  bool _isValidWorktreePath({
    required String projectPath,
    required String worktreePath,
  }) {
    final expectedPrefix = "$projectPath/.worktrees/";
    return worktreePath.startsWith(expectedPrefix);
  }
}

bool _defaultGitPathExistsChecker({required String gitPath}) {
  return FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound;
}
