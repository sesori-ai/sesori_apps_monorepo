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
    final repository = ProjectRepository(api: api, filesystemApi: filesystemApi);
    const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null);
    const projects = Projects(data: [project]);
    const suggestions = FilesystemSuggestions(data: []);
    const baseBranch = BaseBranchResponse(baseBranch: "main", repoSlug: null);
    const sessions = SessionListResponse(items: []);

    when(api.listProjects).thenAnswer((_) async => ApiResponse.success(projects));
    when(() => api.createProject(path: "/project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.discoverProject(path: "/project-1")).thenAnswer((_) async => ApiResponse.success(project));
    when(() => api.hideProject(projectId: "project-1")).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => filesystemApi.getSuggestions(prefix: "/projects"),
    ).thenAnswer((_) async => ApiResponse.success(suggestions));
    when(
      () => api.getBaseBranch(projectId: "project-1"),
    ).thenAnswer((_) async => ApiResponse.success(baseBranch));
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
      await repository.getBaseBranch(projectId: "project-1"),
      ApiResponse<BaseBranchResponse>.success(baseBranch),
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
    verify(() => api.getBaseBranch(projectId: "project-1")).called(1);
    verify(() => api.listSessions(projectId: "project-1", waitForPrData: false)).called(1);
    verify(() => api.renameProject(projectId: "project-1", name: "Renamed")).called(1);
  });
}
