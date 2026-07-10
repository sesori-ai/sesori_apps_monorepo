import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "projects_table.freezed.dart";

@UseRowClass(ProjectDto)
class ProjectsTable extends Table {
  TextColumn get projectId => text()();

  /// The project's live directory on disk. This may differ from [projectId]
  /// after a folder move; the id remains the stable bridge/client handle.
  TextColumn get path => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get baseBranch => text().nullable()();
  IntColumn get worktreeCounter => integer().withDefault(const Constant(0))();

  /// Bridge-persisted display-name override for a renamed project. Used by
  /// bridge-derived plugins, which have no backend to store a project name;
  /// null means fall back to the directory basename.
  TextColumn get displayName => text().nullable()();

  /// Wall-clock ms when this project row was recorded — the folder was opened
  /// or the project was first discovered. Lets a folder with no sessions yet
  /// survive a refresh, and doubles as the project's time until a session
  /// supplies one. Stamped at insert time; re-opening a folder bumps it.
  IntColumn get openedAt => integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {projectId};
}

@freezed
sealed class ProjectDto with _$ProjectDto, $ProjectsTableTableToColumns {
  const factory ProjectDto({
    required String projectId,
    required String path,
    @Default(false) bool hidden,
    String? baseBranch,
    @Default(0) int worktreeCounter,
    String? displayName,
    required int openedAt,
  }) = _ProjectDto;

  const ProjectDto._();
}
