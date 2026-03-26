import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../persistence/hidden_projects_store.dart";
import "request_handler.dart";

/// Handles `POST /project/hide` — hides a project from listings.
///
/// Accepts a JSON body with `{"projectId": "..."}`. The project ID may contain
/// slashes (it can be a filesystem path), so it is passed in the body rather
/// than as a URL path parameter.
class HideProjectHandler extends RequestHandler {
  final HiddenProjectsStore _store;

  HideProjectHandler(this._store) : super(HttpMethod.post, "/project/hide");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final String projectId;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      final map = switch (decoded) {
        final Map<String, dynamic> m => m,
        _ => throw const FormatException("invalid JSON body"),
      };
      final id = map["projectId"];
      if (id is! String || id.isEmpty) {
        return buildErrorResponse(request, 400, "missing or empty projectId");
      }
      projectId = id;
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
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
