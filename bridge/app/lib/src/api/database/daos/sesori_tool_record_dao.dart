import "package:drift/drift.dart";

import "../database.dart";
import "../tables/sesori_tool_records_table.dart";
import "../tables/sesori_tool_session_records_table.dart";

part "sesori_tool_record_dao.g.dart";

@DriftAccessor(tables: [SesoriToolSessionRecordsTable, SesoriToolRecordsTable])
class SesoriToolRecordDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$SesoriToolRecordDaoMixin {
  this : super(database);

  Future<SesoriToolSessionRecordDto?> getSessionRecord({
    required String groupId,
    required String sessionId,
    required String recordKey,
  }) {
    return (select(sesoriToolSessionRecordsTable)..where(
          (row) => row.groupId.equals(groupId) & row.sessionId.equals(sessionId) & row.recordKey.equals(recordKey),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertSessionRecord({required SesoriToolSessionRecordDto row}) async {
    await into(sesoriToolSessionRecordsTable).insertOnConflictUpdate(row);
  }

  /// True when the record existed.
  Future<bool> deleteSessionRecord({
    required String groupId,
    required String sessionId,
    required String recordKey,
  }) async {
    final statement = delete(sesoriToolSessionRecordsTable)
      ..where((row) => row.groupId.equals(groupId) & row.sessionId.equals(sessionId) & row.recordKey.equals(recordKey));
    return await statement.go() > 0;
  }

  Future<List<SesoriToolSessionRecordDto>> listRecordsOfSession({required String groupId, required String sessionId}) {
    return (select(sesoriToolSessionRecordsTable)
          ..where((row) => row.groupId.equals(groupId) & row.sessionId.equals(sessionId))
          ..orderBy([(row) => OrderingTerm.asc(row.recordKey)]))
        .get();
  }

  /// [groupId]'s records of every session.
  Future<List<SesoriToolSessionRecordDto>> listSessionRecords({required String groupId}) {
    return (select(sesoriToolSessionRecordsTable)
          ..where((row) => row.groupId.equals(groupId))
          ..orderBy([(row) => OrderingTerm.asc(row.sessionId), (row) => OrderingTerm.asc(row.recordKey)]))
        .get();
  }

  Future<SesoriToolRecordDto?> getRecord({required String groupId, required String recordKey}) {
    return (select(
      sesoriToolRecordsTable,
    )..where((row) => row.groupId.equals(groupId) & row.recordKey.equals(recordKey))).getSingleOrNull();
  }

  Future<void> upsertRecord({required SesoriToolRecordDto row}) async {
    await into(sesoriToolRecordsTable).insertOnConflictUpdate(row);
  }

  /// True when the record existed.
  Future<bool> deleteRecord({required String groupId, required String recordKey}) async {
    final statement = delete(sesoriToolRecordsTable)
      ..where((row) => row.groupId.equals(groupId) & row.recordKey.equals(recordKey));
    return await statement.go() > 0;
  }

  Future<List<SesoriToolRecordDto>> listRecords({required String groupId}) {
    return (select(sesoriToolRecordsTable)
          ..where((row) => row.groupId.equals(groupId))
          ..orderBy([(row) => OrderingTerm.asc(row.recordKey)]))
        .get();
  }
}
