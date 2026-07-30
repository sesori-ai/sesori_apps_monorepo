import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../database.dart";
import "projects_table.dart";

part "session_options_cache_table.freezed.dart";

@UseRowClass(SessionOptionsCacheDto)
class SessionOptionsCacheTable extends Table {
  @override
  String get tableName => "session_options_cache_table";

  TextColumn get pluginId => text()();
  Column<String> get scope => textEnum<PluginSessionOptionsScope>()();
  TextColumn get ownerId => text()();
  TextColumn get projectId => text().nullable().references(ProjectsTable, #projectId, onDelete: KeyAction.cascade)();
  TextColumn get capturedProjectPath => text().nullable()();
  IntColumn get revision => integer()();
  IntColumn get capturedAt => integer()();
  Column<String> get completeness => textEnum<PluginSessionOptionsCompleteness>()();
  TextColumn get agentsJson => text()();
  TextColumn get providersJson => text()();
  TextColumn get commandsJson => text()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {pluginId, scope, ownerId};

  @override
  List<String> get customConstraints => const [
    "CHECK (owner_id <> '' AND ((scope = 'plugin' AND project_id IS NULL AND captured_project_path IS NULL) OR (scope = 'project' AND project_id IS NOT NULL AND owner_id = project_id AND captured_project_path IS NOT NULL AND captured_project_path <> '')))",
  ];
}

@freezed
sealed class SessionOptionsCacheDto with _$SessionOptionsCacheDto, $SessionOptionsCacheTableTableToColumns {
  const factory SessionOptionsCacheDto({
    required String pluginId,
    required PluginSessionOptionsScope scope,
    required String ownerId,
    required String? projectId,
    required String? capturedProjectPath,
    required int revision,
    required int capturedAt,
    required PluginSessionOptionsCompleteness completeness,
    required String agentsJson,
    required String providersJson,
    required String commandsJson,
  }) = _SessionOptionsCacheDto;

  const SessionOptionsCacheDto._();
}
