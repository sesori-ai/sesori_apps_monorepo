import "package:drift/drift.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class SessionOptionsCacheTable extends Table {
  @override
  String get tableName => "session_options_cache_table";

  TextColumn get pluginId => text()();
  Column<String> get scope => textEnum<PluginSessionOptionsScope>()();
  TextColumn get ownerId => text()();
  TextColumn get projectId =>
      text().nullable().customConstraint("NULL REFERENCES projects_table (project_id) ON DELETE CASCADE")();
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
