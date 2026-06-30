import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../database.dart";
import "projects_table.dart";

part "session_table.freezed.dart";

class AgentModelConverter extends TypeConverter<AgentModel, String> {
  const AgentModelConverter();

  @override
  AgentModel fromSql(String fromDb) {
    final parts = fromDb.split("|");
    return AgentModel(
      providerID: parts[0],
      modelID: parts[1],
      variant: parts.length > 2 ? parts[2] : null,
    );
  }

  @override
  String toSql(AgentModel value) {
    final variant = value.variant;
    return "${value.providerID}|${value.modelID}${variant != null ? "|$variant" : ""}";
  }
}

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
  TextColumn get lastAgent => text().nullable()();
  TextColumn get lastAgentModel => text().nullable().map(const AgentModelConverter())();
  IntColumn get createdAt => integer()();

  /// The id of the plugin that owns this session (e.g. "opencode", "codex").
  /// Defaults to "opencode" so the v6→v7 migration backfills every pre-existing
  /// row — opencode was the only shipped plugin. New sessions are stamped with
  /// the active plugin's id at insert.
  TextColumn get pluginId => text().withDefault(const Constant("opencode"))();

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
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required int createdAt,
    @Default("opencode") String pluginId,
  }) = _SessionDto;

  const SessionDto._();
}
