import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../foundation/platform/active_bridge_locality.dart";

/// Chooses which computer the app works on. Holds no state of its own: the
/// target lives in [ConnectionService], and the registered list only names
/// computers, never chooses one.
@lazySingleton
class SelectedComputerService({
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _activeBridgeLocality,
}) {
  /// Switches the app to the computer running [bridgeId].
  Future<void> select({required String bridgeId}) => _connectionService.retarget(bridgeId: bridgeId);

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
