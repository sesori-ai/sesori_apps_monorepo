import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "request_handler.dart";

/// Handles `GET /project/base-branch` — returns the base branch for a project.
///
/// Requires `x-project-id` header. Returns `{"baseBranch": "develop"}` or
/// `{"baseBranch": null}` when no base branch has been configured.
class GetBaseBranchHandler extends RequestHandler {
  static const _projectIdHeader = "x-project-id";
  final ProjectsDao _projectsDao;

  GetBaseBranchHandler(this._projectsDao) : super(HttpMethod.get, "/project/base-branch");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final projectId = findHeader(request.headers, _projectIdHeader);
    if (projectId == null || projectId.isEmpty) {
      return buildErrorResponse(request, 400, "missing $_projectIdHeader header");
    }

    final baseBranch = await _projectsDao.getBaseBranch(projectId: projectId);

    final body = jsonEncode({"baseBranch": baseBranch});
    return buildOkJsonResponse(request, body);
  }
}
