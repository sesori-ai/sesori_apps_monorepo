import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, Log;

import "../api/git_cli_api.dart";
import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "../worktree_types.dart";

const _worktreeDir = ".worktrees";

class WorktreeRepository {
  final GitCliApi _gitApi;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final BridgePluginApi _plugin;

  WorktreeRepository({
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required GitCliApi gitApi,
    required BridgePluginApi plugin,
  }) : _gitApi = gitApi,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _plugin = plugin;

  Future<({String path, String branchName, String baseBranch, String baseCommit})?> getParentWorktree({
    required String parentSessionId,
  }) async {
    final parentWorktree = await _sessionDao.getSession(sessionId: parentSessionId);
    if (parentWorktree case SessionDto(
      worktreePath: final worktreePath?,
      branchName: final branchName?,
      baseBranch: final parentBaseBranch,
      baseCommit: final parentBaseCommit,
    )) {
      return (
        path: worktreePath,
        branchName: branchName,
        baseBranch: parentBaseBranch ?? "",
        baseCommit: parentBaseCommit ?? "",
      );
    }
    return null;
  }

  Future<bool> isGitInitialized({required String projectPath}) {
    return _gitApi.isGitInitialized(projectPath: projectPath);
  }

  Future<bool> hasAtLeastOneCommit({required String projectPath}) {
    return _gitApi.hasAtLeastOneCommit(projectPath: projectPath);
  }

  Future<bool> branchExists({
    required String projectPath,
    required String branchName,
  }) {
    return _gitApi.branchExists(projectPath: projectPath, branchName: branchName);
  }

  Future<bool> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) {
    return _gitApi.createWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      branchName: branchName,
      startPoint: startPoint,
    );
  }

  Future<int> incrementAndGetWorktreeCounter({required String projectId}) {
    return _projectsDao.incrementAndGetWorktreeCounter(projectId: projectId);
  }

  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectPath,
  }) async {
    try {
      final storedBranch = await _projectsDao.getBaseBranch(projectId: projectPath);
      final baseBranch = await _resolveBaseBranch(
        projectPath: projectPath,
        storedBranch: storedBranch,
      );

      final localCommit = await _gitApi.resolveCommit(
        projectPath: projectPath,
        ref: baseBranch,
      );
      if (localCommit == null) {
        return null;
      }

      final startPointResult = await _gitApi.resolveStartPointForBranch(
        projectPath: projectPath,
        baseBranch: baseBranch,
        localCommit: localCommit,
      );

      return (
        baseBranch: startPointResult.ref,
        baseCommit: startPointResult.commit,
        startPoint: startPointResult.ref,
      );
    } on Object catch (error) {
      Log.w("[WorktreeRepository] failed to resolve base branch/commit for $projectPath: $error");
      return null;
    }
  }

  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    final snapshot = await _gitApi.inspectWorktreeSafety(
      worktreePath: worktreePath,
    );

    if (!snapshot.worktreeExists) {
      return WorktreeSafe();
    }

    final issues = <SafetyIssue>[];
    if (snapshot.hasUnstagedChanges) {
      issues.add(UnstagedChanges());
    }
    if (snapshot.actualBranch != expectedBranch) {
      issues.add(
        BranchMismatch(expected: expectedBranch, actual: snapshot.actualBranch),
      );
    }

    if (issues.isEmpty) {
      return WorktreeSafe();
    }
    return WorktreeUnsafe(issues: issues);
  }

  Future<bool> removeWorktree({
    required String projectId,
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    await _gitApi.pruneWorktrees(
      projectPath: projectPath,
    );
    final removed = await _gitApi.removeWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      force: force,
    );

    if (removed) {
      _plugin
          .deleteWorkspace(
            projectId: projectPath,
            worktreePath: worktreePath,
          )
          .catchError(
            (Object err) => Log.w("[Plugin] deleteWorkspace failed $err"),
          )
          .ignore();
    }

    return removed;
  }

  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    return _gitApi.deleteBranch(
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
    return _gitApi.restoreWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
    );
  }

  bool isValidWorktreePath({required String projectPath, required String worktreePath}) {
    final expectedPrefix = "$projectPath/$_worktreeDir/";
    return worktreePath.startsWith(expectedPrefix);
  }

  Future<String> _resolveBaseBranch({
    required String projectPath,
    required String? storedBranch,
  }) async {
    if (storedBranch != null && await _gitApi.branchExists(projectPath: projectPath, branchName: storedBranch)) {
      return storedBranch;
    }
    return _gitApi.resolveDefaultBranch(projectPath: projectPath);
  }
}
