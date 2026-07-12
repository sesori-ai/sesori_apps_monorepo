import "package:sesori_shared/sesori_shared.dart";

import "../services/project_activity_service.dart";
import "request_handler.dart";

/// Handles `GET /projects` — returns all projects from the plugin.
class GetProjectsHandler extends GetRequestHandler<Projects> {
  final ProjectActivityService _projectActivityService;

  GetProjectsHandler({required ProjectActivityService projectActivityService})
    : _projectActivityService = projectActivityService,
      super("/projects");

  @override
  Future<Projects> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projects = await _projectActivityService.getProjects();
    return Projects(data: projects);
  }
}
