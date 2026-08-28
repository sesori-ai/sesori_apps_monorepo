import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../services/bridge_process_service.dart";
import "../services/desktop_instance_service.dart";

/// Layer-4 owner of launch ownership and last-On bridge restoration.
@lazySingleton
class DesktopStartupOrchestrator._create({
  required final DesktopInstanceService _instanceService,
  required final BridgeProcessService _processService,
}) {
  new({required DesktopInstanceService instanceService, required BridgeProcessService processService})
    : this._create(instanceService: instanceService, processService: processService);

  Future<DesktopInstanceLaunchDisposition> claimLaunch() => _instanceService.claimLaunch();

  Future<void> restoreBridgeDesiredState() async {
    final BridgeProcessDesiredState desiredState;
    try {
      desiredState = await _instanceService.readBridgeDesiredState();
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop bridge's last desired state", error, stackTrace);
      return;
    }
    if (desiredState == BridgeProcessDesiredState.off) {
      return;
    }
    try {
      await _processService.start();
    } on Object catch (error, stackTrace) {
      logw("Failed to restore the desktop bridge's desired On state", error, stackTrace);
    }
  }
}
