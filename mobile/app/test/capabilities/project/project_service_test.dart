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
      test("success: returns List<Project> from GET /project", () async {
        // Arrange
        final testProjects = [
          testProject(path: "/home/user/project-1", name: "Project 1"),
          testProject(path: "/home/user/project-2", name: "Project 2"),
        ];
        final successResponse = ApiResponse<List<Project>>.success(testProjects);

        when(
          () => mockClient.get<List<Project>>(
            "/project",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => successResponse);

        // Act
        final result = await projectService.listProjects();

        // Assert
        expect(result, isA<SuccessResponse<List<Project>>>());
        expect((result as SuccessResponse<List<Project>>).data, equals(testProjects));
        verify(
          () => mockClient.get<List<Project>>(
            "/project",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /project", () async {
        // Arrange
        final apiError = ApiError.generic();
        final errorResponse = ApiResponse<List<Project>>.error(apiError);

        when(
          () => mockClient.get<List<Project>>(
            "/project",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => errorResponse);

        // Act
        final result = await projectService.listProjects();

        // Assert
        expect(result, isA<ErrorResponse<List<Project>>>());
        expect((result as ErrorResponse<List<Project>>).error, equals(apiError));
        verify(
          () => mockClient.get<List<Project>>(
            "/project",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });

      test("verifies correct path passed to client.get()", () async {
        // Arrange
        when(
          () => mockClient.get<List<Project>>(
            any(),
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success([]));

        // Act
        await projectService.listProjects();

        // Assert
        verify(
          () => mockClient.get<List<Project>>(
            "/project",
            fromJson: any(named: "fromJson"),
          ),
        ).called(1);
      });
    });

    group("getCurrentProject", () {
      test("success: returns Project from GET /project/current", () async {
        // Arrange
        final testProj = testProject(path: "/home/user/current-project");
        final successResponse = ApiResponse<Project>.success(testProj);

        when(
          () => mockClient.get<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => successResponse);

        // Act
        final result = await projectService.getCurrentProject(projectId: "/home/user/current-project");

        // Assert
        expect(result, isA<SuccessResponse<Project>>());
        expect((result as SuccessResponse<Project>).data, equals(testProj));
        verify(
          () => mockClient.get<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            queryParameters: {"projectId": "/home/user/current-project"},
          ),
        ).called(1);
      });

      test("error: propagates API error from GET /project/current", () async {
        // Arrange
        final apiError = ApiError.dartHttpClient(Exception("Connection failed"));
        final errorResponse = ApiResponse<Project>.error(apiError);

        when(
          () => mockClient.get<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => errorResponse);

        // Act
        final result = await projectService.getCurrentProject(projectId: "/home/user/current-project");

        // Assert
        expect(result, isA<ErrorResponse<Project>>());
        expect((result as ErrorResponse<Project>).error, equals(apiError));
        verify(
          () => mockClient.get<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            queryParameters: {"projectId": "/home/user/current-project"},
          ),
        ).called(1);
      });

      test("verifies correct path passed to client.get()", () async {
        // Arrange
        when(
          () => mockClient.get<Project>(
            any(),
            fromJson: any(named: "fromJson"),
            queryParameters: any(named: "queryParameters"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testProject()));

        // Act
        await projectService.getCurrentProject(projectId: "/home/user/current-project");

        // Assert
        verify(
          () => mockClient.get<Project>(
            "/project/current",
            fromJson: any(named: "fromJson"),
            queryParameters: {"projectId": "/home/user/current-project"},
          ),
        ).called(1);
      });
    });
  });
}
