import "dart:async";

import "../bridge/device_canvas/integration_state.dart";
import "../repositories/device_canvas_claim_repository.dart";

class DeviceCanvasClaimService({
  required final DeviceCanvasClaimRepository _repository,
  required final DeviceCanvasIntegrationState _integrationState,
}) {
  final StreamController<DeviceCanvasClaimChange> _changes = StreamController<DeviceCanvasClaimChange>.broadcast(
    sync: true,
  );
  bool _disposed = false;

  Stream<DeviceCanvasClaimChange> get changes => _changes.stream;

  Future<List<DeviceCanvasClaimProjection>> snapshot({required String bridgeId}) {
    return _repository.getClaimProjectionsForBridge(bridgeId: bridgeId);
  }

  Future<DeviceCanvasClaimProjectionPage> clientSnapshot({
    required String bridgeId,
    required String sessionId,
    required Set<String> liveDeviceKeys,
    required String? priorityDeviceKey,
    required int limit,
  }) {
    return _repository.getClientClaimProjections(
      bridgeId: bridgeId,
      sessionId: sessionId,
      liveDeviceKeys: liveDeviceKeys,
      priorityDeviceKey: priorityDeviceKey,
      limit: limit,
    );
  }

  Future<List<DeviceCanvasClaimRemoved>> snapshotRemovalsForSessions({required List<String> sessionIds}) async {
    final snapshots = await _repository.getClaimRemovalSnapshotsForSessions(sessionIds: sessionIds);
    return [
      for (final snapshot in snapshots)
        DeviceCanvasClaimRemoved(
          bridgeId: snapshot.bridgeId,
          deviceKey: snapshot.deviceKey,
          claimRevision: snapshot.claimRevision,
        ),
    ];
  }

  Future<void> publishSessionClaimUpdates({required String sessionId}) async {
    if (_changes.isClosed) return;
    final projections = await _repository.getClaimProjectionsForSession(sessionId: sessionId);
    if (_changes.isClosed) return;
    for (final projection in projections) {
      _changes.add(DeviceCanvasClaimUpdated(projection: projection));
    }
  }

  void publishRemovals(List<DeviceCanvasClaimRemoved> removals) {
    if (_changes.isClosed) return;
    removals.forEach(_changes.add);
  }

  Future<DeviceCanvasClaimAttempt> claim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
  }) async {
    final attempt = await _repository.claim(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      canClaimUnownedDevice: () => _integrationState.isConnected && _integrationState.isDeviceAvailable(deviceKey),
    );
    switch (attempt) {
      case DeviceCanvasClaimed(:final claim):
      case DeviceCanvasClaimAlreadyOwned(:final claim):
      case DeviceCanvasClaimReassigned(:final claim):
        await _emitUpdated(claim);
      case DeviceCanvasClaimConflict():
      case DeviceCanvasClaimSessionUnavailable():
      case DeviceCanvasClaimDeviceUnavailable():
        break;
    }
    return attempt;
  }

  Future<DeviceCanvasClaimAttempt> reassign({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required String expectedOwnerSessionId,
    required int expectedClaimRevision,
  }) async {
    final attempt = await _repository.reassign(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedOwnerSessionId: expectedOwnerSessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
    switch (attempt) {
      case DeviceCanvasClaimed(:final claim):
      case DeviceCanvasClaimAlreadyOwned(:final claim):
      case DeviceCanvasClaimReassigned(:final claim):
        await _emitUpdated(claim);
      case DeviceCanvasClaimConflict():
      case DeviceCanvasClaimSessionUnavailable():
      case DeviceCanvasClaimDeviceUnavailable():
        break;
    }
    return attempt;
  }

  Future<DeviceCanvasReleaseAttempt> release({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    int? expectedClaimRevision,
  }) async {
    final attempt = await _repository.release(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
    if (attempt case DeviceCanvasReleased(:final claim)) _emitRemoved(claim);
    return attempt;
  }

  Future<void> releaseSessionClaims({required String sessionId}) async {
    _emitRemovedClaims(await _repository.releaseSessionClaims(sessionId: sessionId));
  }

  Future<void> releaseSessionsClaims({required List<String> sessionIds}) async {
    _emitRemovedClaims(await _repository.releaseSessionsClaims(sessionIds: sessionIds));
  }

  Future<void> cleanupForStartup({required String bridgeId}) async {
    await _repository.primeClaimRevisionsForBridge(bridgeId: bridgeId);
    _emitRemovedClaims(await _repository.deleteClaimsForOtherBridges(bridgeId: bridgeId));
    _emitRemovedClaims(await _repository.deleteUnavailableSessionClaims(bridgeId: bridgeId));
  }

  Future<void> cleanupBridgeIdentity({required String bridgeId}) async {
    _emitRemovedClaims(await _repository.deleteClaimsForBridge(bridgeId: bridgeId));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  Future<void> _emitUpdated(DeviceCanvasClaim claim) async {
    if (_changes.isClosed) return;
    final projection = await _repository.getClaimProjection(
      bridgeId: claim.bridgeId,
      deviceKey: claim.deviceKey,
    );
    if (projection != null) _changes.add(DeviceCanvasClaimUpdated(projection: projection));
  }

  void _emitRemovedClaims(List<DeviceCanvasClaim> claims) {
    claims.forEach(_emitRemoved);
  }

  void _emitRemoved(DeviceCanvasClaim? claim) {
    if (claim == null || _changes.isClosed) return;
    _changes.add(
      DeviceCanvasClaimRemoved(
        bridgeId: claim.bridgeId,
        deviceKey: claim.deviceKey,
        claimRevision: claim.claimRevision,
      ),
    );
  }
}

sealed class const DeviceCanvasClaimChange();

final class const DeviceCanvasClaimUpdated({required final DeviceCanvasClaimProjection projection})
    extends DeviceCanvasClaimChange;

final class const DeviceCanvasClaimRemoved({
  required final String bridgeId,
  required final String deviceKey,
  required final int claimRevision,
}) extends DeviceCanvasClaimChange;
