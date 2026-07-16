import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  late MockRelayHttpApiClient client;
  late ProjectApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = ProjectApi(client: client);
  });

  group("listProjects", () {
    test("returns projects from GET /projects", () async {
      const projects = Projects(
        data: [
          Project(id: "project-1", name: "Project 1", path: "/project-1", time: null),
        ],
      );
      when(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).thenAnswer((_) async => ApiResponse.success(projects));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.success(projects));
      verify(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).called(1);
    });

    test("propagates GET /projects errors", () async {
      final error = ApiError.generic();
      when(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.error(error));
      verify(
        () => client.get<Projects>("/projects", fromJson: any(named: "fromJson")),
      ).called(1);
    });
  });

  group("createProject", () {
    test("posts the project path and returns the project", () async {
      const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null);
      when(
        () => client.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await api.createProject(path: "/project-1");

      expect(response, ApiResponse<Project>.success(project));
      verify(
        () => client.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: const ProjectPathRequest(path: "/project-1"),
        ),
      ).called(1);
    });

    test("propagates errors", () async {
      final error = ApiError.generic();
      when(
        () => client.post<Project>(
          "/project/create",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.createProject(path: "/project-1");

      expect(response, ApiResponse<Project>.error(error));
    });
  });

  group("discoverProject", () {
    test("posts the project path and returns the project", () async {
      const project = Project(id: "project-1", name: "Project 1", path: "/project-1", time: null);
      when(
        () => client.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await api.discoverProject(path: "/project-1");

      expect(response, ApiResponse<Project>.success(project));
      verify(
        () => client.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: const ProjectPathRequest(path: "/project-1"),
        ),
      ).called(1);
    });

    test("propagates errors", () async {
      final error = ApiError.generic();
      when(
        () => client.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.discoverProject(path: "/project-1");

      expect(response, ApiResponse<Project>.error(error));
    });
  });

  group("hideProject", () {
    test("posts the project ID and returns success", () async {
      when(
        () => client.post<void>(
          "/project/hide",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));

      final response = await api.hideProject(projectId: "project-1");

      expect(response, ApiResponse<void>.success(null));
      verify(
        () => client.post<void>(
          "/project/hide",
          fromJson: any(named: "fromJson"),
          body: const ProjectIdRequest(projectId: "project-1"),
        ),
      ).called(1);
    });

    test("propagates errors", () async {
      final error = ApiError.generic();
      when(
        () => client.post<void>(
          "/project/hide",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.hideProject(projectId: "project-1");

      expect(response, ApiResponse<void>.error(error));
    });
  });

  group("getBaseBranch", () {
    test("posts the project ID and returns the base branch", () async {
      const baseBranch = BaseBranchResponse(baseBranch: "main", repoSlug: null);
      when(
        () => client.post<BaseBranchResponse>(
          "/project/base-branch",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(baseBranch));

      final response = await api.getBaseBranch(projectId: "project-1");

      expect(response, ApiResponse<BaseBranchResponse>.success(baseBranch));
      verify(
        () => client.post<BaseBranchResponse>(
          "/project/base-branch",
          fromJson: any(named: "fromJson"),
          body: const ProjectIdRequest(projectId: "project-1"),
        ),
      ).called(1);
    });

    test("propagates errors", () async {
      final error = ApiError.generic();
      when(
        () => client.post<BaseBranchResponse>(
          "/project/base-branch",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.getBaseBranch(projectId: "project-1");

      expect(response, ApiResponse<BaseBranchResponse>.error(error));
    });
  });

  group("renameProject", () {
    test("patches the project name and returns the project", () async {
      const project = Project(id: "project-1", name: "Renamed", path: "/project-1", time: null);
      when(
        () => client.patch<Project>(
          "/project/name",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await api.renameProject(projectId: "project-1", name: "Renamed");

      expect(response, ApiResponse<Project>.success(project));
      verify(
        () => client.patch<Project>(
          "/project/name",
          fromJson: any(named: "fromJson"),
          body: const RenameProjectRequest(projectId: "project-1", name: "Renamed"),
        ),
      ).called(1);
    });

    test("propagates errors", () async {
      final error = ApiError.generic();
      when(
        () => client.patch<Project>(
          "/project/name",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.renameProject(projectId: "project-1", name: "Renamed");

      expect(response, ApiResponse<Project>.error(error));
    });
  });
}
