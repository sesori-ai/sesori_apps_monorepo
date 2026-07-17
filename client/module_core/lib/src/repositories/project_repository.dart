import "dart:async";
import "dart:collection";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/filesystem_api.dart";
import "../api/project_api.dart";
import "../api/session_api.dart";
import "../logging/logging.dart";
import "models/repo_provider.dart";

@lazySingleton
class ProjectRepository {
  final ProjectApi _api;
  final FilesystemApi _filesystemApi;
  final SessionApi _sessionApi;

  ProjectRepository({
    required ProjectApi api,
    required FilesystemApi filesystemApi,
    required SessionApi sessionApi,
  }) : _api = api,
       _filesystemApi = filesystemApi,
       _sessionApi = sessionApi;

  Future<ApiResponse<Projects>> listProjects() {
    return _api.listProjects();
  }

  Future<ApiResponse<Project>> createProject({required String path}) {
    return _api.createProject(path: path);
  }

  Future<ApiResponse<Project>> discoverProject({required String path}) {
    return _api.discoverProject(path: path);
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
        final projectRoots = await Future.wait(
          projects.map((project) async {
            final sessionsResponse = await _api.listSessions(
              projectId: project.id,
              waitForPrData: false,
            );
            final roots = switch (sessionsResponse) {
              SuccessResponse(:final data) => data.items,
              ErrorResponse() => const <Session>[],
            };
            return (projectId: project.id, roots: roots);
          }),
        );

        if (projectRoots.isEmpty) return null;

        final completion = Completer<ProjectSessionContext?>();
        final searches = projectRoots.map(
          (project) => _findSessionContext(
            projectId: project.projectId,
            sessionId: sessionId,
            roots: project.roots,
            completion: completion,
          ),
        );
        unawaited(
          Future.wait(searches).then<void>(
            (_) {
              if (!completion.isCompleted) completion.complete(null);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!completion.isCompleted) {
                completion.completeError(error, stackTrace);
              } else {
                logw("Session context search failed after another project matched", error, stackTrace);
              }
            },
          ),
        );
        return completion.future;
    }
  }

  Future<void> _findSessionContext({
    required String projectId,
    required String sessionId,
    required List<Session> roots,
    required Completer<ProjectSessionContext?> completion,
  }) async {
    final pending = Queue<Session>.of(roots);
    final visited = <String>{};

    while (pending.isNotEmpty && !completion.isCompleted) {
      final session = pending.removeFirst();
      if (!visited.add(session.id)) continue;
      if (session.id == sessionId) {
        completion.complete(
          ProjectSessionContext(
            projectId: projectId,
            pluginId: session.pluginId,
            sessionTitle: session.title,
          ),
        );
        return;
      }

      final childrenResponse = await _sessionApi.getChildren(sessionId: session.id);
      if (childrenResponse case SuccessResponse(:final data)) {
        pending.addAll(data.items);
      }
    }
  }
}

class ProjectSessionContext {
  final String projectId;
  final String pluginId;
  final String? sessionTitle;

  const ProjectSessionContext({
    required this.projectId,
    required this.pluginId,
    required this.sessionTitle,
  });
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
