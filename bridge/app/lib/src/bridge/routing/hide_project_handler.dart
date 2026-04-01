import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "request_handler.dart";

/// Handles `POST /project/hide` — hides a project from listings.
///
/// Accepts a JSON body with `{"projectId": "..."}`. The project ID may contain
/// slashes (it can be a filesystem path), so it is passed in the body rather
/// than as a URL path parameter.
class HideProjectHandler extends BodyRequestHandler<ProjectIdRequest, SuccessEmptyResponse> {
  final ProjectsDao _store;

  HideProjectHandler(this._store)
    : super(
        HttpMethod.post,
        "/project/hide",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
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

    await _store.hideProject(projectId: projectId);

    return const SuccessEmptyResponse();
  }
}
