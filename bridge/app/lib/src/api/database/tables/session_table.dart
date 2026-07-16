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

@TableIndex(
  name: "idx_sessions_plugin_backend",
  columns: {#pluginId, #backendSessionId},
  unique: true,
)
@TableIndex(
  name: "idx_sessions_roots",
  columns: {#projectId, #parentSessionId, #updatedAt, #sessionId},
)
@TableIndex(
  name: "idx_sessions_children",
  columns: {#parentSessionId, #updatedAt, #sessionId},
)
@TableIndex.sql(
  "CREATE INDEX idx_sessions_archive ON sessions_table "
  "(updated_at DESC, session_id DESC) WHERE archived_at IS NOT NULL",
)
@UseRowClass(SessionDto)
class SessionTable extends Table {
  @override
  String get tableName => "sessions_table";

  TextColumn get sessionId => text()();
  TextColumn get backendSessionId => text()();
  TextColumn get projectId => text().references(ProjectsTable, #projectId, onDelete: KeyAction.cascade)();
  TextColumn get parentSessionId =>
      text().nullable().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  TextColumn get directory => text()();
  TextColumn get worktreePath => text().nullable()();
  TextColumn get branchName => text().nullable()();
  BoolColumn get isDedicated => boolean()();
  IntColumn get archivedAt => integer().nullable()();
  TextColumn get baseBranch => text().nullable()();
  TextColumn get baseCommit => text().nullable()();
  TextColumn get lastAgent => text().nullable()();
  TextColumn get lastAgentModel => text().nullable().map(const AgentModelConverter())();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get projectionUpdatedAt => integer()();

  // ── Unseen-changes tracking (ms since epoch; null == 0 == "seen") ──────────
  // Last activity of ANY kind (user OR AI message, question.asked,
  // permission.asked).
  IntColumn get lastActivityAt => integer().nullable()();

  // Last time the user "saw" this session: viewing the detail screen (open /
  // while-viewing / close) or an explicit "Mark as Read".
  IntColumn get lastSeenAt => integer().nullable()();

  // Last user-originated interaction (user message, question/permission reply).
  // Kept pure (separate from viewing) for forward-looking features.
  IntColumn get lastUserMessageAt => integer().nullable()();

  /// The id of the plugin that owns this session (e.g. "opencode", "codex").
  /// No default — every insert stamps the active plugin's id explicitly; the
  /// v7→v8 migration backfills pre-existing rows itself.
  TextColumn get pluginId => text()();

  /// The bridge-owned title override from an explicit rename or a
  /// title-bearing `session.updated` event. This wins over the latest observed
  /// catalog title for every plugin. Null means the catalog title is rendered.
  TextColumn get title => text().nullable()();
  TextColumn get catalogTitle => text().nullable()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {sessionId};
}

@freezed
sealed class SessionDto with _$SessionDto, $SessionTableTableToColumns {
  const factory SessionDto({
    required String sessionId,
    required String backendSessionId,
    required String projectId,
    required String? parentSessionId,
    required String directory,
    required String? worktreePath,
    required String? branchName,
    required bool isDedicated,
    required int? archivedAt,
    required String? baseBranch,
    required String? baseCommit,
    required String? lastAgent,
    required AgentModel? lastAgentModel,
    required int createdAt,
    required int updatedAt,
    required int projectionUpdatedAt,
    required int? lastActivityAt,
    required int? lastSeenAt,
    required int? lastUserMessageAt,
    required String pluginId,
    required String? title,
    required String? catalogTitle,
  }) = _SessionDto;

  const SessionDto._();
}
