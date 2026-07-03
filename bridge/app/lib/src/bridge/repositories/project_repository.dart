import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeDerivedProjectsPluginApi, BridgePluginApi, NativeProjectsPluginApi;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "derived_project_builder.dart";
import "mappers/plugin_project_mapper.dart";
import "session_unseen_calculator.dart";

/// Project data aggregator with two paths chosen by the plugin's sealed
/// subtype:
///
/// - [NativeProjectsPluginApi] (e.g. OpenCode): the plugin owns the project
///   list. This path fetches `plugin.getProjects()`, overlays the bridge's
///   hidden flag and unseen state, and sorts — unchanged from before
///   bridge-derived tracking existed.
/// - [BridgeDerivedProjectsPluginApi] (Codex and every ACP plugin): the backend
///   has no project concept, so the bridge derives the list from the plugin's
///   sessions via [DerivedProjectBuilder] and owns opened-folder + display-name
///   persistence in the projects table.
///
/// All capability branching is contained here; routing handlers stay
/// capability-agnostic and call these methods unconditionally.
class ProjectRepository {
  static const DerivedProjectBuilder _derivedProjectBuilder = DerivedProjectBuilder();

  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _unseenCalculator;

  ProjectRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required SessionUnseenCalculator unseenCalculator,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _unseenCalculator = unseenCalculator;

  Future<List<Project>> getProjects() async {
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        // Seed the plugin's launch directory so it always surfaces as a project
        // — even with no sessions yet. Insert-or-ignore: a fresh row stamps its
        // openedAt at creation; an existing row is left untouched.
        await _projectsDao.insertProjectsIfMissing(
          projectIds: [normalizeProjectDirectory(directory: plugin.launchDirectory)],
        );
        final derived = await _deriveProjects(plugin);
        // Persist canonical rows so a later session insert (and the hidden flag)
        // have a project row to reference.
        await _projectsDao.insertProjectsIfMissing(
          projectIds: [for (final project in derived) project.id],
        );
        final hiddenIds = await _projectsDao.getHiddenProjectIds();
        final visible = derived.where((project) => !hiddenIds.contains(project.id)).toList();
        final unseenById = await unseenByProjectId(
          projectIds: [for (final project in visible) project.id],
        );
        final projects = [
          for (final project in visible)
            project.copyWith(hasUnseenChanges: unseenById[project.id] ?? false),
        ];
        projects.sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
        return projects;

      case final NativeProjectsPluginApi plugin:
        final pluginProjects = await plugin.getProjects();
        await _projectsDao.insertProjectsIfMissing(
          projectIds: [for (final p in pluginProjects) p.id],
        );
        final hiddenIds = await _projectsDao.getHiddenProjectIds();
        final visible = pluginProjects.where((p) => !hiddenIds.contains(p.id)).toList(growable: false);
        final unseenById = await unseenByProjectId(
          projectIds: [for (final p in visible) p.id],
        );
        final projects = visible
            .map((p) => p.toSharedProject(hasUnseenChanges: unseenById[p.id] ?? false))
            .toList();
        projects.sort(
          (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
        );
        return projects;
    }
  }

  /// Whether [projectId] has at least one non-archived session with unseen
  /// changes. Child sessions never have a row, so they cannot contribute.
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

  /// The project for [projectId]. A native plugin owns the lookup; for a
  /// bridge-derived plugin the id IS the canonical directory and the plugin has
  /// no `getProject`, so we resolve it from the derived set (or a placeholder).
  Future<Project> getProject({required String projectId}) async {
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        return _findDerivedProject(plugin, normalizeProjectDirectory(directory: projectId));
      case final NativeProjectsPluginApi plugin:
        final pluginProject = await plugin.getProject(projectId);
        return pluginProject.toSharedProject(
          hasUnseenChanges: await projectHasUnseenChanges(projectId: pluginProject.id),
        );
    }
  }

  Future<Project> openProject({required String path}) async {
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        // Record the folder so a project with no sessions yet survives the
        // refresh and later bridge restarts; the plugin has no getProject to
        // call. Re-opening bumps openedAt so the folder resurfaces with a
        // fresh time.
        final canonical = normalizeProjectDirectory(directory: path);
        await _projectsDao.recordOpenedProject(
          projectId: canonical,
          openedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _projectsDao.unhideProject(projectId: canonical);
        return _findDerivedProject(plugin, canonical);

      case final NativeProjectsPluginApi plugin:
        final pluginProject = await plugin.getProject(path);
        await _projectsDao.unhideProject(projectId: pluginProject.id);
        return pluginProject.toSharedProject(
          hasUnseenChanges: await projectHasUnseenChanges(projectId: pluginProject.id),
        );
    }
  }

  Future<Project> renameProject({required String projectId, required String name}) async {
    switch (_plugin) {
      case final BridgeDerivedProjectsPluginApi plugin:
        // codex has no backend to store a project name, so persist a display-name
        // override that _deriveProjects applies on the next listing.
        final canonical = normalizeProjectDirectory(directory: projectId);
        await _projectsDao.setDisplayName(projectId: canonical, displayName: name);
        return _findDerivedProject(plugin, canonical);

      case final NativeProjectsPluginApi plugin:
        final updated = await plugin.renameProject(projectId: projectId, name: name);
        return updated.toSharedProject(
          hasUnseenChanges: await projectHasUnseenChanges(projectId: updated.id),
        );
    }
  }

  Future<void> hideProject({required String projectId}) {
    return _projectsDao.hideProject(projectId: projectId);
  }

  Future<String?> getBaseBranch({required String projectId}) {
    return _projectsDao.getBaseBranch(projectId: projectId);
  }

  Future<void> setBaseBranch({required String projectId, required String baseBranch}) {
    return _projectsDao.setBaseBranch(
      projectId: projectId,
      baseBranch: baseBranch,
    );
  }

  /// Builds the full bridge-derived project set from the plugin's sessions, the
  /// bridge's stored project rows, and the stored session→project attribution.
  Future<List<Project>> _deriveProjects(BridgeDerivedProjectsPluginApi plugin) async {
    final (sessions, storedProjects, sessionProjectPaths) = await (
      plugin.listAllSessions(),
      _projectsDao.getAllProjects(),
      _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
    ).wait;
    return _derivedProjectBuilder.build(
      sessions: sessions,
      storedProjects: storedProjects,
      projectPathBySessionId: {
        for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
      },
    );
  }

  /// The derived project for [canonicalId], or a minimal placeholder when the
  /// bridge has no row and no session for it yet (e.g. a getProject for a path
  /// that was never listed). The placeholder still honours a stored
  /// display-name override so a rename isn't lost to the directory basename.
  Future<Project> _findDerivedProject(BridgeDerivedProjectsPluginApi plugin, String canonicalId) async {
    final hasUnseenChanges = await projectHasUnseenChanges(projectId: canonicalId);
    final derived = await _deriveProjects(plugin);
    for (final project in derived) {
      if (project.id == canonicalId) return project.copyWith(hasUnseenChanges: hasUnseenChanges);
    }
    final stored = await _projectsDao.getAllProjects();
    String? displayName;
    for (final row in stored) {
      if (normalizeProjectDirectory(directory: row.path) == canonicalId) {
        displayName = row.displayName;
        break;
      }
    }
    final base = p.basename(canonicalId);
    return Project(
      id: canonicalId,
      name: displayName != null && displayName.isNotEmpty ? displayName : (base.isEmpty ? canonicalId : base),
      time: null,
      hasUnseenChanges: hasUnseenChanges,
    );
  }
}
