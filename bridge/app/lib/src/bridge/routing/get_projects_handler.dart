import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /project` — returns all projects from the plugin.
class GetProjectsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetProjectsHandler(this._plugin) : super(HttpMethod.get, "/project");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final pluginProjects = await _plugin.getProjects();
    final projects = pluginProjects
        .map(
          (p) => Project(
            id: p.id,
            name: p.name,
            time: switch (p.time) {
              PluginProjectTime(:final created, :final updated) => ProjectTime(
                created: created,
                updated: updated,
              ),
              null => null,
            },
          ),
        )
        .toList();
    final body = jsonEncode(projects.map((p) => p.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }
}
