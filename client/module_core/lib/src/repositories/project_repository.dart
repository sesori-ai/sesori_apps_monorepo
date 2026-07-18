import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as p;
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/filesystem_api.dart";
import "../api/project_api.dart";
import "models/repo_provider.dart";

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

  Future<ApiResponse<Project>> createProject({
    required String parentPath,
    required String name,
  }) {
    final path = _hostPathContext(parentPath).join(parentPath, name);
    return _api.createProject(path: path);
  }

  String? parentHostPath({required String path}) {
    final parent = _hostPathContext(path).dirname(path);
    return parent == path ? null : parent;
  }

  Future<ApiResponse<Project>> discoverProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) {
    return _api.discoverProject(path: path, gitAction: gitAction);
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

  /// The project's git context: its configured base branch plus the
  /// repository identity of its git remote, with the hosting provider
  /// classified from the remote's host.
  Future<ApiResponse<ProjectGitContext>> getGitContext({required String projectId}) async {
    final response = await _api.getBaseBranch(projectId: projectId);
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success(
        ProjectGitContext(
          baseBranch: data.baseBranch,
          repoSlug: data.repoSlug,
          repoProvider: RepoProvider.fromHost(host: data.repoHost),
        ),
      ),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
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

  p.Context _hostPathContext(String path) {
    final isWindowsPath = RegExp(r"^(?:[A-Za-z]:[\\/]|\\\\)").hasMatch(path);
    return isWindowsPath ? p.windows : p.posix;
  }
}

class ProjectSessionContext {
  final String projectId;
  final String? sessionTitle;

  const ProjectSessionContext({required this.projectId, required this.sessionTitle});
}

/// A project's git context: the configured base branch and the repository
/// identity of its git remote. [repoSlug] is null when the project has no
/// usable remote; [repoProvider] is then [RepoProvider.other].
class ProjectGitContext {
  final String? baseBranch;
  final String? repoSlug;
  final RepoProvider repoProvider;

  const ProjectGitContext({
    required this.baseBranch,
    required this.repoSlug,
    required this.repoProvider,
  });
}
