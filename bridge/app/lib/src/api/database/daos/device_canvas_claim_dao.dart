import "package:drift/drift.dart";

import "../database.dart";
import "../tables/device_canvas_claim_revisions_table.dart";
import "../tables/device_canvas_claims_table.dart";
import "../tables/session_table.dart";

part "device_canvas_claim_dao.g.dart";

@DriftAccessor(tables: [DeviceCanvasClaimsTable, DeviceCanvasClaimRevisionsTable, SessionTable])
class DeviceCanvasClaimDao(super.attachedDatabase)
    extends DatabaseAccessor<AppDatabase>
    with _$DeviceCanvasClaimDaoMixin {
  Future<DeviceCanvasClaimsTableData?> getClaim({
    required String bridgeId,
    required String deviceKey,
  }) {
    return (select(deviceCanvasClaimsTable)..where(
          (table) => table.bridgeId.equals(bridgeId) & table.deviceKey.equals(deviceKey),
        ))
        .getSingleOrNull();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForBridge({required String bridgeId}) {
    return (select(deviceCanvasClaimsTable)..where((table) => table.bridgeId.equals(bridgeId))).get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForBridgeBounded({
    required String bridgeId,
    required int limit,
  }) {
    return (select(deviceCanvasClaimsTable)
          ..where((table) => table.bridgeId.equals(bridgeId))
          ..orderBy([(table) => OrderingTerm.asc(table.deviceKey)])
          ..limit(limit))
        .get();
  }

  Future<int> countClaimsForBridge({required String bridgeId}) async {
    final count = deviceCanvasClaimsTable.deviceKey.count();
    final query = selectOnly(deviceCanvasClaimsTable)
      ..addColumns([count])
      ..where(deviceCanvasClaimsTable.bridgeId.equals(bridgeId));
    return await query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForBridgeSessionBounded({
    required String bridgeId,
    required String sessionId,
    required String? excludedDeviceKey,
    required int limit,
  }) {
    return (select(deviceCanvasClaimsTable)
          ..where(
            (table) =>
                table.bridgeId.equals(bridgeId) &
                table.sessionId.equals(sessionId) &
                (excludedDeviceKey == null ? const Constant(true) : table.deviceKey.equals(excludedDeviceKey).not()),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.deviceKey)])
          ..limit(limit))
        .get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForBridgeDevicesBounded({
    required String bridgeId,
    required String excludedSessionId,
    required Set<String> deviceKeys,
    required int limit,
  }) {
    if (deviceKeys.isEmpty) return Future.value(const []);
    return (select(deviceCanvasClaimsTable)
          ..where(
            (table) =>
                table.bridgeId.equals(bridgeId) &
                table.sessionId.equals(excludedSessionId).not() &
                table.deviceKey.isIn(deviceKeys),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.deviceKey)])
          ..limit(limit))
        .get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getOtherClaimsForBridgeBounded({
    required String bridgeId,
    required String excludedSessionId,
    required Set<String> excludedDeviceKeys,
    required int limit,
  }) {
    return (select(deviceCanvasClaimsTable)
          ..where(
            (table) =>
                table.bridgeId.equals(bridgeId) &
                table.sessionId.equals(excludedSessionId).not() &
                (excludedDeviceKeys.isEmpty ? const Constant(true) : table.deviceKey.isNotIn(excludedDeviceKeys)),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.deviceKey)])
          ..limit(limit))
        .get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForOtherBridges({required String bridgeId}) {
    return (select(deviceCanvasClaimsTable)..where((table) => table.bridgeId.equals(bridgeId).not())).get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForSession({required String sessionId}) {
    return (select(deviceCanvasClaimsTable)..where((table) => table.sessionId.equals(sessionId))).get();
  }

  Future<List<DeviceCanvasClaimsTableData>> getClaimsForSessions({required List<String> sessionIds}) {
    if (sessionIds.isEmpty) return Future.value(const []);
    return (select(deviceCanvasClaimsTable)..where((table) => table.sessionId.isIn(sessionIds))).get();
  }

  Future<int> nextClaimRevision({
    required String bridgeId,
    required int observedRevision,
  }) async {
    final stored = await (select(
      deviceCanvasClaimRevisionsTable,
    )..where((table) => table.bridgeId.equals(bridgeId))).getSingleOrNull();
    final highWater = stored == null || stored.lastRevision < observedRevision ? observedRevision : stored.lastRevision;
    final nextRevision = highWater + 1;
    await into(deviceCanvasClaimRevisionsTable).insertOnConflictUpdate(
      DeviceCanvasClaimRevisionsTableCompanion.insert(
        bridgeId: bridgeId,
        lastRevision: nextRevision,
      ),
    );
    return nextRevision;
  }

  Future<bool> insertClaimIfAbsent({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required int claimRevision,
    required int claimedAt,
    required int updatedAt,
  }) async {
    final inserted = await into(deviceCanvasClaimsTable).insert(
      DeviceCanvasClaimsTableCompanion.insert(
        bridgeId: bridgeId,
        deviceKey: deviceKey,
        sessionId: sessionId,
        claimRevision: claimRevision,
        claimedAt: claimedAt,
        updatedAt: updatedAt,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted > 0;
  }

  Future<bool> touchOwnedClaim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required int updatedAt,
  }) async {
    final updatedRows =
        await (update(deviceCanvasClaimsTable)..where(
              (table) =>
                  table.bridgeId.equals(bridgeId) &
                  table.deviceKey.equals(deviceKey) &
                  table.sessionId.equals(sessionId) &
                  table.updatedAt.isSmallerThanValue(updatedAt),
            ))
            .write(DeviceCanvasClaimsTableCompanion(updatedAt: Value(updatedAt)));
    return updatedRows == 1;
  }

  Future<bool> replaceOwnedClaim({
    required String bridgeId,
    required String deviceKey,
    required String expectedSessionId,
    required int expectedClaimRevision,
    required String sessionId,
    required int claimRevision,
    required int claimedAt,
    required int updatedAt,
  }) async {
    final updatedRows =
        await (update(deviceCanvasClaimsTable)..where(
              (table) =>
                  table.bridgeId.equals(bridgeId) &
                  table.deviceKey.equals(deviceKey) &
                  table.sessionId.equals(expectedSessionId) &
                  table.claimRevision.equals(expectedClaimRevision),
            ))
            .write(
              DeviceCanvasClaimsTableCompanion(
                sessionId: Value(sessionId),
                claimRevision: Value(claimRevision),
                claimedAt: Value(claimedAt),
                updatedAt: Value(updatedAt),
              ),
            );
    return updatedRows == 1;
  }

  Future<bool> deleteOwnedClaim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required int expectedClaimRevision,
  }) async {
    final deletedRows =
        await (delete(deviceCanvasClaimsTable)..where(
              (table) =>
                  table.bridgeId.equals(bridgeId) &
                  table.deviceKey.equals(deviceKey) &
                  table.sessionId.equals(sessionId) &
                  table.claimRevision.equals(expectedClaimRevision),
            ))
            .go();
    return deletedRows == 1;
  }

  Future<int> deleteClaimsForSession({required String sessionId}) {
    return (delete(deviceCanvasClaimsTable)..where((table) => table.sessionId.equals(sessionId))).go();
  }

  Future<int> deleteClaimsForSessions({required List<String> sessionIds}) {
    if (sessionIds.isEmpty) return Future.value(0);
    return (delete(deviceCanvasClaimsTable)..where((table) => table.sessionId.isIn(sessionIds))).go();
  }

  Future<int> deleteClaimsForBridge({required String bridgeId}) {
    return (delete(deviceCanvasClaimsTable)..where((table) => table.bridgeId.equals(bridgeId))).go();
  }

  Future<int> deleteClaimsForOtherBridges({required String bridgeId}) {
    return (delete(deviceCanvasClaimsTable)..where((table) => table.bridgeId.equals(bridgeId).not())).go();
  }

  Future<int> deleteUnavailableSessionClaims({required String bridgeId}) async {
    final statement = customUpdate(
      """
      DELETE FROM device_canvas_claims_table
      WHERE bridge_id = ?
        AND NOT EXISTS (
          SELECT 1
          FROM sessions_table
          WHERE sessions_table.session_id = device_canvas_claims_table.session_id
            AND sessions_table.archived_at IS NULL
        )
      """,
      variables: [Variable<String>(bridgeId)],
      updates: {deviceCanvasClaimsTable},
    );
    return await statement;
  }
}
