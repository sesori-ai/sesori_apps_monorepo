import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/client/relay_http_client.dart";

@lazySingleton
class ProjectService {
  final RelayHttpApiClient _client;

  ProjectService(RelayHttpApiClient client) : _client = client;

  Future<ApiResponse<Projects>> listProjects() {
    return _client.get(
      "/projects",
      fromJson: Projects.fromJson,
    );
  }

  /// Returns the project matching the requested project ID.
  Future<ApiResponse<Project>> getProject({required String projectId}) {
    return _client.post(
      "/project/current",
      fromJson: Project.fromJson,
      body: ProjectIdRequest(projectId: projectId),
    );
  }

  /// Creates a new project at the specified path.
  Future<ApiResponse<Project>> createProject({required String path}) {
    return _client.post(
      "/project/create",
      body: ProjectPathRequest(path: path),
      fromJson: Project.fromJson,
    );
  }

  /// Opens an existing directory as a project.
  Future<ApiResponse<Project>> discoverProject({required String path}) {
    return _client.post(
      "/project/open",
      body: ProjectPathRequest(path: path),
      fromJson: Project.fromJson,
    );
  }

  /// Hides the project with the given [projectId] on the bridge.
  Future<ApiResponse<void>> hideProject({required String projectId}) {
    return _client.post(
      "/project/hide",
      body: ProjectIdRequest(projectId: projectId),
      fromJson: SuccessEmptyResponse.fromJson,
    );
  }

  /// Gets filesystem suggestions for the given prefix.
  ///
  /// When [prefix] is empty the query parameter is omitted, which tells the
  /// bridge to return the user's home-directory children.
  Future<ApiResponse<FilesystemSuggestions>> getFilesystemSuggestions({
    required String? prefix,
  }) {
    return _client.post(
      "/filesystem/suggestions",
      body: FilesystemSuggestionsRequest(prefix: prefix, maxResults: 50),
      fromJson: FilesystemSuggestions.fromJson,
    );
  }

  /// Returns the base branch name for the given project, or `null` if
  /// the project has no base branch configured.
  Future<ApiResponse<BaseBranchResponse>> getBaseBranch({required String projectId}) {
    return _client.post(
      "/project/base-branch",
      body: ProjectIdRequest(projectId: projectId),
      fromJson: BaseBranchResponse.fromJson,
    );
  }

  /// Renames the project with the given [projectId] to [name].
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
