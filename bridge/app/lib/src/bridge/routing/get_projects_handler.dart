import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `GET /projects` — returns all projects from the plugin.
class GetProjectsHandler extends GetRequestHandler<Projects> {
  final BridgePlugin _plugin;
  final ProjectsDao _hiddenStore;

  GetProjectsHandler(this._plugin, this._hiddenStore) : super("/projects");

  @override
  Future<Projects> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final pluginProjects = await _plugin.getProjects();
    final hiddenIds = await _hiddenStore.getHiddenProjectIds();
    final projects = pluginProjects
        .where((project) => !hiddenIds.contains(project.id))
        .map((p) => p.toSharedProject())
        .toList();

    // mutates the list to sort
    projects.sort(
      (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
    );
    return Projects(data: projects);
  }
}
