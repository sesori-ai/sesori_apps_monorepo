import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/project_api.dart";

@lazySingleton
class ProjectRepository {
  final ProjectApi _api;

  ProjectRepository({required ProjectApi api}) : _api = api;

  Future<ApiResponse<Projects>> listProjects() {
    return _api.listProjects();
  }

  Future<ApiResponse<SessionListResponse>> listSessions({required String projectId}) {
    return _api.listSessions(projectId: projectId);
  }

  Future<ProjectSessionContext?> findSessionContext({required String sessionId}) async {
    final projectsResponse = await _api.listProjects();
    switch (projectsResponse) {
      case ErrorResponse<Projects>():
        return null;
      case final SuccessResponse<Projects> success:
        final projects = success.data.data;
        final sessionContexts = await Future.wait(
          projects.map((project) async {
            final sessionsResponse = await _api.listSessions(projectId: project.id);
            final session = switch (sessionsResponse) {
              SuccessResponse(:final data) => data.items.firstWhereOrNull((item) => item.id == sessionId),
              ErrorResponse() => null,
            };

            if (session != null) {
              return ProjectSessionContext(projectId: project.id, sessionTitle: session.title);
            }

            return null;
          }),
        );

        return sessionContexts.nonNulls.firstOrNull;
    }
  }
}

class ProjectSessionContext {
  final String projectId;
  final String? sessionTitle;

  const ProjectSessionContext({required this.projectId, required this.sessionTitle});
}
