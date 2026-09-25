import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../logging/logging.dart";
import "../../repositories/models/session_diff_summary_result.dart";
import "../../repositories/session_repository.dart";
import "diff_summary_state.dart";

/// The session's line totals for the Changes label, refreshed when the
/// session's files change, at most once per [refreshInterval].
class DiffSummaryCubit({
  required final SessionRepository _sessionRepository,
  required final ConnectionService _connectionService,
  required final String sessionId,
  required final Duration refreshInterval,
}) extends Cubit<DiffSummaryState> {
  late final StreamSubscription<SesoriSessionEvent> _diffEvents;

  this : super(const DiffSummaryState.unknown()) {
    _diffEvents = _connectionService
        .sessionEvents(sessionId)
        .where((event) => event is SesoriSessionDiff)
        .throttleTime(refreshInterval, trailing: true)
        .listen((_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final SessionDiffSummaryResult result;
    try {
      result = await _sessionRepository.getSessionDiffSummary(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      logw("Failed to load the session's change totals", error, stackTrace);
      return;
    }
    if (isClosed) return;
    switch (result) {
      case SessionDiffSummaryAvailable(:final additions, :final deletions):
        emit(DiffSummaryState.counts(additions: additions, deletions: deletions));
      case SessionDiffSummaryUnsupported():
        // An older bridge never learns the request; stop asking for this page.
        await _diffEvents.cancel();
      case SessionDiffSummaryFailure(:final error):
        // The last totals stay; the next change refreshes them.
        logw("Failed to load the session's change totals", error);
    }
  }

  @override
  Future<void> close() async {
    await _diffEvents.cancel();
    return await super.close();
  }
}
