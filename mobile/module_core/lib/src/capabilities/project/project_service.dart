import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/client/relay_http_client.dart";

@lazySingleton
class ProjectService {
  final RelayHttpApiClient _client;

  ProjectService(RelayHttpApiClient client) : _client = client;

  Future<ApiResponse<List<Project>>> listProjects() {
    return _client.get(
      "/project",
      // ignore: no_slop_linter/avoid_dynamic_type, json parsing
      fromJson: (json) => (json as List)
          .map(
            // ignore: no_slop_linter/avoid_dynamic_type, json parsing
            (e) => Project.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Returns the project the server resolved for the current request directory.
  Future<ApiResponse<Project>> getCurrentProject() {
    return _client.get(
      "/project/current",
      fromJson: (json) => Project.fromJson(json as Map<String, dynamic>),
    );
  }
}
