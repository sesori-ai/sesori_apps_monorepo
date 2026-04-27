import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/daos/projects_dao.dart";
import "mappers/plugin_project_mapper.dart";

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

  ProjectRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
  }) : _plugin = plugin,
       _projectsDao = projectsDao;

  Future<List<Project>> getProjects() async {
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
