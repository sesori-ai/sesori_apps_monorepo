import "package:sesori_shared/sesori_shared.dart";

import "../services/current_project_service.dart";
import "request_handler.dart";

/// Handles `POST /project/current` — returns project for a given project id.
class GetCurrentProjectHandler({required final CurrentProjectService _currentProjectService})
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
  }) async {
    final projectId = body.projectId;
    requireNonEmpty(request: request, value: projectId, label: "project id");

    return await _currentProjectService.getCurrentProject(projectId: projectId);
  }
}
