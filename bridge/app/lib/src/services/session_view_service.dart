import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_continuation_record.dart";
import "../repositories/session_continuation_repository.dart";
import "../repositories/session_repository.dart";

/// Projects bridge-owned continuation state onto existing session responses.
class const SessionViewService({
  required final SessionRepository _sessions,
  required final SessionContinuationRepository _continuations,
  required final Duration _resetBuffer,
}) {
  Future<Session> get({required String sessionId}) async {
    final session = await _sessions.getCatalogSession(sessionId: sessionId);
    if (session == null) {
      throw PluginOperationException.notFound("getSession", message: "session $sessionId was not found");
    }
    return await enrich(session: session);
  }

  Future<Session> enrich({required Session session}) async => (await enrichMany(sessions: [session])).single;

  Future<List<Session>> enrichMany({required List<Session> sessions}) async {
    final records = await _continuations.readMany(sessionIds: sessions.map((session) => session.id).toSet());
    return [
      for (final session in sessions)
        session.copyWith(
          autoContinuation: _view(session: session, record: records[session.id]),
        ),
    ];
  }

  SessionAutoContinuationView _view({required Session session, required SessionContinuationRecord? record}) =>
      SessionAutoContinuationView(
        enabled: record?.enabled ?? false,
        availability: _sessions.quotaReportingAvailability(pluginId: session.pluginId),
        status: switch (record?.outcome) {
          null ||
          SessionContinuationNone() ||
          SessionContinuationCancelled() => const SessionAutoContinuationStatus.idle(),
          SessionContinuationResetKnown(:final resetAt) => SessionAutoContinuationStatus.resetKnown(
            resetAt: resetAt.millisecondsSinceEpoch,
            continueAt: resetAt.add(_resetBuffer).millisecondsSinceEpoch,
          ),
          SessionContinuationResetUnknown() => const SessionAutoContinuationStatus.resetUnknown(),
          SessionContinuationPaused(:final resetAt, :final reason) => SessionAutoContinuationStatus.paused(
            resetAt: resetAt.millisecondsSinceEpoch,
            continueAt: resetAt.add(_resetBuffer).millisecondsSinceEpoch,
            reason: reason,
          ),
          SessionContinuationConsumed() => const SessionAutoContinuationStatus.attemptUnconfirmed(),
          SessionContinuationSubmitted(:final acceptedAt) => SessionAutoContinuationStatus.submitted(
            acceptedAt: acceptedAt.millisecondsSinceEpoch,
          ),
          SessionContinuationSubmissionFailed(:final reason) => SessionAutoContinuationStatus.submissionFailed(
            reason: reason,
          ),
        },
      );
}
