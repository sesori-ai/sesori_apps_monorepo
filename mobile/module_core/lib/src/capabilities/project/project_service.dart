import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/client/relay_http_client.dart";

@lazySingleton
class ProjectService {
  final RelayHttpApiClient _client;

  ProjectService(RelayHttpApiClient client) : _client = client;

  Future<ApiResponse<List<Project?>>> listProjects() {
    return _client.get(
      "/project",
      fromJson: (json) => switch (json) {
        final List<Object?> list =>
          list
              .map<Project?>(
                (e) => switch (e) {
                  // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
                  final Map<String, dynamic> map => Project.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType.toString()}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType.toString()}"),
      },
    );
  }

  /// Returns the project matching the requested project ID.
  Future<ApiResponse<Project>> getProject({required String projectId}) {
    return _client.get(
      "/project/current",
      fromJson: (json) => switch (json) {
        // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
        final Map<String, dynamic> map => Project.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType.toString()}"),
      },
      headers: {"x-project-id": projectId},
    );
  }

  /// Creates a new project at the specified path.
  Future<ApiResponse<Project>> createProject({required String path}) {
    return _client.post(
      "/project/create",
      body: {"path": path},
      fromJson: (json) => switch (json) {
        // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
        final Map<String, dynamic> map => Project.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType.toString()}"),
      },
    );
  }

  /// Opens an existing directory as a project.
  Future<ApiResponse<Project>> discoverProject({required String path}) {
    return _client.post(
      "/project/open",
      body: {"path": path},
      fromJson: (json) => switch (json) {
        // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
        final Map<String, dynamic> map => Project.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType.toString()}"),
      },
    );
  }

  /// Hides the project with the given [projectId] on the bridge.
  Future<ApiResponse<void>> hideProject({required String projectId}) {
    return _client.post(
      "/project/hide",
      body: {"projectId": projectId},
      fromJson: (_) {},
    );
  }

  /// Gets filesystem suggestions for the given prefix.
  ///
  /// When [prefix] is empty the query parameter is omitted, which tells the
  /// bridge to return the user's home-directory children.
  Future<ApiResponse<List<FilesystemSuggestion>>> getFilesystemSuggestions({
    required String prefix,
  }) {
    return _client.get(
      "/filesystem/suggestions",
      queryParameters: prefix.isEmpty ? null : {"prefix": prefix},
      fromJson: (json) => switch (json) {
        final List<Object?> list =>
          list
              .map(
                (e) => switch (e) {
                  // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
                  final Map<String, dynamic> map => FilesystemSuggestion.fromJson(map),
                  _ => throw FormatException("expected map, got ${e.runtimeType.toString()}"),
                },
              )
              .toList(),
        _ => throw FormatException("expected list, got ${json.runtimeType.toString()}"),
      },
    );
  }

  /// Returns the base branch name for the given project, or `null` if
  /// the project has no base branch configured.
  Future<ApiResponse<String?>> getBaseBranch({required String projectId}) {
    return _client.get(
      "/project/base-branch",
      fromJson: (json) => switch (json) {
        // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
        final Map<String, dynamic> map => switch (map["baseBranch"]) {
          final String baseBranch => baseBranch,
          null => null,
          _ => throw const FormatException("expected baseBranch as string or null"),
        },
        _ => throw FormatException("expected map, got ${json.runtimeType.toString()}"),
      },
      headers: {"x-project-id": projectId},
    );
  }

  /// Renames the project with the given [projectId] to [name].
  Future<ApiResponse<Project>> renameProject({
    required String projectId,
    required String name,
  }) {
    return _client.patch(
      "/project/name",
      body: RenameProjectRequest(projectId: projectId, name: name).toJson(),
      fromJson: (json) => switch (json) {
        // ignore: no_slop_linter/avoid_dynamic_type, JSON parsing requires dynamic
        final Map<String, dynamic> map => Project.fromJson(map),
        _ => throw FormatException("expected map, got ${json.runtimeType.toString()}"),
      },
    );
  }
}
