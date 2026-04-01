import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../capabilities/session/session_service.dart";
import "diff_state.dart";

class DiffCubit extends Cubit<DiffState> {
  final SessionService _service;
  final String sessionId;

  DiffCubit({required SessionService service, required this.sessionId})
    : _service = service,
      super(const DiffState.loading()) {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    try {
      final response = await _service.getSessionDiffs(sessionId: sessionId);
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
