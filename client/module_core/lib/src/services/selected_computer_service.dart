import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/platform/active_bridge_locality.dart";

/// Chooses which computer the app works on. Holds no state of its own: the
/// target lives in [ConnectionService], and the registered list only names
/// computers, never chooses one.
@lazySingleton
class SelectedComputerService({
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _activeBridgeLocality,
}) {
  /// The computer the app works on: the live connection's target, else the
  /// stored one, else `null` when none is known yet.
  Future<String?> targetBridgeId() async =>
      _connectionService.currentStatus.targetBridgeId ?? await _connectionService.readTargetBridgeId();

  /// Resolves the target before the first connection: the stored target wins,
  /// then the bridge this surface supervises on its own computer; otherwise no
  /// target is pinned and the relay picks the most recently connected bridge.
  Future<void> ensureInitialTarget() async {
    if (await _connectionService.readTargetBridgeId() != null) return;
    final localBridgeId = _activeBridgeLocality.localBridgeId;
    if (localBridgeId == null) return;
    await _connectionService.retarget(bridgeId: localBridgeId);
  }
}
