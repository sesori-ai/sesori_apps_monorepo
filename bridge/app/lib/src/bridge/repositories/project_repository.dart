import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeDerivedProjectSource, BridgePluginApi, ProjectTrackingMode;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "derived_project_builder.dart";
import "mappers/plugin_project_mapper.dart";
import "mappers/worktree_project_mapper.dart";

/// Project data aggregator with two paths chosen by the plugin's declared
/// [ProjectTrackingMode]:
///
/// - **nativeBackend** (e.g. OpenCode): the plugin owns the project list. This
///   path fetches `plugin.getProjects()`, overlays the bridge's hidden flag, and
///   sorts — unchanged from before bridge-derived tracking existed.
/// - **bridgeDerived** (Codex and every ACP plugin): the backend has no project
///   concept, so the bridge derives the list from the plugin's sessions
///   ([BridgeDerivedProjectSource.listAllSessions]) via [DerivedProjectBuilder]
///   and owns opened-folder + display-name persistence in [ProjectsTable].
///
/// All capability branching is contained here; routing handlers stay
/// capability-agnostic and call these methods unconditionally.
class ProjectRepository {
  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final ProjectTrackingMode _trackingMode;
  final DerivedProjectBuilder _derivedProjectBuilder;

  ProjectRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required ProjectTrackingMode trackingMode,
    required DerivedProjectBuilder derivedProjectBuilder,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _trackingMode = trackingMode,
       _derivedProjectBuilder = derivedProjectBuilder;

  bool get _isDerived => _trackingMode == ProjectTrackingMode.bridgeDerived;

  Future<List<Project>> getProjects() async {
    if (_isDerived) {
      // Seed the plugin's launch directory as an opened folder so it always
      // surfaces as a project — even with no sessions yet. Idempotent: it only
      // stamps openedAt when the folder has none.
      final source = _plugin as BridgeDerivedProjectSource;
      await _projectsDao.ensureOpenedProject(
        projectId: normalizeProjectDirectory(source.launchDirectory),
        openedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final derived = await _deriveProjects();
      // Persist canonical rows so a later session insert (and the hidden flag)
      // have a project row to reference.
      await _projectsDao.insertProjectsIfMissing(
        projectIds: [for (final project in derived) project.id],
      );
      final hiddenIds = await _projectsDao.getHiddenProjectIds();
      final visible = derived.where((project) => !hiddenIds.contains(project.id)).toList();
      visible.sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
      return visible;
    }

    final pluginProjects = await _plugin.getProjects();
    await _projectsDao.insertProjectsIfMissing(
      projectIds: [for (final p in pluginProjects) p.id],
    );
    final hiddenIds = await _projectsDao.getHiddenProjectIds();
    final projects = pluginProjects.where((p) => !hiddenIds.contains(p.id)).map((p) => p.toSharedProject()).toList();
    projects.sort(
      (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
    );
    return projects;
  }

  Future<Project> openProject({required String path}) async {
    if (_isDerived) {
      // Record the folder so a project with no sessions yet survives the
      // refresh and later bridge restarts; the plugin has no getProject to call.
      final canonical = normalizeProjectDirectory(path);
      await _projectsDao.recordOpenedProject(
        projectId: canonical,
        openedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _projectsDao.unhideProject(projectId: canonical);
      return _findDerivedProject(canonical);
    }

    final pluginProject = await _plugin.getProject(path);
    await _projectsDao.unhideProject(projectId: pluginProject.id);
    return pluginProject.toSharedProject();
  }

  Future<Project> renameProject({required String projectId, required String name}) async {
    if (_isDerived) {
      // codex has no backend to store a project name, so persist a display-name
      // override that _deriveProjects applies on the next listing.
      final canonical = normalizeProjectDirectory(projectId);
      await _projectsDao.setDisplayName(projectId: canonical, displayName: name);
      return _findDerivedProject(canonical);
    }

    final updated = await _plugin.renameProject(projectId: projectId, name: name);
    return updated.toSharedProject();
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

  /// Builds the full bridge-derived project set from the plugin's sessions and
  /// the bridge's stored opened-folder/display-name rows.
  Future<List<Project>> _deriveProjects() async {
    final source = _plugin as BridgeDerivedProjectSource;
    final (sessions, storedProjects, worktreeProjectPaths) = await (
      source.listAllSessions(),
      _projectsDao.getAllProjects(),
      _sessionDao.getWorktreeProjectPaths(pluginId: _plugin.id),
    ).wait;
    return _derivedProjectBuilder.build(
      sessions: sessions,
      storedProjects: storedProjects,
      worktreeMapper: WorktreeProjectMapper(worktreeProjectPaths: worktreeProjectPaths),
    );
  }

  /// The derived project for [canonicalId], or a minimal placeholder when it has
  /// no sessions and no stored row yet (e.g. immediately after a rename whose
  /// listing hasn't refreshed).
  Future<Project> _findDerivedProject(String canonicalId) async {
    final derived = await _deriveProjects();
    for (final project in derived) {
      if (project.id == canonicalId) return project;
    }
    final base = p.basename(canonicalId);
    return Project(
      id: canonicalId,
      name: base.isEmpty ? canonicalId : base,
      time: null,
    );
  }
}
