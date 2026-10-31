import "package:sesori_shared/sesori_shared.dart";

import "../services/project_details_service.dart";
import "request_handler.dart";

/// Handles `POST /project/current` — returns project for a given project id.
/// The route keeps its name for released apps; nothing on the bridge tracks a
/// current project.
class GetCurrentProjectHandler({required final ProjectDetailsService _projectDetailsService})
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

    return await _projectDetailsService.getProject(projectId: projectId);
  }
}
