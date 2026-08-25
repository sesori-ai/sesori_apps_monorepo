// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_canvas_claim_dao.dart';

// ignore_for_file: type=lint
mixin _$DeviceCanvasClaimDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $DeviceCanvasClaimsTableTable get deviceCanvasClaimsTable =>
      attachedDatabase.deviceCanvasClaimsTable;
  $DeviceCanvasClaimRevisionsTableTable get deviceCanvasClaimRevisionsTable =>
      attachedDatabase.deviceCanvasClaimRevisionsTable;
  DeviceCanvasClaimDaoManager get managers => DeviceCanvasClaimDaoManager(this);
}

class DeviceCanvasClaimDaoManager {
  final _$DeviceCanvasClaimDaoMixin _db;
  DeviceCanvasClaimDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$DeviceCanvasClaimsTableTableTableManager get deviceCanvasClaimsTable =>
      $$DeviceCanvasClaimsTableTableTableManager(
        _db.attachedDatabase,
        _db.deviceCanvasClaimsTable,
      );
  $$DeviceCanvasClaimRevisionsTableTableTableManager
  get deviceCanvasClaimRevisionsTable =>
      $$DeviceCanvasClaimRevisionsTableTableTableManager(
        _db.attachedDatabase,
        _db.deviceCanvasClaimRevisionsTable,
      );
}
