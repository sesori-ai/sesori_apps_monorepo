import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `PUT /project/base-branch` — sets the base branch for a project.
///
/// Accepts a JSON body matching [SetBaseBranchRequest]. Both [projectId] and
/// [baseBranch] are required non-empty strings.
class SetBaseBranchHandler({required final ProjectRepository _projectRepository})
    extends BodyRequestHandler<SetBaseBranchRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.put,
        "/project/base-branch",
        fromJson: SetBaseBranchRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required SetBaseBranchRequest body,
  }) async {
    final projectId = body.projectId;
    requireNonEmpty(request: request, value: projectId, label: "project id");
    final baseBranch = body.baseBranch;
    requireNonEmpty(request: request, value: baseBranch, label: "base branch");

    await _projectRepository.setBaseBranch(
      projectId: projectId,
      baseBranch: baseBranch,
    );

    return const SuccessEmptyResponse();
  }
}
