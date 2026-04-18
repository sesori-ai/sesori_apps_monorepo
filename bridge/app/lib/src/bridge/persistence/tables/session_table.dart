import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";
import "projects_table.dart";

part "session_table.freezed.dart";

@UseRowClass(SessionDto)
class SessionTable extends Table {
  @override
  String get tableName => "sessions_table";

  TextColumn get sessionId => text()();
  TextColumn get projectId => text().references(ProjectsTable, #projectId, onDelete: KeyAction.cascade)();
  TextColumn get worktreePath => text().nullable()();
  TextColumn get branchName => text().nullable()();
  BoolColumn get isDedicated => boolean()();
  IntColumn get archivedAt => integer().nullable()();
  TextColumn get baseBranch => text().nullable()();
  TextColumn get baseCommit => text().nullable()();
  IntColumn get createdAt => integer()();

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
    required String? worktreePath,
    required String? branchName,
    required bool isDedicated,
    required int? archivedAt,
    required String? baseBranch,
    required String? baseCommit,
    required int createdAt,
  }) = _SessionDto;

  const SessionDto._();
}
