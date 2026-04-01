import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "request_handler.dart";

/// Handles `PUT /project/base-branch` — sets the base branch for a project.
///
/// Accepts a JSON body matching [SetBaseBranchRequest]. Both [projectId] and
/// [baseBranch] are required non-empty strings.
class SetBaseBranchHandler extends BodyRequestHandler<SetBaseBranchRequest, SuccessEmptyResponse> {
  final ProjectsDao _projectsDao;

  SetBaseBranchHandler(this._projectsDao)
    : super(
        HttpMethod.put,
        "/project/base-branch",
        fromJson: SetBaseBranchRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SetBaseBranchRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    if (projectId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty project id");
    }
    final baseBranch = body.baseBranch;
    if (baseBranch.isEmpty) {
      throw buildErrorResponse(request, 400, "empty base branch");
    }

    await _projectsDao.setBaseBranch(
      projectId: projectId,
      baseBranch: baseBranch,
    );

    return const SuccessEmptyResponse();
  }
}
