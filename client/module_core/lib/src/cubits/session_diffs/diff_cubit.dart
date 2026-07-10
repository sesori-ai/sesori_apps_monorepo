import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../repositories/session_repository.dart";
import "diff_state.dart";

class DiffCubit extends Cubit<DiffState> {
  final SessionRepository _sessionRepository;
  final ConnectionService _connectionService;
  final String sessionId;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  Future<void>? _activeRefresh;

  DiffCubit({
    required SessionRepository sessionRepository,
    required ConnectionService connectionService,
    required this.sessionId,
  }) : _sessionRepository = sessionRepository,
       _connectionService = connectionService,
       super(const DiffState.loading()) {
    _eventSubscription = _connectionService.sessionEvents(sessionId).listen(_handleEvent);
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

  void _handleEvent(SesoriSessionEvent event) {
    if (event is! SesoriSessionDiff) return;
    unawaited(_refresh(showLoading: false));
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Re-fetches diffs from the server.
  Future<void> refresh() => _refresh(showLoading: true);

  Future<void> _refresh({required bool showLoading}) async {
    final previous = _activeRefresh;
    if (previous != null) {
      await previous;
    }

    final refresh = _refreshNow(showLoading: showLoading);
    _activeRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_activeRefresh, refresh)) {
        _activeRefresh = null;
      }
    }
  }

  Future<void> _refreshNow({required bool showLoading}) async {
    if (showLoading) {
      emit(const DiffState.loading());
    }
    await _init();
  }

  @override
  Future<void> close() async {
    await _eventSubscription.cancel();
    return super.close();
  }
}
