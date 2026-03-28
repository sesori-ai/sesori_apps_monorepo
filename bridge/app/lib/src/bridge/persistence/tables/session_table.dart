import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "session_table.freezed.dart";

@UseRowClass(SessionDto)
class SessionTable extends Table {
  @override
  String get tableName => "session_worktrees_table";

  TextColumn get sessionId => text()();
  TextColumn get projectId => text()();
  TextColumn get worktreePath => text()();
  TextColumn get branchName => text()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {sessionId};
}

@freezed
sealed class SessionDto with _$SessionDto, $SessionTableTableToColumns {
  const factory SessionDto({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) = _SessionDto;

  const SessionDto._();
}
