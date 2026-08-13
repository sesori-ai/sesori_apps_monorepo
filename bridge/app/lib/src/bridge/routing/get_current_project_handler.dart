import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/current` — returns project for a given project id.
class GetCurrentProjectHandler({required final ProjectRepository _projectRepository})
    extends BodyRequestHandler<ProjectIdRequest, Project> {
  this
    : super(
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

    return await _projectRepository.getProject(projectId: projectId);
  }
}
