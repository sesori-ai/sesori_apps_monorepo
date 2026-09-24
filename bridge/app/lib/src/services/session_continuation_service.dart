import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_continuation_record.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/session_continuation_repository.dart";
import "../repositories/session_repository.dart";
import "session_mutation_dispatcher.dart";
import "session_operation_dispatcher.dart";
import "session_prompt_service.dart";
import "session_view_service.dart";

final class const SessionAutoContinuationUnavailableException() implements Exception;

/// Owns quota scheduling policy. Every mutation and attempted send uses the
/// existing session lane; timers and plugin-event listeners only trigger it.
class const SessionContinuationService({
  required final SessionContinuationRepository _continuations,
  required final SessionRepository _sessions,
  required final SessionViewService _views,
  required final SessionOperationDispatcher _operations,
  required final SessionPromptService _prompts,
  required final SessionMutationDispatcher _mutations,
  required final Duration _resetBuffer,
  required final Duration _pauseRecheckDelay,
  required final Clock _clock,
}) {
  Future<Session> setEnabled({required String sessionId, required bool enabled}) => _operations.dispatch(
    sessionId: sessionId,
    operation: SessionOperation.setAutoContinuation,
    body: () async {
      final before = await _views.get(sessionId: sessionId);
      if (before.autoContinuation?.enabled == enabled) return before;
      if (enabled && before.autoContinuation?.availability != AutoContinuationAvailability.conditional) {
        throw const SessionAutoContinuationUnavailableException();
      }
      await _continuations.setEnabledAlreadyReserved(sessionId: sessionId, enabled: enabled);
      final updated = await _views.get(sessionId: sessionId);
      _notify(session: updated);
      return updated;
    },
  );

  Future<void> observeQuota({
    required String sessionId,
    required String pluginId,
    required int generation,
    required String errorMessageId,
    required DateTime observedAt,
    required DateTime? resetAt,
  }) => _operations.dispatch(
    sessionId: sessionId,
    operation: SessionOperation.observeQuotaInterruption,
    body: () async {
      final changed = await _continuations.recordObservationForCurrentGenerationAlreadyReserved(
        sessionId: sessionId,
        pluginId: pluginId,
        generation: generation,
        errorMessageId: errorMessageId,
        observedAt: observedAt.toUtc(),
        resetAt: resetAt != null && resetAt.isAfter(observedAt) ? resetAt.toUtc() : null,
      );
      if (changed) await _publish(sessionId: sessionId);
    },
  );

  Future<void> observeSupersedingActivity({
    required String sessionId,
    required String pluginId,
    required int generation,
  }) => _operations.dispatch(
    sessionId: sessionId,
    operation: SessionOperation.cancelQuotaContinuation,
    body: () async {
      if (await _continuations.cancelForCurrentGenerationAlreadyReserved(
        sessionId: sessionId,
        pluginId: pluginId,
        generation: generation,
      )) {
        await _publish(sessionId: sessionId);
      }
    },
  );

  Future<void> runDue() async {
    final now = _clock.now();
    final records = await _continuations.readEnabledReadyToCheck(
      resetCutoff: now.subtract(_resetBuffer),
      pausedRecheckCutoff: now,
    );
    for (final record in records) {
      try {
        await _operations.dispatch(
          sessionId: record.sessionId,
          operation: SessionOperation.continueAfterQuota,
          body: () => _attemptAlreadyReserved(sessionId: record.sessionId),
        );
      } on Object catch (error, stackTrace) {
        Log.w("Quota continuation check failed for session ${record.sessionId}", error, stackTrace);
      }
    }
  }

  Future<void> _attemptAlreadyReserved({required String sessionId}) async {
    final now = _clock.now();
    final record = await _continuations.readReadyToCheck(
      sessionId: sessionId,
      resetCutoff: now.subtract(_resetBuffer),
      pausedRecheckCutoff: now,
    );
    if (record == null) return;
    final (errorMessageId, observedAt, resetAt) = switch (record.outcome) {
      SessionContinuationResetKnown(:final errorMessageId, :final observedAt, :final resetAt) ||
      SessionContinuationPaused(
        :final errorMessageId,
        :final observedAt,
        :final resetAt,
      ) => (errorMessageId, observedAt, resetAt),
      _ => throw StateError("Eligible continuation has no known reset: $sessionId"),
    };
    Future<void> pause({required AutoContinuationPauseReason reason}) => _pause(
      record: record,
      errorMessageId: errorMessageId,
      observedAt: observedAt,
      resetAt: resetAt,
      reason: reason,
    );
    final readiness = await _readiness(sessionId: sessionId);
    if (readiness != SessionContinuationReadiness.idle) {
      await pause(reason: _pauseReason(readiness: readiness));
      return;
    }
    final SessionMessagesSnapshot snapshot;
    try {
      snapshot = await _sessions.getSessionMessages(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Quota continuation could not read history for session $sessionId", error, stackTrace);
      await pause(reason: AutoContinuationPauseReason.historyUnavailable);
      return;
    }
    final last = snapshot.messages.lastOrNull?.info;
    if (last is! MessageError || last.id != errorMessageId) {
      await _continuations.cancelCurrentObservationAlreadyReserved(sessionId: sessionId);
      await _publish(sessionId: sessionId);
      return;
    }
    final finalReadiness = await _readiness(sessionId: sessionId);
    if (finalReadiness != SessionContinuationReadiness.idle) {
      await pause(reason: _pauseReason(readiness: finalReadiness));
      return;
    }
    final promptId = SessionPromptService.generatePromptId();
    await _continuations.writeOutcomeAlreadyReserved(
      record: record,
      outcome: SessionContinuationOutcome.consumed(
        errorMessageId: errorMessageId,
        promptId: promptId,
        attemptedAt: _clock.now(),
      ),
    );
    final defaults = snapshot.promptDefaults;
    final model = defaults?.model;
    try {
      await _prompts.sendPromptAlreadyReserved(
        sessionId: sessionId,
        promptId: promptId,
        parts: const [PromptPart.text(text: "Continue.")],
        agent: defaults?.agent,
        model: model == null ? null : PromptModel(providerID: model.providerID, modelID: model.modelID),
        variant: model?.variant == null ? null : SessionVariant(id: model!.variant!),
        fastMode: defaults?.fastMode ?? false,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Quota continuation submission failed for session $sessionId, prompt $promptId", error, stackTrace);
      await _continuations.writeOutcomeAlreadyReserved(
        record: record,
        outcome: SessionContinuationOutcome.submissionFailed(
          errorMessageId: errorMessageId,
          reason: AutoContinuationFailureReason.submissionRejected,
        ),
      );
      await _publish(sessionId: sessionId);
      return;
    }
    // Keep acceptance separate from recording it: a failed write leaves the
    // consumed marker visible as unconfirmed and must never trigger a resend.
    try {
      await _continuations.writeOutcomeAlreadyReserved(
        record: record,
        outcome: SessionContinuationOutcome.submitted(
          errorMessageId: errorMessageId,
          promptId: promptId,
          acceptedAt: _clock.now(),
        ),
      );
    } on Object catch (error, stackTrace) {
      Log.w("Could not record accepted quota continuation for session $sessionId, prompt $promptId", error, stackTrace);
    }
    await _publish(sessionId: sessionId);
  }

  Future<SessionContinuationReadiness> _readiness({required String sessionId}) async {
    try {
      return await _sessions.getQuotaContinuationReadiness(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Quota continuation readiness unavailable for session $sessionId", error, stackTrace);
      return SessionContinuationReadiness.unavailable;
    }
  }

  Future<void> _pause({
    required SessionContinuationRecord record,
    required String errorMessageId,
    required DateTime observedAt,
    required DateTime resetAt,
    required AutoContinuationPauseReason reason,
  }) async {
    await _continuations.writeOutcomeAlreadyReserved(
      record: record,
      outcome: SessionContinuationOutcome.paused(
        errorMessageId: errorMessageId,
        observedAt: observedAt,
        resetAt: resetAt,
        reason: reason,
        recheckAt: _clock.now().add(_pauseRecheckDelay),
      ),
    );
    // Moving only the private recheck deadline does not change the client view.
    if (record.outcome case SessionContinuationPaused(reason: final previous) when previous == reason) return;
    await _publish(sessionId: record.sessionId);
  }

  Future<void> _publish({required String sessionId}) async {
    try {
      _notify(session: await _views.get(sessionId: sessionId));
    } on Object catch (error, stackTrace) {
      Log.w("Could not project quota continuation for session $sessionId", error, stackTrace);
    }
  }

  void _notify({required Session session}) {
    try {
      _mutations.continuationUpdated(session: session);
    } on Object catch (error, stackTrace) {
      Log.w("Could not publish quota continuation for session ${session.id}", error, stackTrace);
    }
  }

  static AutoContinuationPauseReason _pauseReason({required SessionContinuationReadiness readiness}) =>
      switch (readiness) {
        SessionContinuationReadiness.busy => AutoContinuationPauseReason.busy,
        SessionContinuationReadiness.retrying => AutoContinuationPauseReason.retrying,
        SessionContinuationReadiness.queued => AutoContinuationPauseReason.queued,
        SessionContinuationReadiness.awaitingInput => AutoContinuationPauseReason.awaitingInput,
        SessionContinuationReadiness.unavailable => AutoContinuationPauseReason.unavailable,
        SessionContinuationReadiness.idle ||
        SessionContinuationReadiness.unknown => AutoContinuationPauseReason.unknown,
      };
}
