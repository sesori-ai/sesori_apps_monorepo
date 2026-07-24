import "dart:io" show FileSystemException;
import "dart:math" show max;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart" show SessionDao, SessionUnseenRow;
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../../repositories/project_catalog_identity_calculator.dart";
import "../api/filesystem_api.dart";
import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "mappers/project_catalog_mapper.dart";
import "models/project_activity.dart";
import "models/project_not_found_exception.dart";
import "session_unseen_calculator.dart";

/// Owns the bridge's aggregate project catalog and local project operations.
class ProjectRepository {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();
  static const ProjectCatalogMapper _projectCatalogMapper = ProjectCatalogMapper();

  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _unseenCalculator;
  final FilesystemApi _filesystemApi;
  final GitCliApi _gitCliApi;
  final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator;

  ProjectRepository({
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionUnseenCalculator unseenCalculator,
    required FilesystemApi filesystemApi,
    required GitCliApi gitCliApi,
    required ProjectCatalogIdentityCalculator projectCatalogIdentityCalculator,
  }) : _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _unseenCalculator = unseenCalculator,
       _filesystemApi = filesystemApi,
       _gitCliApi = gitCliApi,
       _projectCatalogIdentityCalculator = projectCatalogIdentityCalculator;

  Future<List<Project>> getProjects() async {
    final rows = await _projectsDao.getCatalogProjects();
    final unseenById = await unseenByProjectId(
      projectIds: [for (final row in rows) row.projectId],
    );
    final worktreeCapabilities = await Future.wait([
      for (final row in rows) _supportsDedicatedWorktrees(path: row.path),
    ]);
    return [
      for (final (index, row) in rows.indexed)
        _projectCatalogMapper.map(
          row: row,
          hasUnseenChanges: unseenById[row.projectId] ?? false,
          directoryMissing: false,
          supportsDedicatedWorktrees: worktreeCapabilities[index],
        ),
    ];
  }

  /// Whether [projectId] has at least one non-archived session with unseen
  /// changes. Child activity remains owned by its root and does not contribute
  /// independently to the project aggregate.
  Future<bool> projectHasUnseenChanges({required String projectId}) async {
    final rows = await _sessionDao.getUnseenRowsForProject(projectId: projectId);
    return _anyUnseen(rows);
  }

  /// Batch variant of [projectHasUnseenChanges] for the `/projects` list. Reads
  /// every project's sessions in a single query to avoid N+1.
  Future<Map<String, bool>> unseenByProjectId({required List<String> projectIds}) async {
    final rowsByProject = await _sessionDao.getUnseenRowsForProjects(projectIds: projectIds);
    return {
      for (final id in projectIds) id: _anyUnseen(rowsByProject[id] ?? const []),
    };
  }

  bool _anyUnseen(List<SessionUnseenRow> rows) {
    for (final row in rows) {
      if (row.parentSessionId != null) continue;
      if (row.archivedAt != null) continue;
      if (_unseenCalculator.isUnseen(
        activity: row.activityAt,
        userMessage: row.userMessageAt,
        seen: row.seenAt,
      )) {
        return true;
      }
    }
    return false;
  }

  Future<Project> getProject({required String projectId}) async {
    final row = await _projectsDao.getProject(projectId: projectId);
    if (row == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    return _projectCatalogMapper.map(
      row: row,
      hasUnseenChanges: await projectHasUnseenChanges(projectId: projectId),
      directoryMissing: false,
      supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: row.path),
    );
  }

