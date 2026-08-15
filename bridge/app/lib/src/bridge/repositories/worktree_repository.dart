import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/tables/session_table.dart";
import "../api/filesystem_api.dart";
import "../api/git_cli_api.dart";
import "../runtime/plugin_runtime.dart";
import "../worktree_types.dart";
import "models/project_not_found_exception.dart";

const _worktreeDir = ".worktrees";

class WorktreeRepository({
    required final ProjectsDao _projectsDao,
    required final SessionDao _sessionDao,
    required final FilesystemApi _filesystemApi,
    required final GitCliApi _gitApi,
    required final PluginRuntime _runtime,
  }) {

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

  Future<bool> isInsideGitWorkTree({required String projectPath}) {
    return _gitApi.isInsideGitWorkTree(projectPath: projectPath);
  }

  Future<bool> initRepository({required String path}) {
    return _gitApi.initRepository(path: path);
  }

  Future<bool> stageAll({required String projectPath}) {
    return _gitApi.stageAll(projectPath: projectPath);
  }

  Future<bool> commitAll({required String projectPath, required String message}) {
    return _gitApi.commitAll(projectPath: projectPath, message: message);
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

  Future<String?> getCurrentBranchName({required String worktreePath}) async {
    final result = await _gitApi.getCurrentBranch(projectPath: worktreePath);
    return switch (result) {
      GitCurrentBranchNamed(:final branchName) => branchName,
      _ => null,
    };
  }

  Future<bool> isValidBranchName({required String branchName}) {
    return _gitApi.isValidBranchName(branchName: branchName);
  }

  Future<bool> hasUpstream({
    required String worktreePath,
    required String branchName,
  }) {
    return _gitApi.hasUpstream(projectPath: worktreePath, branchName: branchName);
  }

  Future<void> renameBranch({
    required String worktreePath,
    required String oldBranchName,
    required String newBranchName,
  }) {
    return _gitApi.renameBranch(
      projectPath: worktreePath,
      oldBranchName: oldBranchName,
      newBranchName: newBranchName,
    );
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

  bool worktreePathExists({required String worktreePath}) =>
      _filesystemApi.entityType(worktreePath) != FileSystemEntityType.notFound;

  /// The live directory for [projectId] — where git operations for the
  /// project must run. Unknown ids are rejected: an id is not a directory.
  Future<String> resolveProjectPath({required String projectId}) async {
    final path = await _projectsDao.getResolvedPath(projectId: projectId);
    if (path == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    return path;
  }

  /// Resolves the branch and commit that new worktrees should be based on.
  ///
  /// [projectId] keys the stored base-branch override; [projectPath] is the
  /// live directory the git queries run in. They differ once a project's
  /// folder has moved since it was first opened.
  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectId,
    required String projectPath,
    required bool refreshOrigin,
  }) async {
    try {
      final storedBranch = await _projectsDao.getBaseBranch(projectId: projectId);
      final baseBranch = await _resolveBaseBranch(
        projectPath: projectPath,
        storedBranch: storedBranch,
      );

      if (refreshOrigin) {
        try {
          await _gitApi.fetchOriginBranch(
            projectPath: projectPath,
            branchName: baseBranch,
          );
        } on ProcessException catch (error, stackTrace) {
          Log.w(
            "[WorktreeRepository] failed to refresh origin/$baseBranch; using existing refs",
            error,
            stackTrace,
          );
        } on TimeoutException catch (error, stackTrace) {
          Log.w(
            "[WorktreeRepository] failed to refresh origin/$baseBranch; using existing refs",
            error,
            stackTrace,
          );
        }
      }

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

  Future<String?> resolveHeadCommit({
    required String projectPath,
  }) async {
    try {
      final isGitRoot = await _gitApi.isGitInitialized(projectPath: projectPath);
      if (!isGitRoot && !await _gitApi.isInsideGitWorkTree(projectPath: projectPath)) {
        return null;
      }

      final headResult = await _gitApi.readHeadCommit(projectPath: projectPath);
      if (headResult.exitCode == 1) return null;
      if (headResult.exitCode != 0) {
        throw StateError("git rev-parse HEAD failed with exit ${headResult.exitCode}");
      }
      final commit = headResult.stdout.toString().trim();
      if (commit.isEmpty) {
        throw StateError("git rev-parse HEAD returned an empty commit");
      }

      return commit;
    } on Object catch (error, stackTrace) {
      Log.w("[WorktreeRepository] failed to capture Git snapshot for $projectPath", error, stackTrace);
      return null;
    }
  }

  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
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
    if (issues.isEmpty) {
      return WorktreeSafe();
    }
    return WorktreeUnsafe(issues: issues);
  }

  Future<bool> removeWorktree({
    required String pluginId,
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
      // The backend resolves the workspace by directory, so it gets the live
      // project path — the same root the worktree was just removed under.
      _runtime
          .useIfActive(
            pluginId: pluginId,
            operation: _WorktreeOperation.deleteWorkspace,
            body: (plugin, _) => plugin.deleteWorkspace(
              projectId: projectPath,
              worktreePath: worktreePath,
            ),
          )
          .catchError((Object error, StackTrace stackTrace) {
            Log.w("[Plugin] deleteWorkspace failed", error, stackTrace);
          })
          .ignore();
    }

    return removed;
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
    return await _gitApi.resolveDefaultBranch(projectPath: projectPath);
  }
}

enum _WorktreeOperation() { deleteWorkspace }
