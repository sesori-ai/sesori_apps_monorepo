import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/plugin_project_mapper.dart";
import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `PATCH /project/name` — renames a project.
class RenameProjectHandler extends BodyRequestHandler<RenameProjectRequest, Project> {
  final BridgePluginApi _plugin;
  final ProjectRepository _projectRepository;

  RenameProjectHandler(this._plugin, {required ProjectRepository projectRepository})
    : _projectRepository = projectRepository,
      super(
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
    final updated = await _plugin.renameProject(
      projectId: body.projectId,
      name: body.name,
    );

    return updated.toSharedProject(
      hasUnseenChanges: await _projectRepository.projectHasUnseenChanges(projectId: body.projectId),
    );
  }
}