  /// Resolves [path] locally, retaining any durable identity already recorded
  /// for the same canonical directory.
  Future<Project> resolveProjectOpenTarget({required String path}) async {
    final canonical = normalizeProjectDirectory(directory: path);
    final storedProjects = await _projectsDao.getAllProjects();
    final stored = _projectCatalogIdentityCalculator.calculate(
      projectsById: {for (final project in storedProjects) project.projectId: project},
      projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
        projects: storedProjects,
      ),
      preferredProjectId: canonical,
      observedPath: canonical,
    );
    final base = p.basename(canonical);
    return Project(
      id: stored?.projectId ?? canonical,
      name: stored?.displayName ?? (base.isEmpty ? canonical : base),
      path: canonical,
      time: null,
      supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: canonical),
    );
  }

  /// Rechecks the opened project's canonical identity, merges [observedAt]
  /// monotonically with that row's activity, persists it, and unhides it in one
  /// transaction. A concurrent catalog import may have claimed
  /// the resolved project's path after [resolveProjectOpenTarget] took its snapshot.
  Future<
    ({
      ProjectActivity committedActivity,
      Project committedProject,
      bool updatedAtAdvanced,
    })
  >
  persistOpenedProject({
    required Project target,
    required int observedAt,
  }) {
    return _projectsDao.transaction(() async {
      final storedProjects = await _projectsDao.getAllProjects();
      final existing = _projectCatalogIdentityCalculator.calculate(
        projectsById: {
          for (final project in storedProjects) project.projectId: project,
        },
        projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
          projects: storedProjects,
        ),
        preferredProjectId: target.id,
        observedPath: target.path,
      );
      final committedProject = existing == null ? target : target.copyWith(id: existing.projectId);
      final currentActivity = _mapActivity(existing);
      final committedActivity = ProjectActivity(
        createdAt: currentActivity?.createdAt ?? observedAt,
        updatedAt: max(currentActivity?.updatedAt ?? observedAt, observedAt),
      );
      await _projectsDao.recordOpenedProject(
        projectId: committedProject.id,
        path: committedProject.path,
        displayName: null,
        createdAt: committedActivity.createdAt,
        updatedAt: committedActivity.updatedAt,
      );
      return (
        committedActivity: committedActivity,
        committedProject: committedProject,
        updatedAtAdvanced: currentActivity == null || committedActivity.updatedAt > currentActivity.updatedAt,
      );
    });
  }

  Future<Project> mapOpenedProject({
    required Project project,
    required ProjectActivity committedActivity,
  }) async {
    return project.copyWith(
      time: _activityToTime(committedActivity),
      hasUnseenChanges: await projectHasUnseenChanges(projectId: project.id),
      directoryMissing: _directoryMissing(project.path),
    );
  }

  Future<Project> renameProject({required String projectId, required String name}) async {
    final existing = await _projectsDao.getProject(projectId: projectId);
    if (existing == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    await _projectsDao.setDisplayName(
      projectId: projectId,
      displayName: name,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final row = (await _projectsDao.getProject(projectId: projectId))!;
    return _projectCatalogMapper.map(
      row: row,
      hasUnseenChanges: await projectHasUnseenChanges(projectId: projectId),
      directoryMissing: _directoryMissing(row.path),
      supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: row.path),
    );
  }

  Future<void> hideProject({required String projectId}) {
    return _projectsDao.hideProject(projectId: projectId);
  }

  Future<String?> getBaseBranch({required String projectId}) {
    return _projectsDao.getBaseBranch(projectId: projectId);
  }

  Future<void> setBaseBranch({required String projectId, required String? baseBranch}) {
    return _projectsDao.setBaseBranch(
      projectId: projectId,
      baseBranch: baseBranch,
    );
  }

  /// Forge identity — host plus `org/repo` slug — parsed from the project's
  /// git remote. Null when the project directory is unknown, is not a git
  /// repository, has no remotes, or its remote has no forge-style identity
  /// (e.g. a local filesystem remote) — absence is a legitimate state the
  /// client renders by omitting repository identity.
  Future<GitRemoteIdentity?> getRemoteIdentity({required String projectId}) async {
    final path = await _projectsDao.getResolvedPath(projectId: projectId);
    if (path == null) {
      return null;
    }
    final remoteUrl = await _gitCliApi.getRemoteUrl(projectPath: path);
    if (remoteUrl == null) {
      return null;
    }
    return _remoteIdentityParser.parse(remoteUrl: remoteUrl);
  }

  Future<StoredProjectActivity?> getStoredSessionActivity({required String sessionId}) async {
    final session = await _sessionDao.getSession(sessionId: sessionId);
    if (session == null) return null;
    final project = await _projectsDao.getProject(projectId: session.projectId);
    final activity = _mapActivity(project);
    if (activity == null) return null;
    return StoredProjectActivity(projectId: session.projectId, activity: activity);
  }

  Future<Map<String, ProjectActivity>> getActivities({required Set<String> projectIds}) async {
    final projects = await _projectsDao.getAllProjects();
    return {
      for (final project in projects)
        if (projectIds.contains(project.projectId)) project.projectId: _mapActivity(project)!,
    };
  }

  Future<ProjectActivity?> getActivity({required String projectId}) async {
    return _mapActivity(await _projectsDao.getProject(projectId: projectId));
  }

  Future<void> writeActivity({required String projectId, required ProjectActivity activity}) =>
      _projectsDao.setActivity(projectId: projectId, createdAt: activity.createdAt, updatedAt: activity.updatedAt);

  bool _directoryMissing(String path) {
    try {
      return !_filesystemApi.directoryExists(path);
    } on FileSystemException catch (error, stackTrace) {
      Log.w("ProjectRepository: could not determine whether $path exists; treating as present", error, stackTrace);
      return false;
    }
  }

  Future<bool> _supportsDedicatedWorktrees({required String path}) async {
    try {
      if (!await _gitCliApi.isGitInitialized(projectPath: path)) return false;
      return await _gitCliApi.hasAtLeastOneCommit(projectPath: path);
    } on Object catch (error, stackTrace) {
      Log.w("ProjectRepository: failed to inspect Git worktree support for $path", error, stackTrace);
      return false;
    }
  }

  static ProjectTime _activityToTime(ProjectActivity activity) {
    return ProjectTime(created: activity.createdAt, updated: activity.updatedAt);
  }

  static ProjectActivity? _mapActivity(ProjectDto? project) {
    if (project == null) return null;
    return ProjectActivity(createdAt: project.createdAt, updatedAt: project.updatedAt);
  }
}
