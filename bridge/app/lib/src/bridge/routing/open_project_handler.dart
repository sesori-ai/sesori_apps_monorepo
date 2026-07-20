import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../services/project_activity_service.dart";
import "../services/project_initialization_service.dart";
import "request_handler.dart";

/// Handles `POST /project/open` — opens an existing directory as a project.
class OpenProjectHandler extends BodyRequestHandler<OpenProjectRequest, Project> {
  final FilesystemRepository _filesystemRepository;
  final ProjectInitializationService _projectInitializationService;
  final ProjectActivityService _projectActivityService;

  OpenProjectHandler({
    required FilesystemRepository filesystemRepository,
    required ProjectInitializationService projectInitializationService,
    required ProjectActivityService projectActivityService,
  }) : _filesystemRepository = filesystemRepository,
       _projectInitializationService = projectInitializationService,
       _projectActivityService = projectActivityService,
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

    final FilesystemEntityKind kind;
    try {
      kind = _filesystemRepository.classifyPath(path: path);
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $path");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("OpenProjectHandler: failed to classify $path", error, stackTrace);
      throw buildErrorResponse(request, 500, "failed to open directory");
    }

    switch (kind) {
      case FilesystemEntityKind.notFound:
        throw buildErrorResponse(request, 404, "directory not found");
      case FilesystemEntityKind.notDirectory:
        throw buildErrorResponse(request, 400, "path is not a directory");
      case FilesystemEntityKind.directory:
        final preparation = await _projectInitializationService.prepareExistingProject(
          path: path,
          gitAction: body.gitAction,
        );
        switch (preparation) {
          case ExistingProjectPreparationOutcome.gitChoiceRequired:
            throw buildErrorResponse(request, 428, "Git setup choice required");
          case ExistingProjectPreparationOutcome.ready:
            return _projectActivityService.openProject(path: path);
        }
    }
  }
}
