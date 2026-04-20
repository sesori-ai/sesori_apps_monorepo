import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../repositories/session_repository.dart";
import "diff_state.dart";

class DiffCubit extends Cubit<DiffState> {
  final SessionRepository _sessionRepository;
  final String sessionId;

  DiffCubit({required SessionRepository sessionRepository, required this.sessionId})
    : _sessionRepository = sessionRepository,
      super(const DiffState.loading()) {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    try {
      final response = await _sessionRepository.getSessionDiffs(sessionId: sessionId);
      if (isClosed) return;

      switch (response) {
        case SuccessResponse(:final data):
          emit(DiffState.loaded(files: data.diffs));
        case ErrorResponse(:final error):
          emit(DiffState.failed(error: error));
      }
    } catch (e) {
      if (isClosed) return;
      emit(DiffState.failed(error: e));
    }
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Re-fetches diffs from the server.
  Future<void> refresh() async {
    emit(const DiffState.loading());
    await _init();
  }
}
