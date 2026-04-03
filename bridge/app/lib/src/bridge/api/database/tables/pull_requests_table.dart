import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../../../persistence/database.dart";
import "../../../persistence/tables/projects_table.dart";

part "pull_requests_table.freezed.dart";

@UseRowClass(PullRequestDto)
class PullRequestsTable extends Table {
  @override
  String get tableName => "pull_requests_table";

  TextColumn get projectId => text().references(ProjectsTable, #projectId, onDelete: KeyAction.cascade)();
  IntColumn get prNumber => integer()();
  TextColumn get branchName => text()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get state => text()();
  TextColumn get mergeableStatus => text()();
  TextColumn get reviewDecision => text()();
  TextColumn get checkStatus => text()();
  IntColumn get lastCheckedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {projectId, prNumber};
}

@freezed
sealed class PullRequestDto with _$PullRequestDto, $PullRequestsTableTableToColumns {
  const factory PullRequestDto({
    required String projectId,
    required int prNumber,
    required String branchName,
    required String url,
    required String title,
    required String state,
    required String mergeableStatus,
    required String reviewDecision,
    required String checkStatus,
    required int lastCheckedAt,
    required int createdAt,
  }) = _PullRequestDto;

  const PullRequestDto._();
}
