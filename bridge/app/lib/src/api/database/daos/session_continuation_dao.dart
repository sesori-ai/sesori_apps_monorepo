import "package:drift/drift.dart";

import "../database.dart";
import "../tables/session_continuation_table.dart";

part "session_continuation_dao.g.dart";

@DriftAccessor(tables: [SessionContinuationTable])
class SessionContinuationDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$SessionContinuationDaoMixin {
  this : super(database);

  Future<SessionContinuationDto?> read({required String sessionId}) =>
      (select(sessionContinuationTable)..where((row) => row.sessionId.equals(sessionId))).getSingleOrNull();

  Future<List<SessionContinuationDto>> readMany({required Set<String> sessionIds}) => sessionIds.isEmpty
      ? Future.value(const [])
      : (select(sessionContinuationTable)..where((row) => row.sessionId.isIn(sessionIds))).get();

  Future<List<SessionContinuationDto>> readEnabled() =>
      (select(sessionContinuationTable)..where((row) => row.enabled.equals(true))).get();

  Future<void> upsert({required SessionContinuationDto row}) async {
    await into(sessionContinuationTable).insertOnConflictUpdate(row);
  }
}
