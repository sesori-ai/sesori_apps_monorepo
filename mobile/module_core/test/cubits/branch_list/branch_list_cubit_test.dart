import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/branch_list/branch_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/branch_list/branch_list_state.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockProjectRepository extends Mock implements ProjectRepository {}

const _projectId = "project-1";

const _branchMain = BranchInfo(
  name: "main",
  isRemoteOnly: false,
  lastCommitTimestamp: 1700000000000,
  worktreePath: null,
);

const _branchFeature = BranchInfo(
  name: "feature/login",
  isRemoteOnly: false,
  lastCommitTimestamp: 1700000001000,
  worktreePath: null,
);

const _branchWithWorktree = BranchInfo(
  name: "fix/bug-123",
  isRemoteOnly: false,
  lastCommitTimestamp: 1700000002000,
  worktreePath: "/repo/.worktrees/fix-bug-123",
);

void main() {
  group("BranchListCubit", () {
    late MockProjectRepository mockProjectRepository;

    setUp(() {
      mockProjectRepository = MockProjectRepository();
    });

    BranchListCubit buildCubit() => BranchListCubit(
      projectRepository: mockProjectRepository,
      projectId: _projectId,
    );

    // -----------------------------------------------------------------------
    // Loading
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "constructor loads branches and emits loaded state",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.branches, "branches", hasLength(2))
            .having((s) => s.filteredBranches, "filteredBranches", hasLength(2))
            .having((s) => s.currentBranch, "currentBranch", "main")
            .having((s) => s.searchQuery, "searchQuery", "")
            .having((s) => s.selectedBranch, "selectedBranch", isNull)
            .having((s) => s.selectedMode, "selectedMode", isNull)
            .having((s) => s.availableModes, "availableModes", isEmpty),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "constructor emits error on API failure",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      expect: () => [
        isA<BranchListError>().having(
          (s) => s.message,
          "message",
          "Failed to load branches.",
        ),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "emits specific error message for NotAuthenticatedError",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.notAuthenticated()));
        return buildCubit();
      },
      expect: () => [
        isA<BranchListError>().having(
          (s) => s.message,
          "message",
          "Authentication required.",
        ),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "emits specific error message for DartHttpClientError",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("timeout"))),
        );
        return buildCubit();
      },
      expect: () => [
        isA<BranchListError>().having(
          (s) => s.message,
          "message",
          "Unable to reach server.",
        ),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "emits raw error string for NonSuccessCodeError",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "Internal Server Error"),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        isA<BranchListError>().having(
          (s) => s.message,
          "message",
          "Internal Server Error",
        ),
      ],
    );

    // -----------------------------------------------------------------------
    // Search
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "search filters branches by name (case-insensitive)",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature, _branchWithWorktree],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.search(query: "FIX");
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.filteredBranches, "filteredBranches", hasLength(1))
            .having((s) => s.filteredBranches.first.name, "filtered name", "fix/bug-123")
            .having((s) => s.searchQuery, "searchQuery", "FIX"),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "search with empty query restores all branches",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.search(query: "feature");
        cubit.search(query: "");
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>().having((s) => s.filteredBranches, "filtered", hasLength(1)),
        isA<BranchListLoaded>().having((s) => s.filteredBranches, "restored", hasLength(2)),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "search is no-op when state is not loaded",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.search(query: "anything");
      },
      skip: 1,
      expect: () => <BranchListState>[],
    );

    // -----------------------------------------------------------------------
    // Branch selection — available modes
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "selectBranch without worktreePath offers stayOnBranch and newBranch",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectBranch(branch: _branchFeature);
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.selectedBranch, "selectedBranch", _branchFeature)
            .having((s) => s.selectedMode, "selectedMode", isNull)
            .having(
              (s) => s.availableModes,
              "availableModes",
              [WorktreeMode.stayOnBranch, WorktreeMode.newBranch],
            ),
      ],
    );

    blocTest<BranchListCubit, BranchListState>(
      "selectBranch with worktreePath still offers stayOnBranch and newBranch",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchWithWorktree],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectBranch(branch: _branchWithWorktree);
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.selectedBranch, "selectedBranch", _branchWithWorktree)
            .having((s) => s.selectedMode, "selectedMode", isNull)
            .having(
              (s) => s.availableModes,
              "availableModes",
              [WorktreeMode.stayOnBranch, WorktreeMode.newBranch],
            ),
      ],
    );

    // -----------------------------------------------------------------------
    // Mode selection
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "selectMode sets the selected mode",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectBranch(branch: _branchFeature);
        cubit.selectMode(mode: WorktreeMode.newBranch);
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>().having((s) => s.selectedMode, "selectedMode", isNull),
        isA<BranchListLoaded>().having((s) => s.selectedMode, "selectedMode", WorktreeMode.newBranch),
      ],
    );

    // -----------------------------------------------------------------------
    // Clear selection
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "clearSelection resets branch, mode, and availableModes",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectBranch(branch: _branchFeature);
        cubit.selectMode(mode: WorktreeMode.stayOnBranch);
        cubit.clearSelection();
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>().having((s) => s.selectedBranch, "selected", _branchFeature),
        isA<BranchListLoaded>().having((s) => s.selectedMode, "mode", WorktreeMode.stayOnBranch),
        isA<BranchListLoaded>()
            .having((s) => s.selectedBranch, "selectedBranch", isNull)
            .having((s) => s.selectedMode, "selectedMode", isNull)
            .having((s) => s.availableModes, "availableModes", isEmpty),
      ],
    );

    // -----------------------------------------------------------------------
    // Selecting a new branch resets mode
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "selecting a different branch resets selectedMode",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(
              branches: [_branchMain, _branchFeature, _branchWithWorktree],
              currentBranch: "main",
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectBranch(branch: _branchFeature);
        cubit.selectMode(mode: WorktreeMode.newBranch);
        cubit.selectBranch(branch: _branchWithWorktree);
      },
      skip: 1,
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.selectedBranch, "first selection", _branchFeature)
            .having((s) => s.selectedMode, "mode cleared", isNull),
        isA<BranchListLoaded>().having((s) => s.selectedMode, "mode set", WorktreeMode.newBranch),
        isA<BranchListLoaded>()
            .having((s) => s.selectedBranch, "second selection", _branchWithWorktree)
            .having((s) => s.selectedMode, "mode reset", isNull)
            .having(
              (s) => s.availableModes,
              "modes for worktree branch",
              [WorktreeMode.stayOnBranch, WorktreeMode.newBranch],
            ),
      ],
    );

    // -----------------------------------------------------------------------
    // Empty branch list
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "loaded with empty branch list",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const BranchListResponse(branches: [], currentBranch: null),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        isA<BranchListLoaded>()
            .having((s) => s.branches, "branches", isEmpty)
            .having((s) => s.currentBranch, "currentBranch", isNull),
      ],
    );

    // -----------------------------------------------------------------------
    // Cubit closed during load
    // -----------------------------------------------------------------------

    blocTest<BranchListCubit, BranchListState>(
      "no emission if cubit is closed before API responds",
      build: () {
        when(
          () => mockProjectRepository.listBranches(projectId: _projectId),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return ApiResponse.success(
            const BranchListResponse(branches: [_branchMain], currentBranch: "main"),
          );
        });
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.close();
      },
      expect: () => <BranchListState>[],
    );
  });
}
