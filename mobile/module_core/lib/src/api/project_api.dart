import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class ProjectApi {
  final RelayHttpApiClient _client;

  ProjectApi(RelayHttpApiClient client) : _client = client;

  Future<ApiResponse<BranchListResponse>> listBranches({required String projectId}) {
    return _client.post(
      "/project/branches",
      fromJson: BranchListResponse.fromJson,
      body: ProjectIdRequest(projectId: projectId),
    );
  }
}
