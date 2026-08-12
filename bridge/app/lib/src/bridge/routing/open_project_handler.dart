import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../services/project_mutation_service.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler({required ProjectMutationService projectMutationService}) extends BodyRequestHandler<OpenProjectRequest, Project> {
  final ProjectMutationService _projectMutationService;

  this
    : _projectMutationService = projectMutationService,
      super(
        HttpMethod.post,
        "/project/open",
        fromJson: OpenProjectRequest.fromJson,
      );

  @override
  Future<Project> handle(
    RelayRequest request, {
    required OpenProjectRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final path = body.path;

    if (path.isEmpty) {
      throw buildErrorResponse(request, 400, "path must not be empty");
    }
    if (!p.isAbsolute(path)) {
      throw buildErrorResponse(request, 400, "path must be absolute");
    }
    if (p.split(path).contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    final OpenProjectOutcome outcome;
    try {
      outcome = await _projectMutationService.openProject(
        path: path,
        gitAction: body.gitAction,
      );
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $path");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("OpenProjectHandler: failed to open project at $path", error, stackTrace);
      throw buildErrorResponse(request, 500, "failed to open directory");
    }

    switch (outcome) {
      case OpenProjectDirectoryNotFound():
        throw buildErrorResponse(request, 404, "directory not found");
      case OpenProjectPathNotDirectory():
        throw buildErrorResponse(request, 400, "path is not a directory");
      case OpenProjectGitChoiceRequired():
        throw buildErrorResponse(request, 428, "Git setup choice required");
      case OpenProjectSuccess(:final project):
        return project;
    }
  }
}
