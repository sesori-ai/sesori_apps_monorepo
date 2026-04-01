import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("ProjectService", () {
    late MockRelayHttpApiClient mockClient;
    late ProjectService projectService;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      projectService = ProjectService(mockClient);
    });

    group("listProjects", () {
      test("success: returns Projects from GET /projects", () async {
        // Arrange
        final testProjects = Projects(
          data: [
            testProject(path: "/home/user/project-1", name: "Project 1"),
            testProject(path: "/home/user/project-2", name: "Project 2"),
          ],
        );
        final successResponse = ApiResponse<Projects>.success(testProjects);

        when(
          () => mockClient.get<Projects>(
            "/projects",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => successResponse);

        // Act
        final result = await projectService.listProjects();

        // Assert
        expect(result, isA<SuccessResponse<Projects>>());
        expect((result as SuccessResponse<Projects>).data, equals(testProjects));
        verify(
          () => mockClient.get<Projects>(
            "/projects",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /projects", () async {
        // Arrange
        final apiError = ApiError.generic();
        final errorResponse = ApiResponse<Projects>.error(apiError);

        when(
          () => mockClient.get<Projects>(
            "/projects",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => errorResponse);

        // Act
        final result = await projectService.listProjects();

        // Assert
        expect(result, isA<ErrorResponse<Projects>>());
        expect((result as ErrorResponse<Projects>).error, equals(apiError));
        verify(
          () => mockClient.get<Projects>(
            "/projects",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("verifies correct path passed to client.get()", () async {
        // Arrange
        when(
          () => mockClient.get<Projects>(
            any(),
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));

        // Act
        await projectService.listProjects();

        // Assert
        verify(
          () => mockClient.get<Projects>(
            "/projects",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("getProject", () {
      test("success: returns Project from POST /project/current", () async {
        // Arrange
        final testProj = testProject(path: "/home/user/current-project");
        final successResponse = ApiResponse<Project>.success(testProj);

        when(
          () => mockClient.post<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => successResponse);

        // Act
        final result = await projectService.getProject(projectId: "/home/user/current-project");

        // Assert
        expect(result, isA<SuccessResponse<Project>>());
        expect((result as SuccessResponse<Project>).data, equals(testProj));
        verify(
          () => mockClient.post<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            body: const ProjectIdRequest(projectId: "/home/user/current-project"),
          ),
        ).called(1);
      });

      test("error: propagates API error from POST /project/current", () async {
        // Arrange
        final apiError = ApiError.dartHttpClient(Exception("Connection failed"));
        final errorResponse = ApiResponse<Project>.error(apiError);

        when(
          () => mockClient.post<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => errorResponse);

        // Act
        final result = await projectService.getProject(projectId: "/home/user/current-project");

        // Assert
        expect(result, isA<ErrorResponse<Project>>());
        expect((result as ErrorResponse<Project>).error, equals(apiError));
        verify(
          () => mockClient.post<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            body: const ProjectIdRequest(projectId: "/home/user/current-project"),
          ),
        ).called(1);
      });

      test("verifies correct path passed to client.post()", () async {
        // Arrange
        when(
          () => mockClient.post<Project>(
            any(),
            fromJson: any(named: "fromJson"),
            body: any(named: "body"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testProject()));

        // Act
        await projectService.getProject(projectId: "/home/user/current-project");

        // Assert
        verify(
          () => mockClient.post<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            body: const ProjectIdRequest(projectId: "/home/user/current-project"),
          ),
        ).called(1);
      });
    });
  });
}
