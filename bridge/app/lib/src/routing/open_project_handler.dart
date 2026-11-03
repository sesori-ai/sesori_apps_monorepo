import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../services/project_mutation_service.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler({required final ProjectMutationService _projectMutationService})
    extends BodyRequestHandler<OpenProjectRequest, Project> {
  this
    : super(
        method: HttpMethod.post,
        path: "/project/open",
        fromJson: OpenProjectRequest.fromJson,
      );

  @override
  Future<Project> handle({
    required RelayRequest request,
    required OpenProjectRequest body,
  }) async {
    final path = body.path;

    if (path.isEmpty) {
      throw buildErrorResponse(request: request, status: 400, message: "path must not be empty");
    }
    if (!p.isAbsolute(path)) {
      throw buildErrorResponse(request: request, status: 400, message: "path must be absolute");
    }
    if (p.split(path).contains("..")) {
      throw buildErrorResponse(request: request, status: 400, message: "path traversal not allowed");
    }

    final OpenProjectOutcome outcome;
    try {
      outcome = await _projectMutationService.openProject(
        path: path,
        gitAction: body.gitAction,
      );
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request: request, status: 403, message: "permission denied: $path");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("OpenProjectHandler: failed to open project at $path", error, stackTrace);
      throw buildErrorResponse(request: request, status: 500, message: "failed to open directory");
    }

    switch (outcome) {
      case OpenProjectDirectoryNotFound():
        throw buildErrorResponse(request: request, status: 404, message: "directory not found");
      case OpenProjectPathNotDirectory():
        throw buildErrorResponse(request: request, status: 400, message: "path is not a directory");
      case OpenProjectGitChoiceRequired():
        throw buildErrorResponse(request: request, status: 428, message: "Git setup choice required");
      case OpenProjectSuccess(:final project):
        return project;
    }
  }
}
