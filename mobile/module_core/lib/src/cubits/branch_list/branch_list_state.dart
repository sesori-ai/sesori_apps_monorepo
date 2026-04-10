import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "branch_list_state.freezed.dart";

@Freezed()
sealed class BranchListState with _$BranchListState {
  const factory BranchListState.loading() = BranchListLoading;

  const factory BranchListState.loaded({
    required List<BranchInfo> branches,
    required List<BranchInfo> filteredBranches,
    required String? currentBranch,
    required String searchQuery,
    required BranchInfo? selectedBranch,
    required WorktreeMode? selectedMode,
    required List<WorktreeMode> availableModes,
  }) = BranchListLoaded;

  const factory BranchListState.error({required String message}) = BranchListError;
}
