import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `PATCH /project/name` — renames a project.
///
/// Routes through [ProjectRepository], which owns the aggregate display name
/// and stamps unseen state on the returned project without calling a plugin.
class RenameProjectHandler({required final ProjectRepository _projectRepository})
    extends BodyRequestHandler<RenameProjectRequest, Project> {
  this
    : super(
        method: HttpMethod.patch,
        path: "/project/name",
        fromJson: RenameProjectRequest.fromJson,
      );

  @override
  Future<Project> handle({
    required RelayRequest request,
    required RenameProjectRequest body,
  }) async {
    final name = body.name.trim();
    if (name.isEmpty) {
      throw buildErrorResponse(request: request, status: 400, message: "Bad Request: project name must not be empty");
    }
    return await _projectRepository.renameProject(
      projectId: body.projectId,
      name: name,
    );
  }
}
