import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockProjectApi extends Mock implements ProjectApi {}

void main() {
  group("ProjectRepository", () {
    late MockProjectApi mockProjectApi;
    late ProjectRepository repository;

    setUp(() {
      mockProjectApi = MockProjectApi();
      repository = ProjectRepository(mockProjectApi);
    });

    test("listBranches delegates to ProjectApi with correct projectId", () async {
      const response = BranchListResponse(
        branches: [
          BranchInfo(
            name: "main",
            isRemoteOnly: false,
            lastCommitTimestamp: 1700000000000,
            worktreePath: null,
          ),
          BranchInfo(
            name: "develop",
            isRemoteOnly: false,
            lastCommitTimestamp: 1700000001000,
            worktreePath: "/repo/.worktrees/develop",
          ),
        ],
        currentBranch: "main",
      );

      when(
        () => mockProjectApi.listBranches(projectId: "proj-99"),
      ).thenAnswer((_) async => ApiResponse.success(response));

      final result = await repository.listBranches(projectId: "proj-99");

      expect(result, isA<SuccessResponse<BranchListResponse>>());
      final data = (result as SuccessResponse<BranchListResponse>).data;
      expect(data.branches, hasLength(2));
      expect(data.currentBranch, equals("main"));
      expect(data.branches[1].worktreePath, equals("/repo/.worktrees/develop"));

      verify(() => mockProjectApi.listBranches(projectId: "proj-99")).called(1);
    });

    test("listBranches propagates error from ProjectApi", () async {
      when(
        () => mockProjectApi.listBranches(projectId: "proj-99"),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "Server Error"),
        ),
      );

      final result = await repository.listBranches(projectId: "proj-99");

      expect(result, isA<ErrorResponse<BranchListResponse>>());
      final error = (result as ErrorResponse<BranchListResponse>).error;
      expect(error, isA<NonSuccessCodeError>());
    });
  });
}
