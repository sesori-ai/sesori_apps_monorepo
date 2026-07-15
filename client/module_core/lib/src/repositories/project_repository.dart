import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/filesystem_api.dart";
import "../api/project_api.dart";

@lazySingleton
class ProjectRepository {
  final ProjectApi _api;
  final FilesystemApi _filesystemApi;

  ProjectRepository({
    required ProjectApi api,
    required FilesystemApi filesystemApi,
  }) : _api = api,
       _filesystemApi = filesystemApi;

  Future<ApiResponse<Projects>> listProjects() {
    return _api.listProjects();
  }

  Future<ApiResponse<Project>> createProject({required String path}) {
    return _api.createProject(path: path);
  }

  Future<ApiResponse<Project>> discoverProject({required String path}) {
    return _api.discoverProject(path: path);
  }

  Future<ApiResponse<void>> hideProject({required String projectId}) {
    return _api.hideProject(projectId: projectId);
  }

  Future<ApiResponse<FilesystemSuggestions>> getFilesystemSuggestions({
    required String? prefix,
  }) {
    return _filesystemApi.getSuggestions(prefix: prefix);
  }

  Future<ApiResponse<BaseBranchResponse>> getBaseBranch({required String projectId}) {
    return _api.getBaseBranch(projectId: projectId);
  }

  Future<ApiResponse<SessionListResponse>> listSessions({
    required String projectId,
    required bool waitForPrData,
  }) {
    return _api.listSessions(
      projectId: projectId,
      waitForPrData: waitForPrData,
    );
  }

  Future<ApiResponse<Project>> renameProject({
    required String projectId,
    required String name,
  }) {
    return _api.renameProject(projectId: projectId, name: name);
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
            final sessionsResponse = await _api.listSessions(
              projectId: project.id,
              waitForPrData: false,
            );
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
