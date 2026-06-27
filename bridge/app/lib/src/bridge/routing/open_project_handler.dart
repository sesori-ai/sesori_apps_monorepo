import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler extends BodyRequestHandler<ProjectPathRequest, Project> {
  final FilesystemRepository _filesystemRepository;
  final ProjectRepository _projectRepository;

  OpenProjectHandler({
    required FilesystemRepository filesystemRepository,
    required ProjectRepository projectRepository,
  }) : _filesystemRepository = filesystemRepository,
       _projectRepository = projectRepository,
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

    if (path.isEmpty) {
      throw buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!path.startsWith("/")) {
      throw buildErrorResponse(request, 400, "path must be absolute");
    }
    if (path.contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    final FilesystemEntityKind kind;
    try {
      kind = _filesystemRepository.classifyPath(path: path);
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $path");
    } on FileSystemException catch (error) {
      Log.w("OpenProjectHandler: failed to classify $path", error);
      throw buildErrorResponse(request, 500, "failed to open directory");
    }

    switch (kind) {
      case FilesystemEntityKind.notFound:
        throw buildErrorResponse(request, 404, "directory not found");
      case FilesystemEntityKind.notDirectory:
        throw buildErrorResponse(request, 400, "path is not a directory");
      case FilesystemEntityKind.directory:
        return _projectRepository.openProject(path: path);
    }
  }
}
