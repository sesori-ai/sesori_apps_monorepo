import "../../api/database/daos/device_canvas_claim_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/database.dart" show DeviceCanvasClaimsTableData;

class const DeviceCanvasClaim({
  required final String bridgeId,
  required final String deviceKey,
  required final String sessionId,
  required final int claimRevision,
  required final int claimedAt,
  required final int updatedAt,
});

class const DeviceCanvasClaimProjection({
  required final String bridgeId,
  required final String projectId,
  required final String sessionId,
  required final String deviceKey,
  required final int claimRevision,
  required final int claimedAt,
  required final String? displayTitle,
});

class const DeviceCanvasClaimRemovalSnapshot({
  required final String bridgeId,
  required final String deviceKey,
  required final int claimRevision,
});

class const DeviceCanvasClaimProjectionPage({
  required final List<DeviceCanvasClaimProjection> projections,
  required final bool truncated,
});

sealed class const DeviceCanvasClaimAttempt();

final class const DeviceCanvasClaimed({required final DeviceCanvasClaim claim}) extends DeviceCanvasClaimAttempt;

final class const DeviceCanvasClaimAlreadyOwned({required final DeviceCanvasClaim claim})
    extends DeviceCanvasClaimAttempt;

final class const DeviceCanvasClaimReassigned({required final DeviceCanvasClaim claim})
    extends DeviceCanvasClaimAttempt;

final class const DeviceCanvasClaimConflict({required final DeviceCanvasClaim claim}) extends DeviceCanvasClaimAttempt;

final class const DeviceCanvasClaimSessionUnavailable() extends DeviceCanvasClaimAttempt;

final class const DeviceCanvasClaimDeviceUnavailable() extends DeviceCanvasClaimAttempt;

sealed class const DeviceCanvasReleaseAttempt();

final class const DeviceCanvasReleased({required final DeviceCanvasClaim claim}) extends DeviceCanvasReleaseAttempt;

final class const DeviceCanvasAlreadyReleased() extends DeviceCanvasReleaseAttempt;

final class const DeviceCanvasReleaseConflict({required final DeviceCanvasClaim claim})
    extends DeviceCanvasReleaseAttempt;

