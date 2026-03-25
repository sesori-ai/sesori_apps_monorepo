import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../hidden_projects_store.dart";
import "plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler extends RequestHandler {
  final BridgePlugin _plugin;
  final HiddenProjectsStore _hiddenStore;

  OpenProjectHandler(this._plugin, this._hiddenStore) : super(HttpMethod.post, "/project/open");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    // Parse request body
    final DiscoverProjectRequest discoverRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      discoverRequest = DiscoverProjectRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    final path = discoverRequest.path;

    // Validate path
    if (path.isEmpty) {
      return buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!path.startsWith("/")) {
      return buildErrorResponse(request, 400, "path must be absolute");
    }
    if (path.contains("..")) {
      return buildErrorResponse(request, 400, "path traversal not allowed");
    }

    // Verify directory exists
    final entity = FileSystemEntity.typeSync(path, followLinks: false);
    if (entity == FileSystemEntityType.notFound) {
      return buildErrorResponse(request, 404, "directory not found");
    }
    if (entity != FileSystemEntityType.directory) {
      return buildErrorResponse(request, 400, "path is not a directory");
    }

    // Discover via plugin (getProject triggers auto-discovery)
    final pluginProject = await _plugin.getProject(path);
    await _hiddenStore.unhideProject(projectId: pluginProject.id);

    final project = pluginProject.toSharedProject();

    return buildOkJsonResponse(request, jsonEncode(project.toJson()));
  }
}
