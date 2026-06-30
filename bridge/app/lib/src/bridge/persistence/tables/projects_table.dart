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

  /// Bridge-persisted display-name override for a renamed project. Used by
  /// bridge-derived plugins, which have no backend to store a project name;
  /// null means fall back to the directory basename.
  TextColumn get displayName => text().nullable()();

  /// Wall-clock ms when the user explicitly opened this folder. Lets a folder
  /// with no sessions yet survive a refresh, and doubles as the project's time
  /// until a session supplies one. Null for projects discovered purely from
  /// sessions.
  IntColumn get openedAt => integer().nullable()();

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
    String? displayName,
    int? openedAt,
  }) = _ProjectDto;

  const ProjectDto._();
}
