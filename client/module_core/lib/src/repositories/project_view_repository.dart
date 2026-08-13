import "package:injectable/injectable.dart";

import "../api/project_view_api.dart";

/// Layer-2 access to project-presence declarations.
@lazySingleton
class ProjectViewRepository({required final ProjectViewApi _api}) {
  Future<void> sendProjectView({required String? projectId}) {
    return _api.sendProjectView(projectId: projectId);
  }
}
