import "dart:io" show FileSystemException;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeDerivedProjectsPluginApi,
        BridgePluginApi,
        Log,
        NativeProjectsPluginApi,
        PluginProjectActivity,
        PluginSessionTime;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart" show SessionDao, SessionUnseenRow;
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../api/filesystem_api.dart";
import "derived_project_builder.dart";
import "mappers/plugin_project_mapper.dart";
import "models/project_activity.dart";
import "models/project_activity_evidence.dart";
import "models/project_not_found_exception.dart";
import "session_unseen_calculator.dart";

typedef ProjectSessionListMetadata = ({
  bool hasUnseenChanges,
  int? lastUserInteractionAt,
});

/// Project data aggregator with two paths chosen by the plugin's sealed
/// subtype:
///
/// - [NativeProjectsPluginApi] (e.g. OpenCode): the plugin owns the project
///   list. This path fetches `plugin.getProjects()` once, inserts rows for
///   newly discovered projects using the plugin's session-derived activity, and
///   returns projects with [Project.time] read from the persisted row.
/// - [BridgeDerivedProjectsPluginApi] (Codex and every ACP plugin): the backend
///   has no project concept, so the bridge derives the list from the plugin's
///   sessions via [DerivedProjectBuilder] and owns created/updated persistence
///   in the projects table.
///
/// All capability branching is contained here; routing handlers stay
/// capability-agnostic and call these methods unconditionally.
///
/// This repository aggregates raw evidence, maps persistence rows, resolves open
/// targets, and performs exact reads and writes. It does not order timestamps.
class ProjectRepository {
  static const DerivedProjectBuilder _derivedProjectBuilder = DerivedProjectBuilder();

  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _unseenCalculator;
  final FilesystemApi _filesystemApi;

  ProjectRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionUnseenCalculator unseenCalculator,
    required FilesystemApi filesystemApi,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _unseenCalculator = unseenCalculator,
       _filesystemApi = filesystemApi;

