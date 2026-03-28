import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "projects_table.freezed.dart";

@UseRowClass(ProjectDto)
class ProjectsTable extends Table {
  TextColumn get projectId => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get baseBranch => text().nullable()();
  IntColumn get worktreeCounter => integer().withDefault(const Constant(0))();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {projectId};
}

@freezed
sealed class ProjectDto with _$ProjectDto, $ProjectsTableTableToColumns {
  const factory ProjectDto({
    required String projectId,
    @Default(false) bool hidden,
    String? baseBranch,
    @Default(0) int worktreeCounter,
  }) = _ProjectDto;

  const ProjectDto._();
}
