import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "../repositories/mappers/plugin_project_mapper.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler extends BodyRequestHandler<ProjectPathRequest, Project> {
  final BridgePlugin _plugin;
  final ProjectsDao _hiddenStore;

  OpenProjectHandler(this._plugin, this._hiddenStore)
    : super(
        HttpMethod.post,
        "/project/open",
        fromJson: ProjectPathRequest.fromJson,
      );

  @override
  Future<Project> handle(
    RelayRequest request, {
    required ProjectPathRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final path = body.path;

    // Validate path
    if (path.isEmpty) {
      throw buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!path.startsWith("/")) {
      throw buildErrorResponse(request, 400, "path must be absolute");
    }
    if (path.contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    // Verify directory exists
    final entity = FileSystemEntity.typeSync(path, followLinks: false);
    if (entity == FileSystemEntityType.notFound) {
      throw buildErrorResponse(request, 404, "directory not found");
    }
    if (entity != FileSystemEntityType.directory) {
      throw buildErrorResponse(request, 400, "path is not a directory");
    }

    // Discover via plugin (getProject triggers auto-discovery)
    final pluginProject = await _plugin.getProject(path);
    await _hiddenStore.unhideProject(projectId: pluginProject.id);

    final project = pluginProject.toSharedProject();

    return project;
  }
}
