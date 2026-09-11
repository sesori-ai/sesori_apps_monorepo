import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

// ignore: no_slop_linter/prefer_specific_type, caught errors are opaque
final class SessionAbortDescendantFailureException({required final Object cause}) implements Exception;

@lazySingleton
class SessionAbortService({required final SessionRepository _repository}) {
  Future<void> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
    required Map<String, SessionStatus> childStatuses,
    required Map<String, SessionStatus>? Function() readCurrentChildStatuses,
  }) async {
    final handled = _data(await _repository.abortSession(sessionId: sessionId, subAgents: subAgents));
    if (subAgents == SessionAbortSubAgentPolicy.keep || handled) return;

    try {
      await _abortReleasedBridgeDescendants(
        statuses: readCurrentChildStatuses() ?? childStatuses,
      );
    } on Object catch (cause) {
      if (cause is SessionAbortDescendantFailureException) rethrow;
      throw SessionAbortDescendantFailureException(cause: cause);
    }
  }

  Future<void> _abortReleasedBridgeDescendants({required Map<String, SessionStatus> statuses}) async {
    for (final MapEntry(key: sessionId, value: status) in statuses.entries) {
      if (status is SessionStatusBusy || status is SessionStatusRetry) {
        final handled = _data(
          await _repository.abortSession(sessionId: sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
        );
        if (handled) continue;
      }
      final children = _data(await _repository.getChildren(sessionId: sessionId)).items;
      if (children.isEmpty) continue;
      final currentStatuses = _data(await _repository.getSessionStatuses()).statuses;
      await _abortReleasedBridgeDescendants(
        statuses: {for (final child in children) child.id: ?currentStatuses[child.id]},
      );
    }
  }

  T _data<T>(ApiResponse<T> response) => switch (response) {
    SuccessResponse(:final data) => data,
    ErrorResponse(:final error) => throw error,
  };
}
