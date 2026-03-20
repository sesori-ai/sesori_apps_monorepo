import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /project/current` — returns project for a given worktree.
class GetCurrentProjectHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetCurrentProjectHandler(this._plugin) : super(HttpMethod.get, "/project/current");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final worktree = findHeader(request.headers, "x-opencode-directory");
    if (worktree == null || worktree.isEmpty) {
      return buildErrorResponse(request, 400, "missing x-opencode-directory header");
    }

    final pluginProject = await _plugin.getCurrentProject(worktree);
    final project = Project(
      id: pluginProject.id,
      worktree: pluginProject.worktree,
      name: pluginProject.name,
      time: switch (pluginProject.time) {
        PluginProjectTime(:final created, :final updated) => ProjectTime(
          created: created,
          updated: updated,
        ),
        null => null,
      },
    );

    return buildOkJsonResponse(request, jsonEncode(project.toJson()));
  }
}
