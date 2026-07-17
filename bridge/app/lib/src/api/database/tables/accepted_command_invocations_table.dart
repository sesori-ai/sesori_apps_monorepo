import "package:drift/drift.dart";

import "session_table.dart";

@TableIndex(
  name: "idx_accepted_commands_plugin_session",
  columns: {#pluginId, #sessionId, #acceptedAt, #invocationId},
)
@DataClassName("AcceptedCommandInvocationDto")
class AcceptedCommandInvocationsTable extends Table {
  @override
  String get tableName => "accepted_command_invocations_table";

  TextColumn get invocationId => text()();
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  TextColumn get pluginId => text()();
  TextColumn get name => text()();
  TextColumn get arguments => text().nullable()();
  IntColumn get acceptedAt => integer()();
  TextColumn get backendMessageId => text().nullable()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column<Object>> get primaryKey => {invocationId};
}
