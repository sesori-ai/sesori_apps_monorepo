import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/base-branch` — returns the base branch for a project.
class GetBaseBranchHandler extends BodyRequestHandler<ProjectIdRequest, BaseBranchResponse> {
  final ProjectRepository _projectRepository;

  GetBaseBranchHandler({required ProjectRepository projectRepository})
    : _projectRepository = projectRepository,
      super(
        HttpMethod.post,
        "/project/base-branch",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<BaseBranchResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;

    final baseBranch = await _projectRepository.getBaseBranch(projectId: projectId);

    return BaseBranchResponse(baseBranch: baseBranch);
  }
}
