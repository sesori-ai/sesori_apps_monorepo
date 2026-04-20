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

  Future<ApiResponse<SessionListResponse>> listSessions({required String projectId}) {
    return _client.post(
      "/sessions",
      fromJson: SessionListResponse.fromJson,
      body: SessionListRequest(projectId: projectId, start: null, limit: null),
    );
  }
}
