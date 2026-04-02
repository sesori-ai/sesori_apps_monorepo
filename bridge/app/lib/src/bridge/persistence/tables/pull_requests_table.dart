import "package:drift/drift.dart";

import "session_table.dart";

class PullRequestsTable extends Table {
  @override
  String get tableName => "pull_requests_table";

  TextColumn get projectId => text()();
  TextColumn get branchName => text()();
  IntColumn get prNumber => integer()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get state => text()();
  TextColumn get mergeableStatus => text().nullable()();
  TextColumn get reviewDecision => text().nullable()();
  TextColumn get checkStatus => text().nullable()();
  TextColumn get sessionId => text().nullable().references(SessionTable, #sessionId)();
  IntColumn get lastCheckedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {projectId, branchName};
}
