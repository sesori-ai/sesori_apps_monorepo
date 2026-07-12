import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../services/project_activity_service.dart";
import "../services/project_initialization_service.dart";
import "request_handler.dart";

/// Handles `POST /project/create` — creates a new project directory with git init.
class CreateProjectHandler extends BodyRequestHandler<ProjectPathRequest, Project> {
  final ProjectInitializationService _projectInitializationService;
  final ProjectActivityService _projectActivityService;

  CreateProjectHandler({
    required ProjectInitializationService projectInitializationService,
    required ProjectActivityService projectActivityService,
  }) : _projectInitializationService = projectInitializationService,
       _projectActivityService = projectActivityService,
       super(
         HttpMethod.post,
         "/project/create",
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

    try {
      await _projectInitializationService.initializeProject(path: path);
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $path");
    } on ProjectParentMissingException {
      throw buildErrorResponse(request, 400, "parent directory does not exist");
    } on ProjectDirectoryExistsException {
      throw buildErrorResponse(request, 409, "directory already exists");
    } on ProjectGitInitException {
      throw buildErrorResponse(request, 500, "git init failed");
    }

    return _projectActivityService.openProject(path: path);
  }
}
