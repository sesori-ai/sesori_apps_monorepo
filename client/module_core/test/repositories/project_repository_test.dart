import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  test("project operations delegate to ProjectApi", () async {
    final api = MockProjectApi();
    final filesystemApi = MockFilesystemApi();
    final repository = ProjectRepository(
      api: api,
      filesystemApi: filesystemApi,
    );
    const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null, voiceGlossaryKey: null);
    const projectSummary = ProjectSummary(id: "project-1", name: "Project 1", path: "/project-1", time: null);
    const projects = Projects(data: [projectSummary]);
    const suggestions = FilesystemSuggestions(data: [], path: null);
    const sessions = SessionListResponse(items: []);

    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(projects));
    when(
      () => api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
    ).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.getProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.hideProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => filesystemApi.getSuggestions(prefix: "/projects"),
    ).thenAnswer((_) async => ApiResponse.success(suggestions));
    when(
      () => api.listSessions(projectId: "project-1"),
    ).thenAnswer((_) async => ApiResponse.success(sessions));
    when(
      () => api.renameProject(projectId: "project-1", name: "Renamed"),
    ).thenAnswer((_) async => ApiResponse.success(project));

    expect(await repository.listProjects(), ApiResponse<Projects>.success(projects));
    expect(
      await repository.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
      ApiResponse<({ProjectSummary project, bool supportsDedicatedWorktrees})>.success((
        project: projectSummary,
        supportsDedicatedWorktrees: project.supportsDedicatedWorktrees,
      )),
    );
    expect(await repository.getProject(projectId: "project-1"), ApiResponse<Project>.success(project));
    expect(await repository.hideProject(projectId: "project-1"), ApiResponse<void>.success(null));
    expect(
      await repository.getFilesystemSuggestions(prefix: "/projects"),
      ApiResponse<FilesystemSuggestions>.success(suggestions),
    );
    expect(
      await repository.listSessions(projectId: "project-1"),
      ApiResponse<SessionListResponse>.success(sessions),
    );
    expect(
      await repository.renameProject(projectId: "project-1", name: "Renamed"),
      ApiResponse<Project>.success(project),
    );

    verify(api.listProjects).called(1);
    verify(
      () => api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      ),
    ).called(1);
    verify(() => api.getProject(projectId: "project-1")).called(1);
    verify(() => api.hideProject(projectId: "project-1")).called(1);
    verify(() => filesystemApi.getSuggestions(prefix: "/projects")).called(1);
    verify(() => api.listSessions(projectId: "project-1")).called(1);
    verify(() => api.renameProject(projectId: "project-1", name: "Renamed")).called(1);
  });

  group("host paths", () {
    test("resolves POSIX and Windows parents without crossing roots", () {
      final repository = ProjectRepository(
        api: MockProjectApi(),
        filesystemApi: MockFilesystemApi(),
        );

      expect(repository.parentHostPath(path: "/home/dev/projects"), "/home/dev");
      expect(repository.parentHostPath(path: "/"), isNull);
      expect(repository.parentHostPath(path: r"C:\Users\dev\projects"), r"C:\Users\dev");
      expect(repository.parentHostPath(path: r"C:\"), isNull);
    });
  });
}
