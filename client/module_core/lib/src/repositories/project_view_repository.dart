import "package:injectable/injectable.dart";

import "../api/project_view_api.dart";

/// Layer-2 access to project-presence declarations.
@lazySingleton
class ProjectViewRepository {
  final ProjectViewApi _api;

  ProjectViewRepository({required ProjectViewApi api}) : _api = api;

  Future<void> sendProjectView({required String? projectId}) {
    return _api.sendProjectView(projectId: projectId);
  }
}
