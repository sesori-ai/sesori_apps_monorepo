import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "projects_table.freezed.dart";

@UseRowClass(Project)
class ProjectsTable extends Table {
  TextColumn get projectId => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {projectId};
}

@freezed
sealed class Project with _$Project, $ProjectsTableTableToColumns {
  const factory Project({
    required String projectId,
    @Default(false) bool hidden,
  }) = _Project;

  const Project._();
}
