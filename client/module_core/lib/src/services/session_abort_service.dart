import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_abort_result.dart";
import "../repositories/session_repository.dart";

/// Applies the bridge's descendant-stop coverage without depending on a UI
/// surface or on the session-detail state's current loading phase.
@lazySingleton
class SessionAbortService({required final SessionRepository _repository}) {
  Future<void> abort({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
    required Map<String, SessionStatus> Function() readLegacyChildStatuses,
  }) async {
    final response = await _repository.abortSession(sessionId: sessionId, subAgents: subAgents);
    final result = switch (response) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
    if (subAgents == SessionAbortSubAgentPolicy.keep) return;

    final targetSessionIds = switch (result.coverage) {
      SessionAbortCoverageHandled() => const <String>{},
      SessionAbortCoveragePartial(:final unhandledSessionIds) => unhandledSessionIds.toSet(),
      SessionAbortCoverageLegacy(:final handledSessionIds) => {
        for (final MapEntry(key: childId, value: status) in readLegacyChildStatuses().entries)
          if ((status is SessionStatusBusy || status is SessionStatusRetry) && !handledSessionIds.contains(childId))
            childId,
      },
    };
    final results = await Future.wait([
      for (final childId in targetSessionIds)
        _repository.abortSession(sessionId: childId, subAgents: SessionAbortSubAgentPolicy.stop),
    ]);
    for (final result in results) {
      if (result case ErrorResponse(:final error)) throw error;
    }
  }
}
