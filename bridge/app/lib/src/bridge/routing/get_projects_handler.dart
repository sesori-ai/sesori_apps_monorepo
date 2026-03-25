import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../hidden_projects_store.dart";
import "plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `GET /project` — returns all projects from the plugin.
class GetProjectsHandler extends RequestHandler {
  final BridgePlugin _plugin;
  final HiddenProjectsStore _hiddenStore;

  GetProjectsHandler(this._plugin, this._hiddenStore) : super(HttpMethod.get, "/project");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final pluginProjects = await _plugin.getProjects();
    final hiddenIds = await _hiddenStore.getHiddenProjectIds();
    final projects = pluginProjects
        .where((project) => !hiddenIds.contains(project.id))
        .map((p) => p.toSharedProject())
        .toList();
    final body = jsonEncode(projects.map((p) => p.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
