import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `PATCH /project/name` — renames a project.
///
/// Routes through [ProjectRepository] (not the plugin) so the bridge-derived
/// path can persist a display-name override while the native path still
/// delegates the rename to the backend; the repository also stamps the
/// project's unseen state on the returned model.
class RenameProjectHandler extends BodyRequestHandler<RenameProjectRequest, Project> {
  final ProjectRepository _projectRepository;

  RenameProjectHandler(this._projectRepository)
    : super(
        HttpMethod.patch,
        "/project/name",
        fromJson: RenameProjectRequest.fromJson,
      );

  @override
  Future<Project> handle(
    RelayRequest request, {
    required RenameProjectRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _projectRepository.renameProject(
      projectId: body.projectId,
      name: body.name,
    );
  }
}
