import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /project/current` — returns project for a given project id.
class GetCurrentProjectHandler extends RequestHandler {
  static const _projectIdHeader = "x-project-id";
  final BridgePlugin _plugin;

  GetCurrentProjectHandler(this._plugin) : super(HttpMethod.get, "/project/current");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final projectId = findHeader(request.headers, _projectIdHeader);
    if (projectId == null || projectId.isEmpty) {
      return buildErrorResponse(request, 400, "missing $_projectIdHeader header");
    }

    final pluginProject = await _plugin.getProject(projectId);
    final project = Project(
      id: pluginProject.id,
      name: pluginProject.name,
      time: switch (pluginProject.time) {
        PluginProjectTime(:final created, :final updated) => ProjectTime(
          created: created,
          updated: updated,
          initialized: null,
        ),
        null => null,
      },
    );

    return buildOkJsonResponse(request, jsonEncode(project.toJson()));
  }
}
