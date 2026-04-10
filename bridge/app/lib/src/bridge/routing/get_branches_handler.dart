import "package:sesori_shared/sesori_shared.dart";

import "../repositories/branch_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/branches` — returns the list of branches for a project.
class GetBranchesHandler extends BodyRequestHandler<ProjectIdRequest, BranchListResponse> {
  final BranchRepository _branchRepository;

  GetBranchesHandler(this._branchRepository)
    : super(
        HttpMethod.post,
        "/project/branches",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<BranchListResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;

    return _branchRepository.listBranches(projectPath: projectId);
  }
}
