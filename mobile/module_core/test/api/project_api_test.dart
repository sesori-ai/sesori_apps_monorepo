import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ProjectIdRequest(projectId: ""));
  });

  group("ProjectApi", () {
    late MockRelayHttpApiClient mockClient;
    late ProjectApi projectApi;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      projectApi = ProjectApi(mockClient);
    });

    test("listBranches posts to /project/branches with correct body", () async {
      const response = BranchListResponse(
        branches: [
          BranchInfo(
            name: "main",
            isRemoteOnly: false,
            lastCommitTimestamp: 1700000000000,
            worktreePath: null,
          ),
        ],
        currentBranch: "main",
      );

      when(
        () => mockClient.post<BranchListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(response));

      final result = await projectApi.listBranches(projectId: "proj-42");

      expect(result, isA<SuccessResponse<BranchListResponse>>());
      expect((result as SuccessResponse<BranchListResponse>).data.branches, hasLength(1));

      final captured = verify(
        () => mockClient.post<BranchListResponse>(
          captureAny(),
          fromJson: any(named: "fromJson"),
          body: captureAny(named: "body"),
        ),
      ).captured;

      expect(captured[0], equals("/project/branches"));
      expect(captured[1], isA<ProjectIdRequest>());
      expect((captured[1] as ProjectIdRequest).projectId, equals("proj-42"));
    });

    test("listBranches propagates error response", () async {
      when(
        () => mockClient.post<BranchListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final result = await projectApi.listBranches(projectId: "proj-42");

      expect(result, isA<ErrorResponse<BranchListResponse>>());
    });
  });
}
