import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "session_worktrees_table.freezed.dart";

@UseRowClass(SessionWorktree)
class SessionWorktreesTable extends Table {
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
sealed class SessionWorktree with _$SessionWorktree, $SessionWorktreesTableTableToColumns {
  const factory SessionWorktree({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) = _SessionWorktree;

  const SessionWorktree._();
}
