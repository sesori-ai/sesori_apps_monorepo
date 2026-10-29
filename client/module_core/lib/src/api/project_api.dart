import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class ProjectApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<Projects>> listProjects() {
    // Heavy users have hundreds of projects; decode off the UI isolate.
    return _client.getDecodedInBackground(path: "/projects", fromJson: Projects.fromJson);
  }

  Future<ApiResponse<Project>> discoverProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) {
    return _client.post(
      "/project/open",
      body: OpenProjectRequest(path: path, gitAction: gitAction),
      fromJson: Project.fromJson,
    );
  }

  Future<ApiResponse<Project>> getProject({required String projectId}) {
    return _client.post(
      "/project/current",
      body: ProjectIdRequest(projectId: projectId),
      fromJson: Project.fromJson,
    );
  }

  Future<ApiResponse<void>> hideProject({required String projectId}) {
    return _client.post(
      "/project/hide",
      body: ProjectIdRequest(projectId: projectId),
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  Future<ApiResponse<SessionListResponse>> listSessions({required String projectId}) {
    // A project can hold thousands of sessions; decode off the UI isolate.
    return _client.postDecodedInBackground(
      path: "/sessions",
      fromJson: SessionListResponse.fromJson,
      body: SessionListRequest(
        projectId: projectId,
        start: null,
        limit: null,
      ),
      sensitiveResponse: false,
    );
  }

  Future<ApiResponse<Project>> renameProject({
    required String projectId,
    required String name,
  }) {
    return _client.patch(
      "/project/name",
      body: RenameProjectRequest(projectId: projectId, name: name),
      fromJson: Project.fromJson,
    );
  }
}
