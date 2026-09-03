import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/platform/desktop_application_terminator.dart";
import "../services/bridge_process_service.dart";
import "../services/desktop_instance_service.dart";
import "../services/window_bounds_service.dart";

/// Layer-4 owner of launch ownership and last-On bridge restoration.
@lazySingleton
class DesktopStartupOrchestrator._create({
  required final DesktopInstanceService _instanceService,
  required final BridgeProcessService _processService,
  required final DesktopApplicationTerminator _applicationTerminator,
  required final WindowBoundsService _windowBoundsService,
}) {
  new({
    required DesktopInstanceService instanceService,
    required BridgeProcessService processService,
    required DesktopApplicationTerminator applicationTerminator,
    required WindowBoundsService windowBoundsService,
  }) : this._create(
         instanceService: instanceService,
         processService: processService,
         applicationTerminator: applicationTerminator,
         windowBoundsService: windowBoundsService,
       );

  /// Claims the primary process role and terminates every secondary launch.
  ///
  /// The shell only needs to know whether it should continue constructing UI;
  /// instance-arbitration outcomes and exit policy stay owned here.
  Future<bool> preparePrimaryLaunch() async {
    final DesktopInstanceLaunchDisposition disposition = await _instanceService.claimLaunch();
    if (disposition == DesktopInstanceLaunchDisposition.primary) {
      return true;
    }
    _applicationTerminator.terminate(exitCode: 0);
    return false;
  }

  /// Restores and begins tracking the native window before UI construction.
  Future<void> initializeWindow({required bool hidden}) => _windowBoundsService.initializeWindow(hidden: hidden);

  Future<void> restoreBridgeDesiredState() async {
    final BridgeProcessDesiredState? desiredState;
    try {
      desiredState = await _instanceService.readBridgeDesiredStateForRestore();
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop bridge's last desired state", error, stackTrace);
      return;
    }
    if (desiredState == null || desiredState == BridgeProcessDesiredState.off) {
      return;
    }
    try {
      await _processService.start();
    } on Object catch (error, stackTrace) {
      logw("Failed to restore the desktop bridge's desired On state", error, stackTrace);
    }
  }
}
