import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/platform/active_bridge_locality.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "product_analytics_service.dart";
import "registered_bridges_service.dart";

/// Chooses which computer the app works on. The target lives in
/// [ConnectionService], and the registered list only names computers, never
/// chooses one. The one thing held here is whether the user has picked a
/// computer since start-up, which keeps [followLocalComputer] from undoing it.
@lazySingleton
class SelectedComputerService({
  required final ConnectionService _connectionService,
  required final ActiveBridgeLocality _activeBridgeLocality,
  required final RegisteredBridgesService _registeredBridgesService,
  required final ProductAnalyticsService _productAnalyticsService,
}) {
  bool _pickedSinceStartUp = false;

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

  /// Points the app at this computer's own bridge, whose id [bridgeId] just
  /// appeared or changed (a fresh install, a new login, or a re-registration),
  /// unless the user has picked a computer since start-up. Without this the
  /// connection keeps the relay's default computer or an id that is gone.
  Future<void> followLocalComputer({required String bridgeId}) async {
    if (_pickedSinceStartUp) return;
    await _connectionService.retarget(bridgeId: bridgeId);
  }

  /// Switches the app to the computer [bridgeId], reporting where the switch
  /// started. Navigation is the caller's: every switch goes through
  /// `ComputerSwitchDispatcher`, which also returns the app to Projects.
  Future<void> select({required String bridgeId, required ComputerSwitchSource source}) async {
    _pickedSinceStartUp = true;
    final target = _registeredBridgesService.bridges.value.where((bridge) => bridge.id == bridgeId).firstOrNull;
    _reportSwitch(
      event: ProductAnalyticsEvent.computerSwitched(
        source: source,
        targetOnline: target?.status == BridgeRegistrationStatus.active,
      ),
    );
    await _connectionService.retarget(bridgeId: bridgeId);
  }

  void _reportSwitch({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService.logEvent(event: event, occurredAtUtc: DateTime.now().toUtc()).then<void>((result) {
        if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
          logw("Failed to deliver computer switch analytics event");
        }
      }),
    );
  }
}