class DeviceCanvasClaimRepository({
  required final DeviceCanvasClaimDao _claimDao,
  required final SessionDao _sessionDao,
  required int Function() now,
}) {
  /// High-water marks for bridge-global claim revisions.
  ///
  /// A single durable counter per bridge prevents release/reclaim, archive,
  /// deletion, and FK-cascade cleanup from ever reusing a stale CAS token,
  /// without retaining one row for every historical device key.
  static const int maxProjectedClaims = 128;

  final int Function() _now = now;
  final Map<String, int> _lastClaimRevisions = <String, int>{};

  Future<List<DeviceCanvasClaim>> getClaimsForBridge({required String bridgeId}) async {
    final rows = await _claimDao.getClaimsForBridge(bridgeId: bridgeId);
    return rows.map(_mapClaim).toList(growable: false);
  }

  Future<DeviceCanvasClaim?> getClaim({required String bridgeId, required String deviceKey}) {
    return _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
  }

  Future<List<DeviceCanvasClaimProjection>> getClaimProjectionsForBridge({required String bridgeId}) async {
    final claims = (await _claimDao.getClaimsForBridgeBounded(
      bridgeId: bridgeId,
      limit: maxProjectedClaims,
    )).map(_mapClaim);
    final projections = <DeviceCanvasClaimProjection>[];
    for (final claim in claims) {
      final projection = await _projectClaim(claim);
      if (projection != null) projections.add(projection);
    }
    return projections;
  }

  Future<List<DeviceCanvasClaimProjection>> getClaimProjectionsForSession({required String sessionId}) async {
    final claims = (await _claimDao.getClaimsForSession(sessionId: sessionId)).map(_mapClaim);
    final projections = <DeviceCanvasClaimProjection>[];
    for (final claim in claims) {
      final projection = await _projectClaim(claim);
      if (projection != null) projections.add(projection);
    }
    return projections;
  }

  Future<DeviceCanvasClaimProjection?> getClaimProjection({
    required String bridgeId,
    required String deviceKey,
  }) async {
    final claim = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
    if (claim == null) return null;
    return await _projectClaim(claim);
  }

  Future<DeviceCanvasClaimProjectionPage> getClientClaimProjections({
    required String bridgeId,
    required String sessionId,
    required Set<String> liveDeviceKeys,
    required String? priorityDeviceKey,
    required int limit,
  }) async {
    final rows = <DeviceCanvasClaimsTableData>[];
    var truncated = false;

    Future<void> append(Future<List<DeviceCanvasClaimsTableData>> pendingRows) async {
      final candidates = await pendingRows;
      final remaining = limit - rows.length;
      if (candidates.length > remaining) truncated = true;
      rows.addAll(candidates.take(remaining));
    }

    if (priorityDeviceKey != null) {
      final priority = await _claimDao.getClaim(bridgeId: bridgeId, deviceKey: priorityDeviceKey);
      if (priority != null) rows.add(priority);
    }

    await append(
      _claimDao.getClaimsForBridgeSessionBounded(
        bridgeId: bridgeId,
        sessionId: sessionId,
        excludedDeviceKey: priorityDeviceKey,
        limit: limit - rows.length + 1,
      ),
    );
    final remainingAfterSession = limit - rows.length;
    await append(
      _claimDao.getClaimsForBridgeDevicesBounded(
        bridgeId: bridgeId,
        excludedSessionId: sessionId,
        deviceKeys: priorityDeviceKey == null ? liveDeviceKeys : liveDeviceKeys.difference({priorityDeviceKey}),
        limit: remainingAfterSession + 1,
      ),
    );
    final remainingAfterLiveDevices = limit - rows.length;
    await append(
      _claimDao.getOtherClaimsForBridgeBounded(
        bridgeId: bridgeId,
        excludedSessionId: sessionId,
        excludedDeviceKeys: priorityDeviceKey == null ? liveDeviceKeys : {...liveDeviceKeys, priorityDeviceKey},
        limit: remainingAfterLiveDevices + 1,
      ),
    );

    final projections = <DeviceCanvasClaimProjection>[];
    for (final row in rows) {
      final projection = await _projectClaim(_mapClaim(row));
      if (projection != null) projections.add(projection);
    }
    return DeviceCanvasClaimProjectionPage(
      projections: projections,
      truncated: truncated,
    );
  }

  Future<List<DeviceCanvasClaimRemovalSnapshot>> getClaimRemovalSnapshotsForSessions({
    required List<String> sessionIds,
  }) async {
    final claims = (await _claimDao.getClaimsForSessions(sessionIds: sessionIds))
        .map(_mapClaim)
        .toList(growable: false);
    _rememberClaimRevisions(claims);
    return [
      for (final claim in claims)
        DeviceCanvasClaimRemovalSnapshot(
          bridgeId: claim.bridgeId,
          deviceKey: claim.deviceKey,
          claimRevision: claim.claimRevision,
        ),
    ];
  }

  Future<DeviceCanvasClaimAttempt> claim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required bool Function() canClaimUnownedDevice,
  }) {
    return _claimDao.attachedDatabase.transaction(() async {
      final session = await _sessionDao.getSession(sessionId: sessionId);
      if (session == null || session.archivedAt != null) {
        return const DeviceCanvasClaimSessionUnavailable();
      }
      final tombstoned = await _sessionDao.isSessionTombstoned(
        backendSessionId: session.backendSessionId,
        pluginId: session.pluginId,
      );
      if (tombstoned) {
        return const DeviceCanvasClaimSessionUnavailable();
      }

      final now = _now();
      final existing = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
      if (existing != null) {
        _rememberRevision(existing);
        if (existing.sessionId != sessionId) {
          return DeviceCanvasClaimConflict(claim: existing);
        }
        await _claimDao.touchOwnedClaim(
          bridgeId: bridgeId,
          deviceKey: deviceKey,
          sessionId: sessionId,
          updatedAt: now,
        );
        return DeviceCanvasClaimAlreadyOwned(
          claim: (await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey))!,
        );
      }

      if (!canClaimUnownedDevice()) return const DeviceCanvasClaimDeviceUnavailable();
      if (await _claimDao.countClaimsForBridge(bridgeId: bridgeId) >= maxProjectedClaims) {
        return const DeviceCanvasClaimDeviceUnavailable();
      }

      final claimRevision = await _nextRevision(bridgeId: bridgeId);
      if (!canClaimUnownedDevice()) return const DeviceCanvasClaimDeviceUnavailable();
      await _claimDao.insertClaimIfAbsent(
        bridgeId: bridgeId,
        deviceKey: deviceKey,
        sessionId: sessionId,
        claimRevision: claimRevision,
        claimedAt: now,
        updatedAt: now,
      );
      final claimed = (await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey))!;
      _rememberRevision(claimed);
      if (claimed.sessionId != sessionId) return DeviceCanvasClaimConflict(claim: claimed);
      return DeviceCanvasClaimed(claim: claimed);
    });
  }

  Future<DeviceCanvasClaimAttempt> reassign({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required String expectedOwnerSessionId,
    required int expectedClaimRevision,
  }) {
    return _claimDao.attachedDatabase.transaction(() async {
      final session = await _sessionDao.getSession(sessionId: sessionId);
      if (session == null || session.archivedAt != null) {
        return const DeviceCanvasClaimSessionUnavailable();
      }
      final tombstoned = await _sessionDao.isSessionTombstoned(
        backendSessionId: session.backendSessionId,
        pluginId: session.pluginId,
      );
      if (tombstoned) return const DeviceCanvasClaimSessionUnavailable();

      final now = _now();
      final existing = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
      if (existing == null) return const DeviceCanvasClaimDeviceUnavailable();

      _rememberRevision(existing);
      if (existing.sessionId != expectedOwnerSessionId || existing.claimRevision != expectedClaimRevision) {
        return DeviceCanvasClaimConflict(claim: existing);
      }

      final replaced = await _claimDao.replaceOwnedClaim(
        bridgeId: bridgeId,
        deviceKey: deviceKey,
        expectedSessionId: expectedOwnerSessionId,
        expectedClaimRevision: expectedClaimRevision,
        sessionId: sessionId,
        claimRevision: await _nextRevision(bridgeId: bridgeId),
        claimedAt: now,
        updatedAt: now,
      );
      if (!replaced) {
        final current = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
        return current == null ? const DeviceCanvasClaimDeviceUnavailable() : DeviceCanvasClaimConflict(claim: current);
      }
      final reassigned = (await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey))!;
      _rememberRevision(reassigned);
      return DeviceCanvasClaimReassigned(claim: reassigned);
    });
  }

  Future<DeviceCanvasReleaseAttempt> release({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    int? expectedClaimRevision,
  }) {
    return _claimDao.attachedDatabase.transaction(() async {
      final existing = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
      if (existing == null) return const DeviceCanvasAlreadyReleased();
      if (existing.sessionId != sessionId ||
          (expectedClaimRevision != null && existing.claimRevision != expectedClaimRevision)) {
        return DeviceCanvasReleaseConflict(claim: existing);
      }
      _rememberRevision(existing);
      final deleted = await _claimDao.deleteOwnedClaim(
        bridgeId: bridgeId,
        deviceKey: deviceKey,
        sessionId: sessionId,
        expectedClaimRevision: existing.claimRevision,
      );
      if (deleted) return DeviceCanvasReleased(claim: existing);
      final current = await _getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
      return current == null ? const DeviceCanvasAlreadyReleased() : DeviceCanvasReleaseConflict(claim: current);
    });
  }

  Future<List<DeviceCanvasClaim>> releaseSessionClaims({required String sessionId}) {
    return _claimDao.attachedDatabase.transaction(() async {
      final claims = (await _claimDao.getClaimsForSession(sessionId: sessionId)).map(_mapClaim).toList(growable: false);
      _rememberClaimRevisions(claims);
      await _claimDao.deleteClaimsForSession(sessionId: sessionId);
      return claims;
    });
  }

  Future<List<DeviceCanvasClaim>> releaseSessionsClaims({required List<String> sessionIds}) {
    return _claimDao.attachedDatabase.transaction(() async {
      final claims = (await _claimDao.getClaimsForSessions(sessionIds: sessionIds))
          .map(_mapClaim)
          .toList(growable: false);
      _rememberClaimRevisions(claims);
      await _claimDao.deleteClaimsForSessions(sessionIds: sessionIds);
      return claims;
    });
  }

  Future<List<DeviceCanvasClaim>> deleteClaimsForBridge({required String bridgeId}) {
    return _claimDao.attachedDatabase.transaction(() async {
      final claims = (await _claimDao.getClaimsForBridge(bridgeId: bridgeId)).map(_mapClaim).toList(growable: false);
      _rememberClaimRevisions(claims);
      await _claimDao.deleteClaimsForBridge(bridgeId: bridgeId);
      return claims;
    });
  }

  Future<List<DeviceCanvasClaim>> deleteClaimsForOtherBridges({required String bridgeId}) {
    return _claimDao.attachedDatabase.transaction(() async {
      final claims = (await _claimDao.getClaimsForOtherBridges(bridgeId: bridgeId))
          .map(_mapClaim)
          .toList(growable: false);
      _rememberClaimRevisions(claims);
      await _claimDao.deleteClaimsForOtherBridges(bridgeId: bridgeId);
      return claims;
    });
  }

  Future<List<DeviceCanvasClaim>> deleteUnavailableSessionClaims({required String bridgeId}) {
    return _claimDao.attachedDatabase.transaction(() async {
      final before = (await _claimDao.getClaimsForBridge(bridgeId: bridgeId)).map(_mapClaim).toList(growable: false);
      _rememberClaimRevisions(before);
      await _claimDao.deleteUnavailableSessionClaims(bridgeId: bridgeId);
      final afterKeys = (await _claimDao.getClaimsForBridge(bridgeId: bridgeId))
          .map((row) => (bridgeId: row.bridgeId, deviceKey: row.deviceKey))
          .toSet();
      return [
        for (final claim in before)
          if (!afterKeys.contains((bridgeId: claim.bridgeId, deviceKey: claim.deviceKey))) claim,
      ];
    });
  }

  Future<void> primeClaimRevisionsForBridge({required String bridgeId}) async {
    _rememberRevisions(await _claimDao.getClaimsForBridge(bridgeId: bridgeId));
  }

  Future<DeviceCanvasClaim?> _getClaim({
    required String bridgeId,
    required String deviceKey,
  }) async {
    final row = await _claimDao.getClaim(bridgeId: bridgeId, deviceKey: deviceKey);
    return row == null ? null : _mapClaim(row);
  }

  static DeviceCanvasClaim _mapClaim(DeviceCanvasClaimsTableData row) {
    return DeviceCanvasClaim(
      bridgeId: row.bridgeId,
      deviceKey: row.deviceKey,
      sessionId: row.sessionId,
      claimRevision: row.claimRevision,
      claimedAt: row.claimedAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<DeviceCanvasClaimProjection?> _projectClaim(DeviceCanvasClaim claim) async {
    final session = await _sessionDao.getSession(sessionId: claim.sessionId);
    if (session == null || session.archivedAt != null) return null;
    return DeviceCanvasClaimProjection(
      bridgeId: claim.bridgeId,
      projectId: session.projectId,
      sessionId: claim.sessionId,
      deviceKey: claim.deviceKey,
      claimRevision: claim.claimRevision,
      claimedAt: claim.claimedAt,
      displayTitle: session.title ?? session.catalogTitle,
    );
  }

  void _rememberRevisions(List<DeviceCanvasClaimsTableData> rows) {
    for (final row in rows) {
      _rememberRevision(_mapClaim(row));
    }
  }

  void _rememberClaimRevisions(List<DeviceCanvasClaim> claims) {
    claims.forEach(_rememberRevision);
  }

  void _rememberRevision(DeviceCanvasClaim claim) {
    final current = _lastClaimRevisions[claim.bridgeId] ?? 0;
    if (claim.claimRevision > current) {
      _lastClaimRevisions[claim.bridgeId] = claim.claimRevision;
    }
  }

  Future<int> _nextRevision({required String bridgeId}) {
    return _claimDao.nextClaimRevision(
      bridgeId: bridgeId,
      observedRevision: _lastClaimRevisions[bridgeId] ?? 0,
    );
  }
}
