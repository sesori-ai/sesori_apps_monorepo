import "dart:io" show FileSystemException;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeDerivedProjectsPluginApi, BridgePluginApi, Log, NativeProjectsPluginApi, PluginSessionTime;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart" show SessionDao, SessionUnseenRow;
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../api/filesystem_api.dart";
import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "mappers/plugin_project_mapper.dart";
import "mappers/project_catalog_mapper.dart";
import "models/project_activity.dart";
import "models/project_activity_evidence.dart";
import "models/project_not_found_exception.dart";
import "session_unseen_calculator.dart";

/// Owns catalog project reads and bridge/plugin-backed targeted operations.
class ProjectRepository {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();
  static const ProjectCatalogMapper _projectCatalogMapper = ProjectCatalogMapper();

  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _unseenCalculator;
  final FilesystemApi _filesystemApi;
  final GitCliApi _gitCliApi;

  ProjectRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionUnseenCalculator unseenCalculator,
    required FilesystemApi filesystemApi,
    required GitCliApi gitCliApi,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _unseenCalculator = unseenCalculator,
       _filesystemApi = filesystemApi,
       _gitCliApi = gitCliApi;

  Future<List<Project>> getProjects() async {
    final rows = await _projectsDao.getCatalogProjects();
    final unseenById = await unseenByProjectId(
      projectIds: [for (final row in rows) row.projectId],
    );
    return [
      for (final row in rows)
        _projectCatalogMapper.map(
          row: row,
          hasUnseenChanges: unseenById[row.projectId] ?? false,
          directoryMissing: false,
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
    );
  }

  /// Resolves the canonical target for opening [path].
  ///
  /// For a native plugin the backend maps the opened directory to the stable
  /// project id (a moved folder keeps its identity). For a bridge-derived
  /// plugin the canonical id is the normalized directory itself.
  Future<ProjectOpenTarget> resolveProjectOpenTarget({required String path}) async {
    switch (_plugin) {
      case BridgeDerivedProjectsPluginApi():
        final canonical = normalizeProjectDirectory(directory: path);
        final stored = await _projectsDao.getProject(projectId: canonical);
        final base = p.basename(canonical);
        return ProjectOpenTarget(
          project: Project(
            id: canonical,
            name: stored?.displayName ?? (base.isEmpty ? canonical : base),
            path: canonical,
            time: null,
          ),
          path: canonical,
        );
      case final NativeProjectsPluginApi plugin:
        final openedPath = normalizeProjectDirectory(directory: path);
        final pluginProject = await plugin.getProject(openedPath);
        return ProjectOpenTarget(
          project: pluginProject.toSharedProject(
            path: openedPath,
            hasUnseenChanges: false,
            directoryMissing: false,
            time: null,
          ),
          path: openedPath,
        );
    }
  }

  /// Persists the exact [activity] for an opened project and unhides it. This is
  /// a dumb exact write; the caller ([ProjectActivityService]) owns the decision.
  Future<void> persistOpenedProject({
    required ProjectOpenTarget target,
    required ProjectActivity activity,
  }) async {
    await _projectsDao.recordOpenedProject(
      projectId: target.projectId,
      path: target.path,
      displayName: _plugin is NativeProjectsPluginApi ? target.project.name : null,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
    );
  }

  Future<Project> mapOpenedProject({required ProjectOpenTarget target}) async {
    final activity = await getActivity(projectId: target.projectId);
    return target.project.copyWith(
      time: _activityToTime(activity!),
      hasUnseenChanges: await projectHasUnseenChanges(projectId: target.projectId),
      directoryMissing: _directoryMissing(target.path),
    );
  }

  Future<Project> renameProject({required String projectId, required String name}) async {
    final path = await _projectsDao.getResolvedPath(projectId: projectId);
    if (path == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final activity = _mapActivity(await _projectsDao.getProject(projectId: projectId));
    switch (_plugin) {
      case BridgeDerivedProjectsPluginApi():
        // codex has no backend to store a project name, so persist a display-name
        // override that later catalog reads apply.
        final canonical = normalizeProjectDirectory(directory: path);
        await _projectsDao.setDisplayName(
          projectId: projectId,
          displayName: name,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        final row = (await _projectsDao.getProject(projectId: projectId))!;
        return _projectCatalogMapper.map(
          row: row,
          hasUnseenChanges: await projectHasUnseenChanges(projectId: projectId),
          directoryMissing: _directoryMissing(canonical),
        );

      case final NativeProjectsPluginApi plugin:
        // The backend looks the project up by directory, so hand it the live
        // path rather than the (possibly moved-away-from) id.
        final updated = await plugin.renameProject(projectId: path, name: name);
        final renamedAt = DateTime.now().millisecondsSinceEpoch;
        await _projectsDao.setDisplayName(
          projectId: projectId,
          displayName: name,
          updatedAt: renamedAt,
        );
        return updated.toSharedProject(
          path: path,
          hasUnseenChanges: await projectHasUnseenChanges(projectId: updated.id),
          directoryMissing: _directoryMissing(path),
          time: _activityToTime(activity!),
        );
    }
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

  Future<ProjectActivityReconciliationData> listProjectActivityEvidence() async {
    switch (_plugin) {
      case final NativeProjectsPluginApi plugin:
        final pluginProjects = await plugin.getProjects();
        await _projectsDao.insertProjectsWithPathsIfMissing(
          projects: {
            for (final project in pluginProjects)
              project.id: (
                path: project.directory,
                createdAt: project.activity?.createdAt,
                updatedAt: project.activity?.updatedAt,
              ),
          },
        );
        final storedProjects = await _projectsDao.getAllProjects();
        return ProjectActivityReconciliationData(
          evidence: [
            for (final p in pluginProjects)
              ProjectActivityEvidence(
                projectId: p.id,
                pluginActivity: p.activity,
                sessionActivities: const [],
              ),
          ],
          storedActivities: _mapActivities(storedProjects),
        );
      case final BridgeDerivedProjectsPluginApi plugin:
        final (storedProjects, sessionProjectPaths, tombstoned) = await (
          _projectsDao.getAllProjects(),
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          _sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
        ).wait;
        final sessions = await plugin.listAllSessions(
          knownDirectories: {
            for (final stored in storedProjects) stored.path,
            for (final row in sessionProjectPaths) ?row.worktreePath,
          },
        );
        final pathBySessionId = {
          for (final row in sessionProjectPaths) row.backendSessionId: row.projectPath,
        };
        final grouped = <String, List<PluginSessionTime>>{};
        for (final session in sessions) {
          if (tombstoned.contains(session.id)) continue;
          final time = session.time;
          if (time == null) continue;
          final projectPath = pathBySessionId[session.id] ?? session.directory;
          final key = normalizeProjectDirectory(directory: projectPath);
          grouped.putIfAbsent(key, () => []).add(time);
        }
        return ProjectActivityReconciliationData(
          evidence: [
            for (final entry in grouped.entries)
              ProjectActivityEvidence(
                projectId: entry.key,
                pluginActivity: null,
                sessionActivities: entry.value,
              ),
          ],
          storedActivities: _mapActivities(storedProjects),
        );
    }
  }

  Future<ProjectActivity?> getActivity({required String projectId}) async {
    return _mapActivity(await _projectsDao.getProject(projectId: projectId));
  }

  Future<void> writeActivity({required String projectId, required ProjectActivity activity}) =>
      _projectsDao.setActivity(projectId: projectId, createdAt: activity.createdAt, updatedAt: activity.updatedAt);

  Future<void> batchWriteActivities({required Map<String, ProjectActivity> activities}) =>
      _projectsDao.setAllActivities(
        activities: {
          for (final entry in activities.entries)
            entry.key: (createdAt: entry.value.createdAt, updatedAt: entry.value.updatedAt),
        },
      );

  bool _directoryMissing(String path) {
    try {
      return !_filesystemApi.directoryExists(path);
    } on FileSystemException catch (error, stackTrace) {
      Log.w("ProjectRepository: could not determine whether $path exists; treating as present", error, stackTrace);
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

  static Map<String, ProjectActivity> _mapActivities(List<ProjectDto> projects) => {
    for (final project in projects) project.projectId: _mapActivity(project)!,
  };
}

/// Canonical target returned by [ProjectRepository.resolveProjectOpenTarget].
class ProjectOpenTarget {
  const ProjectOpenTarget({required this.project, required this.path});

  final Project project;
  String get projectId => project.id;

  /// Live directory where the project currently resides on disk.
  final String path;
}
