import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Owns root abort plus released-bridge descendant fallback.
@lazySingleton
class SessionAbortService({required final SessionRepository _repository}) {
  Future<void> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
    required Map<String, SessionStatus> childStatuses,
  }) async {
    final root = await _repository.abortSession(sessionId: sessionId, subAgents: subAgents);
    final subAgentsHandled = switch (root) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
    if (subAgents == SessionAbortSubAgentPolicy.keep || subAgentsHandled) return;

    final results = await Future.wait([
      for (final MapEntry(key: childId, value: status) in childStatuses.entries)
        if (status is SessionStatusBusy || status is SessionStatusRetry)
          _repository.abortSession(sessionId: childId, subAgents: SessionAbortSubAgentPolicy.stop),
    ]);
    for (final result in results) {
      if (result case ErrorResponse(:final error)) throw error;
    }
  }
}
