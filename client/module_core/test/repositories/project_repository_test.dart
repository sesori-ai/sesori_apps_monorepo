import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/models/repo_provider.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  test("project operations delegate to ProjectApi", () async {
    final api = MockProjectApi();
    final filesystemApi = MockFilesystemApi();
    final repository = ProjectRepository(api: api, filesystemApi: filesystemApi);
    const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null);
    const projects = Projects(data: [project]);
    const suggestions = FilesystemSuggestions(data: []);
    const sessions = SessionListResponse(items: []);

    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(projects));
    when(() => api.createProject(path: "/project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.discoverProject(path: "/project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.hideProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => filesystemApi.getSuggestions(prefix: "/projects"),
    ).thenAnswer((_) async => ApiResponse.success(suggestions));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(sessions));
    when(
      () => api.renameProject(projectId: "project-1", name: "Renamed"),
    ).thenAnswer((_) async => ApiResponse.success(project));

    expect(await repository.listProjects(), ApiResponse<Projects>.success(projects));
    expect(await repository.createProject(path: "/project-1"), ApiResponse<Project>.success(project));
    expect(await repository.discoverProject(path: "/project-1"), ApiResponse<Project>.success(project));
    expect(await repository.hideProject(projectId: "project-1"), ApiResponse<void>.success(null));
    expect(
      await repository.getFilesystemSuggestions(prefix: "/projects"),
      ApiResponse<FilesystemSuggestions>.success(suggestions),
    );
    expect(
      await repository.listSessions(projectId: "project-1", waitForPrData: false),
      ApiResponse<SessionListResponse>.success(sessions),
    );
    expect(
      await repository.renameProject(projectId: "project-1", name: "Renamed"),
      ApiResponse<Project>.success(project),
    );

    verify(api.listProjects).called(1);
    verify(() => api.createProject(path: "/project-1")).called(1);
    verify(() => api.discoverProject(path: "/project-1")).called(1);
    verify(() => api.hideProject(projectId: "project-1")).called(1);
    verify(() => filesystemApi.getSuggestions(prefix: "/projects")).called(1);
    verify(() => api.listSessions(projectId: "project-1", waitForPrData: false)).called(1);
    verify(() => api.renameProject(projectId: "project-1", name: "Renamed")).called(1);
  });

  group("getGitContext", () {
    late MockProjectApi api;
    late ProjectRepository repository;

    setUp(() {
      api = MockProjectApi();
      repository = ProjectRepository(api: api, filesystemApi: MockFilesystemApi());
    });

    void stubBaseBranch(BaseBranchResponse response) {
      when(
        () => api.getBaseBranch(projectId: "project-1"),
      ).thenAnswer((_) async => ApiResponse.success(response));
    }

    test("maps the wire response into a git context with a classified provider", () async {
      stubBaseBranch(
        const BaseBranchResponse(baseBranch: "main", repoSlug: "org/repo", repoHost: "gitlab.company.com"),
      );

      final response = await repository.getGitContext(projectId: "project-1");

      final context = (response as SuccessResponse<ProjectGitContext>).data;
      expect(context.baseBranch, equals("main"));
      expect(context.repoSlug, equals("org/repo"));
      expect(context.repoProvider, equals(RepoProvider.gitlab));
    });

    test("classifies a missing host as RepoProvider.other", () async {
      stubBaseBranch(const BaseBranchResponse(baseBranch: null, repoSlug: "org/repo", repoHost: null));

      final response = await repository.getGitContext(projectId: "project-1");

      final context = (response as SuccessResponse<ProjectGitContext>).data;
      expect(context.repoProvider, equals(RepoProvider.other));
    });

    test("passes errors through", () async {
      final error = ApiError.generic();
      when(
        () => api.getBaseBranch(projectId: "project-1"),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await repository.getGitContext(projectId: "project-1");

      expect(response, ApiResponse<ProjectGitContext>.error(error));
    });
  });

  test("findSessionContext retains the catalog session plugin identity", () async {
    final api = MockProjectApi();
    final repository = ProjectRepository(api: api, filesystemApi: MockFilesystemApi());
    const project = Project(id: "project-1", name: "Project", path: "/project", time: null);
    final session = testSession(id: "session-1", pluginId: "plugin-b", title: "Session");
    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(const Projects(data: [project])));
    when(
      () => api.listSessions(projectId: "project-1", waitForPrData: false),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [session])));

    final context = await repository.findSessionContext(sessionId: "session-1");

    expect(context?.projectId, "project-1");
    expect(context?.pluginId, "plugin-b");
    expect(context?.sessionTitle, "Session");
  });
}
