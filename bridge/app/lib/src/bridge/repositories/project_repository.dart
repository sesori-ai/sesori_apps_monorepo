import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/daos/projects_dao.dart";
import "../persistence/database.dart";
import "mappers/plugin_project_mapper.dart";

/// Aggregates plugin project data with local persistence state.
///
/// Fetches projects from the plugin, persists each project ID to the local
/// database (so hide/unhide state is preserved), filters hidden projects,
/// and returns the visible list sorted by [Project.time.updated] descending.
class ProjectRepository {
  final BridgePlugin _plugin;
  final ProjectsDao _projectsDao;
  final AppDatabase _db;

  ProjectRepository({
    required BridgePlugin plugin,
    required ProjectsDao projectsDao,
    required AppDatabase db,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _db = db;

  Future<List<Project>> getProjects() async {
    final pluginProjects = await _plugin.getProjects();
    await _db.transaction(() async {
      for (final p in pluginProjects) {
        await _projectsDao.insertProjectIfMissing(projectId: p.id);
      }
    });
    final hiddenIds = await _projectsDao.getHiddenProjectIds();
    final projects = pluginProjects.where((p) => !hiddenIds.contains(p.id)).map((p) => p.toSharedProject()).toList();
    projects.sort(
      (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
    );
    return projects;
  }
}
