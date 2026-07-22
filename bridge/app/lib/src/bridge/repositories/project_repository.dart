import "dart:io" show FileSystemException;
import "dart:math" show max;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PluginOperationException,
        PluginProjectOwnership,
        PluginSessionTime;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart" show SessionDao, SessionUnseenRow;
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../../repositories/project_catalog_identity_calculator.dart";
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

  final Map<String, BridgePluginApi> _operationalPlugins;
  final String? Function() _readDefaultEnabledPluginId;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _unseenCalculator;
  final FilesystemApi _filesystemApi;
  final GitCliApi _gitCliApi;
  final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator;
  final Duration _aggregateSourceDeadline;

  ProjectRepository({
    required Map<String, BridgePluginApi> operationalPlugins,
    required String? Function() readDefaultEnabledPluginId,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionUnseenCalculator unseenCalculator,
    required FilesystemApi filesystemApi,
    required GitCliApi gitCliApi,
    required ProjectCatalogIdentityCalculator projectCatalogIdentityCalculator,
    required Duration aggregateSourceDeadline,
  }) : _operationalPlugins = operationalPlugins,
       _readDefaultEnabledPluginId = readDefaultEnabledPluginId,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _unseenCalculator = unseenCalculator,
       _filesystemApi = filesystemApi,
       _gitCliApi = gitCliApi,
       _projectCatalogIdentityCalculator = projectCatalogIdentityCalculator,
       _aggregateSourceDeadline = aggregateSourceDeadline;

  Set<String> get operationalPluginIds => Set<String>.unmodifiable(_operationalPlugins.keys);

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

  /// Resolves the canonical target for opening [path].
  ///
  /// For a native plugin the backend maps the opened directory to the stable
  /// project id (a moved folder keeps its identity). A bridge-derived plugin
  /// prefers the normalized directory while retaining any same-path catalog id.
  Future<ProjectOpenTarget> resolveProjectOpenTarget({required String path}) async {
    switch (_requireDefaultPlugin(operation: "openProject")) {
      case BridgeDerivedProjectsPluginApi():
        final canonical = normalizeProjectDirectory(directory: path);
        final storedProjects = await _projectsDao.getAllProjects();
        final stored = _projectCatalogIdentityCalculator.calculate(
          projectsById: {
            for (final project in storedProjects) project.projectId: project,
          },
          projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
            projects: storedProjects,
          ),
          preferredProjectId: canonical,
          observedPath: canonical,
        );
        final base = p.basename(canonical);
        return ProjectOpenTarget(
          project: Project(
            id: stored?.projectId ?? canonical,
            name: stored?.displayName ?? (base.isEmpty ? canonical : base),
            path: canonical,
            time: null,
            supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: canonical),
          ),
          path: canonical,
          projectOwnership: PluginProjectOwnership.bridgeDerived,
        );
      case final NativeProjectsPluginApi plugin:
        final openedPath = normalizeProjectDirectory(directory: path);
        final pluginProject = await plugin.getProject(openedPath);
        final storedProjects = await _projectsDao.getAllProjects();
        final existing = _projectCatalogIdentityCalculator.calculate(
          projectsById: {
            for (final project in storedProjects) project.projectId: project,
          },
          projectsByNormalizedPath: _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
            projects: storedProjects,
          ),
          preferredProjectId: pluginProject.id,
          observedPath: openedPath,
        );
        return ProjectOpenTarget(
          project: pluginProject
              .toSharedProject(
                path: openedPath,
                hasUnseenChanges: false,
                directoryMissing: false,
                supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: openedPath),
                time: null,
              )
              .copyWith(id: existing?.projectId ?? pluginProject.id),
          path: openedPath,
          projectOwnership: PluginProjectOwnership.native,
        );
    }
  }

  /// Rechecks the opened project's canonical identity, merges [observedAt]
  /// monotonically with that row's activity, persists it, and unhides it in one
  /// transaction. A concurrent catalog import may have claimed
  /// [ProjectOpenTarget.path] after [resolveProjectOpenTarget] took its snapshot.
  Future<
    ({
      ProjectActivity committedActivity,
      ProjectOpenTarget committedTarget,
      bool updatedAtAdvanced,
    })
  >
  persistOpenedProject({
    required ProjectOpenTarget target,
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
        preferredProjectId: target.projectId,
        observedPath: target.path,
      );
      final committedTarget = existing == null
          ? target
          : ProjectOpenTarget(
              project: target.project.copyWith(id: existing.projectId),
              path: target.path,
              projectOwnership: target.projectOwnership,
            );
      final currentActivity = _mapActivity(existing);
      final committedActivity = ProjectActivity(
        createdAt: currentActivity?.createdAt ?? observedAt,
        updatedAt: max(currentActivity?.updatedAt ?? observedAt, observedAt),
      );
      await _projectsDao.recordOpenedProject(
        projectId: committedTarget.projectId,
        path: committedTarget.path,
        displayName: target.projectOwnership == PluginProjectOwnership.native ? committedTarget.project.name : null,
        createdAt: committedActivity.createdAt,
        updatedAt: committedActivity.updatedAt,
      );
      return (
        committedActivity: committedActivity,
        committedTarget: committedTarget,
        updatedAtAdvanced: currentActivity == null || committedActivity.updatedAt > currentActivity.updatedAt,
      );
    });
  }

  Future<Project> mapOpenedProject({
    required ProjectOpenTarget target,
    required ProjectActivity committedActivity,
  }) async {
    return target.project.copyWith(
      time: _activityToTime(committedActivity),
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
    switch (_requireDefaultPlugin(operation: "renameProject")) {
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
          supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: canonical),
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
        return updated
            .toSharedProject(
              path: path,
              hasUnseenChanges: await projectHasUnseenChanges(projectId: projectId),
              directoryMissing: _directoryMissing(path),
              supportsDedicatedWorktrees: await _supportsDedicatedWorktrees(path: path),
              time: _activityToTime(activity!),
            )
            .copyWith(id: projectId);
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

  Future<List<ProjectActivityEvidence>> listProjectActivityEvidence({required String pluginId}) async {
    final selected = _operationalPlugins[pluginId];
    if (selected == null) {
      throw PluginOperationException(
        "listProjectActivityEvidence",
        statusCode: 503,
        message: "plugin $pluginId is not running",
      );
    }
    return _listProjectActivityEvidence(plugin: selected).timeout(_aggregateSourceDeadline);
  }

  Future<List<ProjectActivityEvidence>> _listProjectActivityEvidence({required BridgePluginApi plugin}) async {
    switch (plugin) {
      case final NativeProjectsPluginApi plugin:
        final pluginProjects = await plugin.getProjects();
        return _projectsDao.transaction(() async {
          final storedProjects = (await _projectsDao.getAllProjects()).toList();
          final projectsById = <String, ProjectDto>{
            for (final project in storedProjects) project.projectId: project,
          };
          final projectsByNormalizedPath = _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
            projects: storedProjects,
          );
          final missingProjects = <String, ({String path, int? createdAt, int? updatedAt})>{};
          final evidence = <ProjectActivityEvidence>[];
          for (final project in pluginProjects) {
            final existing = _projectCatalogIdentityCalculator.calculate(
              projectsById: projectsById,
              projectsByNormalizedPath: projectsByNormalizedPath,
              preferredProjectId: project.id,
              observedPath: project.directory,
            );
            final projectId = existing?.projectId ?? project.id;
            if (existing == null) {
              missingProjects[projectId] = (
                path: project.directory,
                createdAt: project.activity?.createdAt,
                updatedAt: project.activity?.updatedAt,
              );
              final inserted = ProjectDto(
                projectId: projectId,
                path: project.directory,
                createdAt: project.activity?.createdAt ?? 0,
                updatedAt: project.activity?.updatedAt ?? 0,
                projectionUpdatedAt: 0,
              );
              projectsById[projectId] = inserted;
              projectsByNormalizedPath[normalizeProjectDirectory(directory: project.directory)] = inserted;
            }
            evidence.add(
              ProjectActivityEvidence(
                pluginId: plugin.id,
                projectId: projectId,
                pluginActivity: project.activity,
                sessionActivities: const [],
              ),
            );
          }
          await _projectsDao.insertProjectsWithPathsIfMissing(
            projects: missingProjects,
          );
          return evidence;
        });
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
        final projectsById = <String, ProjectDto>{
          for (final project in storedProjects) project.projectId: project,
        };
        final projectsByNormalizedPath = _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
          projects: storedProjects,
        );
        final evidence = <ProjectActivityEvidence>[];
        for (final entry in grouped.entries) {
          final stored = _projectCatalogIdentityCalculator.calculate(
            projectsById: projectsById,
            projectsByNormalizedPath: projectsByNormalizedPath,
            preferredProjectId: entry.key,
            observedPath: entry.key,
          );
          if (stored == null) continue;
          evidence.add(
            ProjectActivityEvidence(
              pluginId: plugin.id,
              projectId: stored.projectId,
              pluginActivity: null,
              sessionActivities: entry.value,
            ),
          );
        }
        return evidence;
    }
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

  BridgePluginApi _requireDefaultPlugin({required String operation}) {
    final defaultPluginId = _readDefaultEnabledPluginId();
    if (defaultPluginId == null) {
      throw PluginOperationException(
        operation,
        statusCode: 503,
        message: "no default plugin is enabled",
      );
    }
    final plugin = _operationalPlugins[defaultPluginId];
    if (plugin != null) return plugin;
    throw PluginOperationException(
      operation,
      statusCode: 503,
      message: "plugin $defaultPluginId is not running",
    );
  }
}

/// Canonical target returned by [ProjectRepository.resolveProjectOpenTarget].
class ProjectOpenTarget {
  const ProjectOpenTarget({
    required this.project,
    required this.path,
    required this.projectOwnership,
  });

  final Project project;
  String get projectId => project.id;

  /// Live directory where the project currently resides on disk.
  final String path;

  final PluginProjectOwnership projectOwnership;
}
