import "package:drift/drift.dart";

import "session_table.dart";

@TableIndex(
  name: "idx_device_canvas_claims_session",
  columns: {#sessionId},
)
class DeviceCanvasClaimsTable() extends Table {
  @override
  String get tableName => "device_canvas_claims_table";

  TextColumn get bridgeId => text()();
  TextColumn get deviceKey => text()();
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  IntColumn get claimRevision => integer()();
  IntColumn get claimedAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column>? get primaryKey => {bridgeId, deviceKey};
}
