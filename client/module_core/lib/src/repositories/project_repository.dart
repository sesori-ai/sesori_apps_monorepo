import "package:injectable/injectable.dart";
import "package:path/path.dart" as p;
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/filesystem_api.dart";
import "../api/project_api.dart";

@lazySingleton
class ProjectRepository({
  required final ProjectApi _api,
  required final FilesystemApi _filesystemApi,
}) {
  Future<ApiResponse<Projects>> listProjects() {
    return _api.listProjects();
  }

  String? parentHostPath({required String path}) {
    final parent = _hostPathContext(path).dirname(path);
    return parent == path ? null : parent;
  }

  /// Adds the folder at [path] as a project: the project as the list shows
  /// it, and whether it can host dedicated worktrees.
  Future<ApiResponse<({ProjectSummary project, bool supportsDedicatedWorktrees})>> discoverProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) async {
    final response = await _api.discoverProject(path: path, gitAction: gitAction);
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success((
        project: ProjectSummary(
          id: data.id,
          name: data.name,
          // COMPATIBILITY 2026-09-24 (v1.9.0): Bridges older than v1.5.0 omit path and use the directory as id. Use data.path directly once those bridges are unsupported.
          path: data.path.isEmpty ? data.id : data.path,
          time: data.time,
          hasUnseenChanges: data.hasUnseenChanges,
          directoryMissing: data.directoryMissing,
        ),
        supportsDedicatedWorktrees: data.supportsDedicatedWorktrees,
      )),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }

  Future<ApiResponse<Project>> getProject({required String projectId}) {
    return _api.getProject(projectId: projectId);
  }

  Future<ApiResponse<void>> hideProject({required String projectId}) {
    return _api.hideProject(projectId: projectId);
  }

  Future<ApiResponse<FilesystemSuggestions>> getFilesystemSuggestions({
    required String? prefix,
  }) {
    return _filesystemApi.getSuggestions(prefix: prefix);
  }

  /// Creates a plain folder named [name] under [parentPath] on the bridge host.
  ///
  /// This only makes the directory — the caller decides whether to register
  /// it as a project afterwards.
  Future<ApiResponse<FilesystemSuggestion>> createDirectory({
    required String parentPath,
    required String name,
  }) {
    return _filesystemApi.createDirectory(parentPath: parentPath, name: name);
  }

  Future<ApiResponse<SessionListResponse>> listSessions({required String projectId}) {
    return _api.listSessions(projectId: projectId);
  }

  Future<ApiResponse<Project>> renameProject({
    required String projectId,
    required String name,
  }) {
    return _api.renameProject(projectId: projectId, name: name);
  }

  p.Context _hostPathContext(String path) {
    final isWindowsPath = RegExp(r"^(?:[A-Za-z]:[\\/]|\\\\)").hasMatch(path);
    return isWindowsPath ? p.windows : p.posix;
  }
}