  Future<List<Project>> getProjects({required int defaultTimestamp}) async {
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        // Seed the plugin's launch directory so it always surfaces as a project
        // — even with no sessions yet. Existing rows are left untouched.
        await _projectsDao.insertMissingProjectsWithActivity(
          activities: {
            normalizeProjectDirectory(directory: plugin.launchDirectory): (
              path: normalizeProjectDirectory(directory: plugin.launchDirectory),
              createdAt: defaultTimestamp,
              updatedAt: defaultTimestamp,
            ),
          },
        );
        final derived = await _deriveProjects(plugin);
        await _seedNewProjects([
          for (final project in derived) (project: project, directActivity: null),
        ], defaultTimestamp: defaultTimestamp);
        final hiddenIds = await _projectsDao.getHiddenProjectIds();
        final visible = derived.where((project) => !hiddenIds.contains(project.id)).toList();
        final metadataById = await getSessionListMetadataByProjectId(
          projectIds: [for (final project in visible) project.id],
        );
        final activityById = _mapActivities(await _projectsDao.getAllProjects());
        final projects = [
          for (final project in visible)
            project.copyWith(
              hasUnseenChanges: metadataById[project.id]?.hasUnseenChanges ?? false,
              lastUserInteractionAt: metadataById[project.id]?.lastUserInteractionAt,
              directoryMissing: _directoryMissing(project.id),
              time: _activityToTime(activityById[project.id]!),
            ),
        ];
        projects.sort(_projectComparator);
        return projects;

      case final NativeProjectsPluginApi plugin:
        final pluginProjects = await plugin.getProjects();
        await _seedNewProjects([
          for (final p in pluginProjects)
            (
              project: p.toSharedProject(
                path: p.directory,
                hasUnseenChanges: false,
                directoryMissing: false,
                time: null,
              ),
              directActivity: p.activity,
            ),
        ], defaultTimestamp: defaultTimestamp);
        final storedProjects = await _projectsDao.getAllProjects();
        final pathById = {
          for (final stored in storedProjects)
            if (stored.path.isNotEmpty) stored.projectId: stored.path,
        };
        final hiddenIds = await _projectsDao.getHiddenProjectIds();
        final visible = pluginProjects.where((p) => !hiddenIds.contains(p.id)).toList(growable: false);
        final metadataById = await getSessionListMetadataByProjectId(
          projectIds: [for (final p in visible) p.id],
        );
        final activityById = _mapActivities(storedProjects);
        final projects = visible.map((p) {
          final path = pathById[p.id] ?? p.directory;
          final metadata = metadataById[p.id];
          return p
              .toSharedProject(
                path: path,
                hasUnseenChanges: metadata?.hasUnseenChanges ?? false,
                directoryMissing: _directoryMissing(path),
                time: _activityToTime(activityById[p.id]!),
              )
              .copyWith(lastUserInteractionAt: metadata?.lastUserInteractionAt);
        }).toList();
        projects.sort(_projectComparator);
        return projects;
    }
  }

  /// Session-list metadata aggregated over the persisted root sessions in
  /// [projectId]. Archived roots remain valid user-interaction evidence, while
  /// only non-archived roots contribute to unseen state.
  Future<ProjectSessionListMetadata> getSessionListMetadata({required String projectId}) async {
    final rows = await _sessionDao.getUnseenRowsForProject(projectId: projectId);
    return _sessionListMetadata(rows);
  }

  /// Batched variant of [getSessionListMetadata] for project-list snapshots.
  Future<Map<String, ProjectSessionListMetadata>> getSessionListMetadataByProjectId({
    required List<String> projectIds,
  }) async {
    final rowsByProject = await _sessionDao.getUnseenRowsForProjects(projectIds: projectIds);
    return {
      for (final id in projectIds) id: _sessionListMetadata(rowsByProject[id] ?? const []),
    };
  }

  ProjectSessionListMetadata _sessionListMetadata(List<SessionUnseenRow> rows) {
    var hasUnseenChanges = false;
    int? lastUserInteractionAt;
    for (final row in rows) {
      final userMessageAt = row.userMessageAt;
      if (userMessageAt != null && (lastUserInteractionAt == null || userMessageAt > lastUserInteractionAt)) {
        lastUserInteractionAt = userMessageAt;
      }
      if (row.archivedAt == null &&
          _unseenCalculator.isUnseen(
            activity: row.activityAt,
            userMessage: userMessageAt,
            seen: row.seenAt,
          )) {
        hasUnseenChanges = true;
      }
    }
    return (
      hasUnseenChanges: hasUnseenChanges,
      lastUserInteractionAt: lastUserInteractionAt,
    );
  }

  /// The project for [projectId]. A native plugin owns the lookup; for a
  /// bridge-derived plugin the id IS the canonical directory and the plugin has
  /// no `getProject`, so we resolve it from the derived set (or a placeholder).
  Future<Project> getProject({required String projectId}) async {
    final path = await _projectsDao.getResolvedPath(projectId: projectId);
    if (path == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final activity = _mapActivity(await _projectsDao.getProject(projectId: projectId));
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        final project = await _findDerivedProject(plugin, normalizeProjectDirectory(directory: path));
        final metadata = await getSessionListMetadata(projectId: project.id);
        return project.copyWith(
          hasUnseenChanges: metadata.hasUnseenChanges,
          lastUserInteractionAt: metadata.lastUserInteractionAt,
          directoryMissing: _directoryMissing(project.id),
          time: _activityToTime(activity!),
        );
      case final NativeProjectsPluginApi plugin:
        // The backend needs the live directory — the id may point at a
        // location the folder has since moved away from.
        final pluginProject = await plugin.getProject(path);
        final metadata = await getSessionListMetadata(projectId: pluginProject.id);
        return pluginProject
            .toSharedProject(
              path: path,
              hasUnseenChanges: metadata.hasUnseenChanges,
              directoryMissing: _directoryMissing(path),
              time: _activityToTime(activity!),
            )
            .copyWith(lastUserInteractionAt: metadata.lastUserInteractionAt);
    }
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
    required String projectId,
    required String path,
    required ProjectActivity activity,
  }) async {
    await _projectsDao.recordOpenedProject(
      projectId: projectId,
      path: path,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
    );
    await _projectsDao.unhideProject(projectId: projectId);
  }

  Future<Project> mapOpenedProject({required ProjectOpenTarget target}) async {
    final activity = await getActivity(projectId: target.projectId);
    final metadata = await getSessionListMetadata(projectId: target.projectId);
    return target.project.copyWith(
      time: _activityToTime(activity!),
      hasUnseenChanges: metadata.hasUnseenChanges,
      lastUserInteractionAt: metadata.lastUserInteractionAt,
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
      case final BridgeDerivedProjectsPluginApi plugin:
        // codex has no backend to store a project name, so persist a display-name
        // override that _deriveProjects applies on the next listing.
        final canonical = normalizeProjectDirectory(directory: path);
        await _projectsDao.setDisplayName(projectId: canonical, displayName: name);
        final project = await _findDerivedProject(plugin, canonical);
        final metadata = await getSessionListMetadata(projectId: project.id);
        return project.copyWith(
          hasUnseenChanges: metadata.hasUnseenChanges,
          lastUserInteractionAt: metadata.lastUserInteractionAt,
          directoryMissing: _directoryMissing(project.id),
          time: _activityToTime(activity!),
        );

      case final NativeProjectsPluginApi plugin:
        // The backend looks the project up by directory, so hand it the live
        // path rather than the (possibly moved-away-from) id.
        final updated = await plugin.renameProject(projectId: path, name: name);
        final metadata = await getSessionListMetadata(projectId: updated.id);
        return updated
            .toSharedProject(
              path: path,
              hasUnseenChanges: metadata.hasUnseenChanges,
              directoryMissing: _directoryMissing(path),
              time: _activityToTime(activity!),
            )
            .copyWith(lastUserInteractionAt: metadata.lastUserInteractionAt);
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
          for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
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

  // ── Derived-project helpers ───────────────────────────────────────────────

  Future<List<Project>> _deriveProjects(
    BridgeDerivedProjectsPluginApi plugin,
  ) async {
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
    return _derivedProjectBuilder.build(
      // A backend without session deletion keeps enumerating deleted sessions
      // forever — the tombstones keep them out of project derivation.
      sessions: sessions.where((s) => !tombstoned.contains(s.id)).toList(growable: false),
      storedProjects: storedProjects,
      projectPathBySessionId: {
        for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
      },
    );
  }

  Future<Project> _findDerivedProject(BridgeDerivedProjectsPluginApi plugin, String canonicalId) async {
    final derived = await _deriveProjects(plugin);
    for (final project in derived) {
      if (project.id == canonicalId) return project;
    }
    final base = p.basename(canonicalId);
    return Project(
      id: canonicalId,
      name: base.isEmpty ? canonicalId : base,
      path: canonicalId,
      time: null,
    );
  }

  Future<void> _seedNewProjects(
    List<({Project project, PluginProjectActivity? directActivity})> projects, {
    required int defaultTimestamp,
  }) async {
    await _projectsDao.insertMissingProjectsWithActivity(
      activities: {
        for (final item in projects)
          item.project.id: (
            path: item.project.path,
            createdAt: item.directActivity?.createdAt ?? defaultTimestamp,
            updatedAt: item.directActivity?.updatedAt ?? defaultTimestamp,
          ),
      },
    );
  }

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

  static int _projectComparator(Project a, Project b) {
    final updatedA = a.time?.updated ?? 0;
    final updatedB = b.time?.updated ?? 0;
    if (updatedA != updatedB) return updatedB.compareTo(updatedA);
    final nameA = a.name ?? a.id;
    final nameB = b.name ?? b.id;
    final nameCompare = nameA.compareTo(nameB);
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  }
}

/// Canonical target returned by [ProjectRepository.resolveProjectOpenTarget].
class ProjectOpenTarget {
  const ProjectOpenTarget({required this.project, required this.path});

  final Project project;
  String get projectId => project.id;

  /// Live directory where the project currently resides on disk.
  final String path;
}
