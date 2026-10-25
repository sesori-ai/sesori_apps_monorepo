import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `POST /project/base-branch` — returns the project's git context:
/// its configured base branch and the repository slug of its git remote.
class GetBaseBranchHandler({required final ProjectRepository _projectRepository})
    extends BodyRequestHandler<ProjectIdRequest, BaseBranchResponse> {
  // COMPATIBILITY 2026-10-25 (v1.9.2): Released apps read the git context here; current apps no longer
  // call it. Remove once no supported app release calls /project/base-branch.
  this
    : super(
        HttpMethod.post,
        "/project/base-branch",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<BaseBranchResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
  }) async {
    final projectId = body.projectId;

    final (baseBranch, remote) = await (
      _projectRepository.getBaseBranch(projectId: projectId),
      _projectRepository.getRemoteIdentity(projectId: projectId),
    ).wait;

    return BaseBranchResponse(
      baseBranch: baseBranch,
      repoSlug: remote?.slug,
      repoHost: remote?.host,
    );
  }
}
