import "package:drift/drift.dart";

class DeviceCanvasClaimRevisionsTable() extends Table {
  @override
  String get tableName => "device_canvas_claim_revisions_table";

  TextColumn get bridgeId => text()();
  IntColumn get lastRevision => integer()();

  @override
  Set<Column>? get primaryKey => {bridgeId};
}
