import "package:drift/drift.dart";

import "../database.dart";
import "../tables/session_interruptions_table.dart";
import "../tables/session_running_turns_table.dart";
import "../tables/session_table.dart";

part "session_interruption_dao.g.dart";

@DriftAccessor(tables: [SessionRunningTurnsTable, SessionInterruptionsTable, SessionTable])
class SessionInterruptionDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$SessionInterruptionDaoMixin {
  this : super(database);

  Future<void> upsertRunning({required String sessionId, required int startedAt}) async {
    await into(sessionRunningTurnsTable).insertOnConflictUpdate(
      SessionRunningTurnDto(sessionId: sessionId, startedAt: startedAt),
    );
  }

  Future<void> deleteRunning({required String sessionId}) async {
    await (delete(sessionRunningTurnsTable)..where((row) => row.sessionId.equals(sessionId))).go();
  }

  Future<SessionRunningTurnDto?> readRunning({required String sessionId}) =>
      (select(sessionRunningTurnsTable)..where((row) => row.sessionId.equals(sessionId))).getSingleOrNull();

  /// The running rows of [pluginId]'s sessions written before [startedBefore].
  Future<List<SessionRunningTurnDto>> readRunningOfPluginBefore({
    required String pluginId,
    required int startedBefore,
  }) async {
    final query =
        select(sessionRunningTurnsTable).join([
          innerJoin(sessionTable, sessionTable.sessionId.equalsExp(sessionRunningTurnsTable.sessionId)),
        ])..where(
          sessionTable.pluginId.equals(pluginId) & sessionRunningTurnsTable.startedAt.isSmallerThanValue(startedBefore),
        );
    return [for (final row in await query.get()) row.readTable(sessionRunningTurnsTable)];
  }

  Future<void> updateRunningStartedAt({required String sessionId, required int startedAt}) async {
    await (update(sessionRunningTurnsTable)..where((row) => row.sessionId.equals(sessionId))).write(
      SessionRunningTurnsTableCompanion(startedAt: Value(startedAt)),
    );
  }

  Future<List<SessionInterruptionDto>> readInterruptions({required Set<String> sessionIds}) => sessionIds.isEmpty
      ? Future.value(const [])
      : (select(sessionInterruptionsTable)..where((row) => row.sessionId.isIn(sessionIds))).get();

  Future<void> upsertInterruption({required SessionInterruptionDto row}) async {
    await into(sessionInterruptionsTable).insertOnConflictUpdate(row);
  }

  /// Marks the session's interruption acknowledged; returns how many rows
  /// changed, so zero when it had none or it was already acknowledged.
  Future<int> acknowledgeInterruption({required String sessionId}) =>
      (update(sessionInterruptionsTable)
            ..where((row) => row.sessionId.equals(sessionId) & row.acknowledged.equals(false)))
          .write(const SessionInterruptionsTableCompanion(acknowledged: Value(true)));

  /// Moves the session's interruption from [fromMessageId] to [toMessageId];
  /// returns how many rows changed.
  Future<int> updateInterruptionAnchor({
    required String sessionId,
    required String fromMessageId,
    required String toMessageId,
  }) =>
      (update(sessionInterruptionsTable)
            ..where((row) => row.sessionId.equals(sessionId) & row.afterMessageId.equals(fromMessageId)))
          .write(SessionInterruptionsTableCompanion(afterMessageId: Value(toMessageId)));
}
