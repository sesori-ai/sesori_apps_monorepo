import "package:drift/drift.dart";

import "../converters/agent_model_converter.dart";

class NewSessionDefaultsTable() extends Table {
  @override
  String get tableName => "new_session_defaults_table";

  TextColumn get pluginId => text()();
  TextColumn get agent => text().nullable()();
  TextColumn get agentModel => text().nullable().map(const AgentModelConverter())();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {pluginId};

  @override
  List<String> get customConstraints => const ["CHECK (plugin_id <> '')"];
}
