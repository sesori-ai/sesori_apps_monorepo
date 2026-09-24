import "../api/database/daos/session_continuation_dao.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/session_continuation_mapper.dart";
import "models/session_continuation_record.dart";
import "models/session_operation.dart";

/// Sole durable continuation owner. Callers serialize writes on the existing
/// session-operation lane; the service supplies all timing policy and cutoffs.
class const SessionContinuationRepository({
  required final SessionContinuationDao _dao,
  required final PluginRuntime _runtime,
}) {
  static const _mapper = SessionContinuationMapper();

  Future<SessionContinuationRecord> read({required String sessionId}) async {
    final row = await _dao.read(sessionId: sessionId);
    return row == null
        ? SessionContinuationRecord(
            sessionId: sessionId,
            enabled: false,
            outcome: const SessionContinuationOutcome.none(),
          )
        : _mapper.fromDto(row: row);
  }

  Future<Map<String, SessionContinuationRecord>> readMany({required Set<String> sessionIds}) async => {
    for (final row in await _dao.readMany(sessionIds: sessionIds)) row.sessionId: _mapper.fromDto(row: row),
  };

  Future<List<SessionContinuationRecord>> readEnabledReadyToCheck({
    required DateTime resetCutoff,
    required DateTime pausedRecheckCutoff,
  }) async => [
    for (final row in await _dao.readEnabled())
      if (_mapper.fromDto(row: row) case final record
          when _readyToCheck(record: record, resetCutoff: resetCutoff, pausedRecheckCutoff: pausedRecheckCutoff))
        record,
  ];

  Future<SessionContinuationRecord?> readReadyToCheck({
    required String sessionId,
    required DateTime resetCutoff,
    required DateTime pausedRecheckCutoff,
  }) async {
    final record = await read(sessionId: sessionId);
    return _readyToCheck(record: record, resetCutoff: resetCutoff, pausedRecheckCutoff: pausedRecheckCutoff)
        ? record
        : null;
  }

  Future<void> setEnabledAlreadyReserved({required String sessionId, required bool enabled}) async {
    final record = await read(sessionId: sessionId);
    if (record.enabled == enabled) return;
    await _write(
      record: SessionContinuationRecord(sessionId: sessionId, enabled: enabled, outcome: record.outcome),
    );
  }

  Future<bool> recordObservationForCurrentGenerationAlreadyReserved({
    required String sessionId,
    required String pluginId,
    required int generation,
    required String errorMessageId,
    required DateTime observedAt,
    required DateTime? resetAt,
  }) => _runtime.commitCurrentGeneration(
    pluginId: pluginId,
    generation: generation,
    operation: SessionOperation.observeQuotaInterruption,
    commit: () async {
      final record = await read(sessionId: sessionId);
      // Retain the original timing and never rearm a consumed/cancelled error.
      if (record.outcome.observationId == errorMessageId) return false;
      await writeOutcomeAlreadyReserved(
        record: record,
        outcome: resetAt == null
            ? SessionContinuationOutcome.resetUnknown(errorMessageId: errorMessageId, observedAt: observedAt)
            : SessionContinuationOutcome.resetKnown(
                errorMessageId: errorMessageId,
                observedAt: observedAt,
                resetAt: resetAt,
              ),
      );
      return true;
    },
  );

  Future<bool> cancelForCurrentGenerationAlreadyReserved({
    required String sessionId,
    required String pluginId,
    required int generation,
  }) => _runtime.commitCurrentGeneration(
    pluginId: pluginId,
    generation: generation,
    operation: SessionOperation.cancelQuotaContinuation,
    commit: () => cancelCurrentObservationAlreadyReserved(sessionId: sessionId),
  );

  Future<bool> cancelCurrentObservationAlreadyReserved({required String sessionId}) async {
    final record = await read(sessionId: sessionId);
    final errorMessageId = switch (record.outcome) {
      SessionContinuationResetKnown(:final errorMessageId) ||
      SessionContinuationResetUnknown(:final errorMessageId) ||
      SessionContinuationPaused(:final errorMessageId) => errorMessageId,
      _ => null,
    };
    if (errorMessageId == null) return false;
    await writeOutcomeAlreadyReserved(
      record: record,
      outcome: SessionContinuationOutcome.cancelled(errorMessageId: errorMessageId),
    );
    return true;
  }

  /// The continuation service owns scheduled transitions; this method only
  /// encodes and persists the chosen outcome while retaining the preference.
  Future<void> writeOutcomeAlreadyReserved({
    required SessionContinuationRecord record,
    required SessionContinuationOutcome outcome,
  }) => _write(
    record: SessionContinuationRecord(sessionId: record.sessionId, enabled: record.enabled, outcome: outcome),
  );

  Future<void> _write({required SessionContinuationRecord record}) => _dao.upsert(row: _mapper.toDto(record: record));

  static bool _readyToCheck({
    required SessionContinuationRecord record,
    required DateTime resetCutoff,
    required DateTime pausedRecheckCutoff,
  }) =>
      record.enabled &&
      switch (record.outcome) {
        SessionContinuationResetKnown(:final resetAt) => !resetAt.isAfter(resetCutoff),
        SessionContinuationPaused(:final resetAt, :final recheckAt) =>
          !resetAt.isAfter(resetCutoff) && !recheckAt.isAfter(pausedRecheckCutoff),
        _ => false,
      };
}
