import "dart:io";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "foundation/process_runner.dart";
import "persistence/daos/projects_dao.dart";
import "persistence/daos/session_dao.dart";
import "persistence/tables/session_table.dart";
import "repositories/branch_repository.dart";

part "worktree_types.dart";
part "worktree_git_queries.dart";
part "worktree_safety.dart";
part "worktree_lifecycle.dart";
part "worktree_branch_preparation.dart";

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
  final BranchRepository _branchRepository;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;

  WorktreeService({
    required BranchRepository branchRepository,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required ProcessRunner processRunner,
    required GitPathExistsChecker gitPathExists,
  }) : _branchRepository = branchRepository,
       _processRunner = processRunner,
       _gitPathExists = gitPathExists,
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
          isDedicated: true,
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
    final startPoint = baseBranchAndCommit.startPoint;

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
          baseBranch: startPoint,
        );
        if (result.exitCode == 0) {
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
      final counter = await _projectsDao.incrementAndGetWorktreeCounter(projectId: projectId);
      final branchName = "$_branchPrefix${counter.toString().padLeft(3, '0')}";
      final worktreePath = "$projectId/$_worktreeDir/$branchName";

      if (await branchExists(projectPath: projectId, branchName: branchName)) continue;

      final result = await createWorktree(
        projectPath: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: startPoint,
      );

      if (result.exitCode == 0) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
          isDedicated: true,
        );
      }
    }

    Log.w("WorktreeService: failed to create worktree after 3 attempts for: $projectId");
    return WorktreeFallback(
      originalPath: projectId,
      reason: "failed to create worktree after 3 attempts",
    );
  }

  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
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

      final localCommit = revParseResult.stdout.toString().trim();
      if (localCommit.isEmpty) return null;

      final startPointResult = await resolveStartPointForBranch(
        projectPath: projectPath,
        baseBranch: baseBranch,
        localCommit: localCommit,
      );

      return (
        baseBranch: startPointResult.ref,
        baseCommit: startPointResult.commit,
        startPoint: startPointResult.ref,
      );
    } on Object {
      return null;
    }
  }
}
