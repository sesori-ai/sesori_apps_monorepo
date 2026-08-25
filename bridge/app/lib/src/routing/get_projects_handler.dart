import "package:sesori_shared/sesori_shared.dart";

import "../services/project_activity_service.dart";
import "request_handler.dart";

/// Handles `GET /projects` — returns visible projects from the catalog.
class GetProjectsHandler({required final ProjectActivityService _projectActivityService})
    extends GetRequestHandler<Projects> {
  this : super("/projects");

  @override
  Future<Projects> handle(
    RelayRequest request,
  ) async {
    final projects = await _projectActivityService.getProjects();
    return Projects(data: projects);
  }
}
