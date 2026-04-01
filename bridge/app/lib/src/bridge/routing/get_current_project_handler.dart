import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /project/current` — returns project for a given project id.
class GetCurrentProjectHandler extends BodyRequestHandler<ProjectIdRequest, Project> {
  final BridgePlugin _plugin;

  GetCurrentProjectHandler(this._plugin)
    : super(
        HttpMethod.post,
        "/project/current",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<Project> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    if (projectId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty project id");
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

    return project;
  }
}
