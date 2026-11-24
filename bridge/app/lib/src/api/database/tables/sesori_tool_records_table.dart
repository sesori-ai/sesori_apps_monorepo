import "package:drift/drift.dart";

/// Records Sesori tool groups keep for the whole bridge, such as a group's
/// configuration.
@DataClassName("SesoriToolRecordDto")
class SesoriToolRecordsTable() extends Table {
  @override
  String get tableName => "sesori_tool_records";

  TextColumn get groupId => text()();
  TextColumn get recordKey => text()();

  /// A JSON object in the group's own format.
  TextColumn get valueJson => text()();

  /// UTC milliseconds.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {groupId, recordKey};

  @override
  bool get withoutRowId => true;
}
