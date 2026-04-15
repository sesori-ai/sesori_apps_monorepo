import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler extends BodyRequestHandler<ProjectPathRequest, Project> {
  final ProjectRepository _projectRepository;

  OpenProjectHandler({required ProjectRepository projectRepository})
    : _projectRepository = projectRepository,
      super(
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

    return _projectRepository.openProject(path: path);
  }
}
