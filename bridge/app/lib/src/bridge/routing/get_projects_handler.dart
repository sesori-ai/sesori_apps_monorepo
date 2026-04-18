import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "request_handler.dart";

/// Handles `GET /projects` — returns all projects from the plugin.
class GetProjectsHandler extends GetRequestHandler<Projects> {
  final ProjectRepository _projectRepository;

  GetProjectsHandler({required ProjectRepository projectRepository})
    : _projectRepository = projectRepository,
      super("/projects");

  @override
  Future<Projects> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projects = await _projectRepository.getProjects();
    return Projects(data: projects);
  }
}
