import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "request_handler.dart";

/// Handles `PUT /project/base-branch` — sets the base branch for a project.
///
/// Accepts a JSON body matching [SetBaseBranchRequest]. Pass `null` for
/// [baseBranch] to reset the configured branch to the default.
class SetBaseBranchHandler extends RequestHandler {
  final ProjectsDao _projectsDao;

  SetBaseBranchHandler(this._projectsDao) : super(HttpMethod.put, "/project/base-branch");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final SetBaseBranchRequest setRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      setRequest = SetBaseBranchRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    await _projectsDao.setBaseBranch(
      projectId: setRequest.projectId,
      baseBranch: setRequest.baseBranch,
    );

    return buildOkJsonResponse(request, jsonEncode({"success": true}));
  }
}
