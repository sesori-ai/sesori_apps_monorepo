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
        method: HttpMethod.post,
        path: "/project/hide",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required ProjectIdRequest body,
  }) async {
    final projectId = body.projectId;
    requireNonEmpty(request: request, value: projectId, label: "project id");

    try {
      await _projectMutationService.hideProject(projectId: projectId);
    } on ScratchProjectHideRefusedException {
      throw buildErrorResponse(request: request, status: 409, message: "the No project project cannot be hidden");
    }

    return const SuccessEmptyResponse();
  }
}
