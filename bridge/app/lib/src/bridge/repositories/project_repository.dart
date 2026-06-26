import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "mappers/plugin_project_mapper.dart";
import "session_unseen_calculator.dart";

/// Project data aggregator that fetches plugin projects, persists them
/// atomically via a single batch insert, and returns the visible/sorted list
/// to handlers.
///
/// This class exposes ONLY [getProjects]. Defensive "ensure project exists"
/// helpers are intentionally absent: per the Aristotle architectural review
/// (rule A5 — Unnecessary Complexity), single-use thin DAO wrappers are
/// rejected. Callers that need to ensure a specific project exists go through
/// [SessionPersistenceService.ensureProject] (Layer 3 → Layer 1) or call
/// [ProjectsDao.insertProjectIfMissing] directly from a Layer 2 repository
/// (e.g. [PullRequestRepository]).
class ProjectRepository {
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
    final pluginProjects = await _plugin.getProjects();
    await _projectsDao.insertProjectsIfMissing(
      projectIds: [for (final p in pluginProjects) p.id],
    );
    final hiddenIds = await _projectsDao.getHiddenProjectIds();
    final visible = pluginProjects.where((p) => !hiddenIds.contains(p.id)).toList(growable: false);
    final unseenById = await unseenByProjectId(
      projectIds: [for (final p in visible) p.id],
    );
    final projects = visible
        .map((p) => p.toSharedProject().copyWith(hasUnseenChanges: unseenById[p.id] ?? false))
        .toList();
    projects.sort(
      (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
    );
    return projects;
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

  Future<Project> openProject({required String path}) async {
    final pluginProject = await _plugin.getProject(path);
    await _projectsDao.unhideProject(projectId: pluginProject.id);
    return pluginProject.toSharedProject();
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
}
