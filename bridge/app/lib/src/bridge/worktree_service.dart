import "dart:io";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "foundation/process_runner.dart";
import "persistence/daos/projects_dao.dart";
import "persistence/daos/session_dao.dart";
import "persistence/tables/session_table.dart";

part "worktree_types.dart";
part "worktree_git_queries.dart";

typedef GitPathExistsChecker = bool Function({required String gitPath});

const _maxWorktreeCreationAttempts = 3;
const _branchPrefix = "session-";
const _worktreeDir = ".worktrees";

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class WorktreeService {
  final ProcessRunner _processRunner;
  final GitPathExistsChecker _gitPathExists;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;

  WorktreeService({
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    ProcessRunner? processRunner,
    GitPathExistsChecker? gitPathExists,
  }) : _processRunner = processRunner ?? ProcessRunner(),
       _gitPathExists = gitPathExists ?? _defaultGitPathExistsChecker,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao;

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

  // -------------------------------------------------------------------------
  // Orchestration
  // -------------------------------------------------------------------------

  /// Prepares a worktree for a new or child session.
  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
    ({String branchName, String worktreeName})? preferredBranchAndWorktreeName,
  }) async {
    if (parentSessionId != null) {
      final parentWorktree = await _sessionDao.getSession(sessionId: parentSessionId);
      if (parentWorktree case SessionDto(
        worktreePath: final worktreePath?,
        branchName: final branchName?,
        baseBranch: final parentBaseBranch,
        baseCommit: final parentBaseCommit,
      )) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: parentBaseBranch ?? "",
          baseCommit: parentBaseCommit ?? "",
        );
      }
    }

    if (!await isGitInitialized(projectPath: projectId)) {
      Log.w("WorktreeService: not a git repository: $projectId");
      return WorktreeFallback(originalPath: projectId, reason: "not a git repository");
    }

    if (!await hasAtLeastOneCommit(projectPath: projectId)) {
      Log.w("WorktreeService: repository has no commits: $projectId");
      return WorktreeFallback(originalPath: projectId, reason: "repository has no commits");
    }

    final baseBranchAndCommit = await resolveBaseBranchAndCommit(projectPath: projectId);
    if (baseBranchAndCommit == null) {
      Log.w("WorktreeService: failed to resolve base branch/commit for: $projectId");
      return WorktreeFallback(
        originalPath: projectId,
        reason: "failed to resolve base branch/commit",
      );
    }
    final baseBranch = baseBranchAndCommit.baseBranch;
    final baseCommit = baseBranchAndCommit.baseCommit;

    // 4.5. Try preferred branch name if provided.
    if (preferredBranchAndWorktreeName != null && parentSessionId == null) {
      final preferredBranch = preferredBranchAndWorktreeName.branchName;
      final preferredWorktree = preferredBranchAndWorktreeName.worktreeName;
      if (!_isSafeGitName(preferredBranch) || !_isSafeGitName(preferredWorktree)) {
        Log.w("WorktreeService: rejected unsafe preferred names: branch=$preferredBranch worktree=$preferredWorktree");
      } else {
        final suffix = await branchExists(projectPath: projectId, branchName: preferredBranch)
            ? "-${_randomSuffix()}"
            : "";
        final branchName = "$preferredBranch$suffix";
        final worktreeName = "$preferredWorktree$suffix";
        final worktreePath = "$projectId/$_worktreeDir/$worktreeName";
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
      }
    }

    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final counter = await _projectsDao.incrementAndGetWorktreeCounter(projectId: projectId);
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      final worktreePath = "$projectId/$_worktreeDir/$branchName";

      if (await branchExists(projectPath: projectId, branchName: branchName)) continue;

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
    }

    Log.w("WorktreeService: failed to create worktree after 3 attempts for: $projectId");
    return WorktreeFallback(
      originalPath: projectId,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  Future<({String baseBranch, String baseCommit})?> resolveBaseBranchAndCommit({
    required String projectPath,
  }) async {
    try {
      final storedBranch = await _projectsDao.getBaseBranch(projectId: projectPath);
      final String baseBranch;
      if (storedBranch != null && await branchExists(projectPath: projectPath, branchName: storedBranch)) {
        baseBranch = storedBranch;
      } else {
        baseBranch = await resolveDefaultBranch(projectPath: projectPath);
      }

      final revParseResult = await _runGit(
        projectPath: projectPath,
        arguments: ["rev-parse", baseBranch],
      );
      if (revParseResult.exitCode != 0) return null;

      final baseCommit = revParseResult.stdout.toString().trim();
      if (baseCommit.isEmpty) return null;

      return (baseBranch: baseBranch, baseCommit: baseCommit);
    } on Object {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Safety check
  // -------------------------------------------------------------------------

  /// Returns [WorktreeSafe] when the directory does not exist — a missing
  /// worktree is treated as already cleaned up.
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    if (!Directory(worktreePath).existsSync()) {
      return WorktreeSafe();
    }

    final issues = <SafetyIssue>[];

    final statusResult = await _processRunner.run(
      "git",
      ["status", "--porcelain"],
      workingDirectory: worktreePath,
    );
    if (statusResult.stdout.toString().trim().isNotEmpty) {
      issues.add(UnstagedChanges());
    }

    final headResult = await _processRunner.run(
      "git",
      ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: worktreePath,
    );
    final actualBranch = headResult.stdout.toString().trim();
    if (actualBranch != expectedBranch) {
      issues.add(BranchMismatch(expected: expectedBranch, actual: actualBranch));
    }

    if (issues.isEmpty) return WorktreeSafe();
    return WorktreeUnsafe(issues: issues);
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  Future<void> pruneWorktrees({required String projectPath}) async {
    await _runGit(projectPath: projectPath, arguments: const ["worktree", "prune"]);
  }

  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    if (!_isValidWorktreePath(projectPath: projectPath, worktreePath: worktreePath)) {
      return false;
    }
    await pruneWorktrees(projectPath: projectPath);
    final arguments = ["worktree", "remove", if (force) "--force", "--", worktreePath];
    final result = await _runGit(projectPath: projectPath, arguments: arguments);
    return result.exitCode == 0;
  }

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
      addArguments = ["worktree", "add", "--", worktreePath, branchName];
    } else {
      final startPoint = baseCommit ?? baseBranch;
      addArguments = ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint];
    }

    final addResult = await _runGit(projectPath: projectPath, arguments: addArguments);
    return addResult.exitCode == 0;
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
