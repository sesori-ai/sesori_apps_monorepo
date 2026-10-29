import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late MockRelayHttpApiClient client;
  late ProjectApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = ProjectApi(client: client);
  });

  group("listProjects", () {
    test("returns projects from GET /projects, decoded in the background", () async {
      const projects = Projects(
        data: [
          ProjectSummary(id: "project-1", name: "Project 1", path: "/project-1", time: null),
        ],
      );
      when(
        () => client.getDecodedInBackground<Projects>(
          path: "/projects",
          fromJson: any(named: "fromJson"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(projects));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.success(projects));
      verify(
        () => client.getDecodedInBackground<Projects>(
          path: "/projects",
          fromJson: any(named: "fromJson"),
        ),
      ).called(1);
    });

    test("propagates GET /projects errors", () async {
      final error = ApiError.generic();
      when(
        () => client.getDecodedInBackground<Projects>(
          path: "/projects",
          fromJson: any(named: "fromJson"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final response = await api.listProjects();

      expect(response, ApiResponse<Projects>.error(error));
      verify(
        () => client.getDecodedInBackground<Projects>(
          path: "/projects",
          fromJson: any(named: "fromJson"),
        ),
      ).called(1);
    });
  });

  group("listSessions", () {
    test("posts the whole-project request to /sessions and decodes it in the background", () async {
      const sessions = SessionListResponse(items: []);
      when(
        () => client.postDecodedInBackground<SessionListResponse>(
          path: "/sessions",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
          sensitiveResponse: false,
        ),
      ).thenAnswer((_) async => ApiResponse.success(sessions));

      final response = await api.listSessions(projectId: "project-1");

      expect(response, ApiResponse<SessionListResponse>.success(sessions));
      verify(
        () => client.postDecodedInBackground<SessionListResponse>(
          path: "/sessions",
          fromJson: any(named: "fromJson"),
          body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
          sensitiveResponse: false,
        ),
      ).called(1);
    });
  });

  group("discoverProject", () {
    test("posts the project path and returns the project", () async {
      const project = Project(
        id: "project-1",
        name: "Project 1",
        path: "/project-1",
        time: null,
        voiceGlossaryKey: null,
      );
      when(
        () => client.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.initializeGit,
      );

      expect(response, ApiResponse<Project>.success(project));
      verify(
        () => client.post<Project>(
          "/project/open",
          fromJson: any(named: "fromJson"),
          body: const OpenProjectRequest(
            path: "/project-1",
            gitAction: OpenProjectGitAction.initializeGit,
          ),
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

      final response = await api.discoverProject(
        path: "/project-1",
        gitAction: OpenProjectGitAction.openWithoutGit,
      );

      expect(response, ApiResponse<Project>.error(error));
    });
  });

  group("getProject", () {
    test("posts the project ID and returns the project", () async {
      const project = Project(
        id: "project-1",
        name: "Project 1",
        path: "/project-1",
        time: null,
        voiceGlossaryKey: null,
      );
      when(
        () => client.post<Project>(
          "/project/current",
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(project));

      final response = await api.getProject(projectId: "project-1");

      expect(response, ApiResponse<Project>.success(project));
      verify(
        () => client.post<Project>(
          "/project/current",
          fromJson: any(named: "fromJson"),
          body: const ProjectIdRequest(projectId: "project-1"),
        ),
      ).called(1);
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

  group("renameProject", () {
    test("patches the project name and returns the project", () async {
      const project = Project(id: "project-1", name: "Renamed", path: "/project-1", time: null, voiceGlossaryKey: null);
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
