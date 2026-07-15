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
