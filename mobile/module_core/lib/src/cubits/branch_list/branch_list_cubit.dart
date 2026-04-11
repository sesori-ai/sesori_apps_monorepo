import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/project_repository.dart";
import "branch_list_state.dart";

class BranchListCubit extends Cubit<BranchListState> {
  final ProjectRepository _projectRepository;
  final String _projectId;

  List<BranchInfo> _allBranches = const [];

  BranchListCubit({
    required ProjectRepository projectRepository,
    required String projectId,
  }) : _projectRepository = projectRepository,
       _projectId = projectId,
       super(const BranchListState.loading()) {
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final response = await _projectRepository.listBranches(
      projectId: _projectId,
    );

    if (isClosed) return;

    switch (response) {
      case SuccessResponse(:final data):
        _allBranches = data.branches;
        emit(
          BranchListState.loaded(
            branches: _allBranches,
            filteredBranches: _allBranches,
            currentBranch: data.currentBranch,
            searchQuery: "",
            selectedBranch: null,
            selectedMode: null,
            availableModes: const [],
          ),
        );
      case ErrorResponse(:final error):
        emit(BranchListState.error(message: _describeError(error: error)));
    }
  }

  void search({required String query}) {
    final current = state;
    if (current is! BranchListLoaded) return;

    final trimmed = query.trim();
    final filtered = trimmed.isEmpty
        ? _allBranches
        : _allBranches
              .where(
                (b) => b.name.toLowerCase().contains(trimmed.toLowerCase()),
              )
              .toList();

    emit(current.copyWith(filteredBranches: filtered, searchQuery: query));
  }

  void selectBranch({required BranchInfo branch}) {
    final current = state;
    if (current is! BranchListLoaded) return;

    final modes = _computeAvailableModes(branch: branch);
    emit(
      current.copyWith(
        selectedBranch: branch,
        selectedMode: null,
        availableModes: modes,
      ),
    );
  }

  void selectMode({required WorktreeMode mode}) {
    final current = state;
    if (current is! BranchListLoaded) return;

    emit(current.copyWith(selectedMode: mode));
  }

  void clearSelection() {
    final current = state;
    if (current is! BranchListLoaded) return;

    emit(
      current.copyWith(
        selectedBranch: null,
        selectedMode: null,
        availableModes: const [],
      ),
    );
  }

  List<WorktreeMode> _computeAvailableModes({required BranchInfo branch}) {
    return const [WorktreeMode.stayOnBranch, WorktreeMode.newBranch];
  }

  String _describeError({required ApiError error}) {
    return switch (error) {
      NotAuthenticatedError() => "Authentication required.",
      NonSuccessCodeError(:final rawErrorString) => rawErrorString ?? "Failed to load branches.",
      DartHttpClientError() => "Unable to reach server.",
      JsonParsingError() => "Unexpected server response.",
      GenericError() => "Failed to load branches.",
      EmptyResponseError() => "Empty response from server.",
    };
  }
}
