import "../api/database/daos/session_interruption_dao.dart";
import "mappers/session_interruption_mapper.dart";
import "models/session_interruption_record.dart";
import "models/session_running_turn_record.dart";

/// Sole owner of the running-turn and interruption records. A running row
/// says a turn is in flight; one left from an earlier bridge run says that
/// run stopped during the turn, and becomes the session's interruption.
class const SessionInterruptionRepository({required final SessionInterruptionDao _dao}) {
  static const _mapper = SessionInterruptionMapper();

  /// Records that the session has a turn running as of [at]. A row an earlier
  /// bridge run left takes the new time, so it is no longer left over.
  Future<void> markRunning({required String sessionId, required DateTime at}) =>
      _dao.upsertRunning(sessionId: sessionId, startedAt: at.millisecondsSinceEpoch);

  Future<void> clearRunning({required String sessionId}) => _dao.deleteRunning(sessionId: sessionId);

  /// The running rows of [pluginId]'s sessions written before
  /// [startedBefore], the start of this bridge run.
  Future<List<SessionRunningTurnRecord>> readLeftovers({
    required String pluginId,
    required DateTime startedBefore,
  }) async => [
    for (final row in await _dao.readRunningOfPluginBefore(
      pluginId: pluginId,
      startedBefore: startedBefore.millisecondsSinceEpoch,
    ))
      SessionRunningTurnRecord(
        sessionId: row.sessionId,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row.startedAt, isUtc: true),
      ),
  ];

  /// Takes over a [leftover] turn that is still running: its row now dates
  /// from [now], so this run's idle clears it. Like [convertLeftover], it
  /// acts only while the row is unchanged. Returns whether it did.
  Future<bool> adoptLeftover({required SessionRunningTurnRecord leftover, required DateTime now}) =>
      _dao.transaction(() async {
        if (!await _isUnchanged(leftover: leftover)) return false;
        await _dao.updateRunningStartedAt(sessionId: leftover.sessionId, startedAt: now.millisecondsSinceEpoch);
        return true;
      });

  /// Turns a [leftover] turn that is no longer running into the session's
  /// unacknowledged interruption after [afterMessageId], replacing an older
  /// one, and drops its running row, in one transaction. A session with no
  /// stored message ([afterMessageId] null) only loses the row. Returns
  /// whether an interruption was written.
  ///
  /// It acts only while the row still holds the time [leftover] was read
  /// with: a newer time means a turn of this run started after the status
  /// read, and that row is not this one's to resolve.
  Future<bool> convertLeftover({
    required SessionRunningTurnRecord leftover,
    required String? afterMessageId,
  }) => _dao.transaction(() async {
    final sessionId = leftover.sessionId;
    if (!await _isUnchanged(leftover: leftover)) return false;
    await _dao.deleteRunning(sessionId: sessionId);
    if (afterMessageId == null) return false;
    await _dao.upsertInterruption(
      row: _mapper.toDto(
        record: SessionInterruptionRecord(sessionId: sessionId, afterMessageId: afterMessageId, acknowledged: false),
      ),
    );
    return true;
  });

  /// Returns whether an unacknowledged interruption became acknowledged.
  Future<bool> acknowledge({required String sessionId}) async =>
      await _dao.acknowledgeInterruption(sessionId: sessionId) > 0;

  /// Moves the session's interruption onto the message that replaced its
  /// anchor in a re-import. Returns whether the anchor moved.
  Future<bool> reanchor({required String sessionId, required Map<String, String> replacementIds}) async {
    final row = (await _dao.readInterruptions(sessionIds: {sessionId})).firstOrNull;
    if (row == null) return false;
    final replacement = replacementIds[row.afterMessageId];
    if (replacement == null || replacement == row.afterMessageId) return false;
    return await _dao.updateInterruptionAnchor(
          sessionId: sessionId,
          fromMessageId: row.afterMessageId,
          toMessageId: replacement,
        ) >
        0;
  }

  Future<Map<String, SessionInterruptionRecord>> readMany({required Set<String> sessionIds}) async => {
    for (final row in await _dao.readInterruptions(sessionIds: sessionIds)) row.sessionId: _mapper.fromDto(row: row),
  };

  Future<bool> _isUnchanged({required SessionRunningTurnRecord leftover}) async {
    final running = await _dao.readRunning(sessionId: leftover.sessionId);
    return running != null && running.startedAt == leftover.startedAt.millisecondsSinceEpoch;
  }
}
