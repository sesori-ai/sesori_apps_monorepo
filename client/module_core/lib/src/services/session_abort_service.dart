import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

final class SessionAbortDescendantFailureException({
  // Dart permits throwing any non-null Object; retain exact Error and
  // non-Exception causes instead of narrowing or stringifying them.
  // ignore: no_slop_linter/prefer_specific_type
  required final Object cause,
  required final StackTrace causeStackTrace,
}) implements Exception;

final class SessionAbortDescendantStatusUnavailableException({
  required final String sessionId,
  required final String pluginId,
}) implements Exception;

@lazySingleton
class SessionAbortService({required final SessionRepository _repository}) {
  Future<void> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) async {
    final handled = _data(await _repository.abortSession(sessionId: sessionId, subAgents: subAgents));
    if (subAgents == SessionAbortSubAgentPolicy.keep || handled) return;

    try {
      await _abortDescendantsOf(sessionId: sessionId);
    } on Object catch (cause, stackTrace) {
      throw SessionAbortDescendantFailureException(cause: cause, causeStackTrace: stackTrace);
    }
  }

  Future<void> _abortDescendantsOf({required String sessionId}) async {
    final children = _data(await _repository.getChildren(sessionId: sessionId)).items;
    if (children.isEmpty) return;
    final snapshot = _data(await _repository.getSessionStatuses());
    await Future.wait([
      for (final child in children) _abortDescendant(session: child, snapshot: snapshot),
    ]);
  }

  Future<void> _abortDescendant({required Session session, required SessionStatusResponse snapshot}) async {
    if (snapshot.unavailablePluginIds.contains(session.pluginId)) {
      throw SessionAbortDescendantStatusUnavailableException(sessionId: session.id, pluginId: session.pluginId);
    }
    final status = snapshot.statuses[session.id];
    if (status is SessionStatusBusy || status is SessionStatusRetry) {
      final handled = _data(
        await _repository.abortSession(sessionId: session.id, subAgents: SessionAbortSubAgentPolicy.stop),
      );
      if (handled) return;
    }
    await _abortDescendantsOf(sessionId: session.id);
  }

  T _data<T>(ApiResponse<T> response) => switch (response) {
    SuccessResponse(:final data) => data,
    ErrorResponse(:final error) => throw error,
  };
}
