import "package:drift/drift.dart";

import "../database.dart";
import "../tables/session_wake_ups_table.dart";

part "session_wake_up_dao.g.dart";

@DriftAccessor(tables: [SessionWakeUpsTable])
class SessionWakeUpDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$SessionWakeUpDaoMixin {
  this : super(database);

  Future<void> insertWakeUp({required SessionWakeUpDto row}) async {
    await into(sessionWakeUpsTable).insert(row);
  }

  /// [sessionId]'s wake-ups, soonest first.
  Future<List<SessionWakeUpDto>> listForSession({required String sessionId}) {
    return (select(sessionWakeUpsTable)
          ..where((row) => row.sessionId.equals(sessionId))
          ..orderBy([(row) => OrderingTerm.asc(row.nextDueAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  /// The wake-ups due at or before [nowMs], soonest first.
  Future<List<SessionWakeUpDto>> listDue({required int nowMs}) {
    return (select(sessionWakeUpsTable)
          ..where((row) => row.nextDueAt.isSmallerOrEqualValue(nowMs))
          ..orderBy([(row) => OrderingTerm.asc(row.nextDueAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  Future<bool> exists({required String id}) async {
    final query = selectOnly(sessionWakeUpsTable)
      ..addColumns([sessionWakeUpsTable.id])
      ..where(sessionWakeUpsTable.id.equals(id));
    return await query.getSingleOrNull() != null;
  }

  /// Deletes wake-up [id]; true when it existed.
  Future<bool> deleteWakeUp({required String id}) async {
    return await (delete(sessionWakeUpsTable)..where((row) => row.id.equals(id))).go() > 0;
  }

  /// Deletes wake-up [id] when it belongs to [sessionId]; true when it did.
  Future<bool> deleteSessionWakeUp({required String id, required String sessionId}) async {
    final statement = delete(sessionWakeUpsTable)
      ..where((row) => row.id.equals(id) & row.sessionId.equals(sessionId));
    return await statement.go() > 0;
  }

  Future<void> setNextDueAt({required String id, required int nextDueAtMs}) async {
    await (update(sessionWakeUpsTable)..where((row) => row.id.equals(id))).write(
      SessionWakeUpsTableCompanion(nextDueAt: Value(nextDueAtMs)),
    );
  }
}
