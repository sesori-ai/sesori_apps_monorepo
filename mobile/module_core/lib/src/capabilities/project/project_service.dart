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
      fromJson: (json) => switch (json) {
        final List<dynamic> list =>
          list
              .map(
                (e) => switch (e) {
                  final Map<String, dynamic> map => Project.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType}"),
      },
    );
  }

  /// Returns the project matching the requested project ID.
  Future<ApiResponse<Project>> getCurrentProject({required String projectId}) {
    return _client.get(
      "/project/current",
      fromJson: (json) => switch (json) {
        final Map<String, dynamic> map => Project.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType}"),
      },
      headers: {"x-project-id": projectId},
    );
  }
}
