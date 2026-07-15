import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class ProjectApi {
  final RelayHttpApiClient _client;

  ProjectApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<Projects>> listProjects() {
    return _client.get("/projects", fromJson: Projects.fromJson);
  }

  Future<ApiResponse<Project>> createProject({required String path}) {
    return _client.post(
      "/project/create",
      body: ProjectPathRequest(path: path),
      fromJson: Project.fromJson,
    );
  }

  Future<ApiResponse<Project>> discoverProject({required String path}) {
    return _client.post(
      "/project/open",
      body: ProjectPathRequest(path: path),
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

  Future<ApiResponse<BaseBranchResponse>> getBaseBranch({required String projectId}) {
    return _client.post(
      "/project/base-branch",
      body: ProjectIdRequest(projectId: projectId),
      fromJson: BaseBranchResponse.fromJson,
    );
  }

  Future<ApiResponse<SessionListResponse>> listSessions({
    required String projectId,
    required bool waitForPrData,
  }) {
    return _client.post(
      "/sessions",
      fromJson: SessionListResponse.fromJson,
      body: SessionListRequest(
        projectId: projectId,
        start: null,
        limit: null,
        waitForPrData: waitForPrData,
      ),
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
