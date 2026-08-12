import "package:injectable/injectable.dart";

import "../api/project_view_api.dart";

/// Layer-2 access to project-presence declarations.
@lazySingleton
class ProjectViewRepository({required ProjectViewApi api}) {
  final ProjectViewApi _api;

  this : _api = api;

  Future<void> sendProjectView({required String? projectId}) {
    return _api.sendProjectView(projectId: projectId);
  }
}
