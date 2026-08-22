import "package:sesori_shared/sesori_shared.dart";

import "../services/project_mutation_service.dart";
import "request_handler.dart";

/// Handles `POST /project/hide` — hides a project from listings.
///
/// Accepts a JSON body with `{"projectId": "..."}`. The project ID may contain
/// slashes (it can be a filesystem path), so it is passed in the body rather
/// than as a URL path parameter.
class HideProjectHandler({required final ProjectMutationService _projectMutationService})
    extends BodyRequestHandler<ProjectIdRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/project/hide",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
  }) async {
    final projectId = body.projectId;
    requireNonEmpty(request, projectId, "project id");

    await _projectMutationService.hideProject(projectId: projectId);

    return const SuccessEmptyResponse();
  }
}
