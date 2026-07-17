import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/current` — returns project for a given project id.
class GetCurrentProjectHandler extends BodyRequestHandler<ProjectIdRequest, Project> {
  final ProjectRepository _projectRepository;

  GetCurrentProjectHandler({required ProjectRepository projectRepository})
    : _projectRepository = projectRepository,
      super(
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

    return _projectRepository.getProject(projectId: projectId);
  }
}
