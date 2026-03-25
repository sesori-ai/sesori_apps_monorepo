import "package:sesori_shared/sesori_shared.dart";

import "hidden_projects_store.dart";
import "request_handler.dart";

const _idParam = "id";

/// Handles `DELETE /project/:id` — hides a project from listings.
class CloseProjectHandler extends RequestHandler {
  final HiddenProjectsStore _store;

  CloseProjectHandler(this._store) : super(HttpMethod.delete, "/project/:$_idParam");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final projectId = pathParams[_idParam];
    if (projectId == null || projectId.isEmpty) {
      return buildErrorResponse(request, 400, "missing project id");
    }

    await _store.hideProject(projectId: projectId);

    return RelayResponse(
      id: request.id,
      status: 200,
      headers: {},
      body: null,
    );
  }
}
