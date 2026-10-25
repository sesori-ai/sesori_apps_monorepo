import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../services/bridge_process_service.dart";
import "../services/desktop_update_service.dart";

/// How the user asked the desktop to exit.
enum DesktopExitIntent() {
  quit,
  restartToUpdate,
}

/// Layer-4 owner of the work that runs before the desktop exits.
///
/// A restart to update first runs the install kind's update step, which starts
/// the new desktop waiting for this one to exit. A failed update step therefore
/// leaves the running helper untouched; once a package upgrade replaced the
/// bundle, this process could not start its helper again. The helper is stopped
/// last; when that fails, a helper that was on is restored. Failures are
/// rethrown, so the app keeps running. A relaunch already started then times
/// out waiting for the lock and activates this window instead.
@lazySingleton
class DesktopExitOrchestrator({
  required final BridgeProcessService _processService,
  required final DesktopUpdateService _updateService,
}) {
  Future<void> prepareExit({required DesktopExitIntent intent}) async {
    if (intent == DesktopExitIntent.restartToUpdate) {
      await _updateService.prepareRestartToUpdate();
    }
    final bool helperWasOn = _processService.desiredState == BridgeProcessDesiredState.on;
    try {
      await _processService.stop();
    } on Object {
      if (helperWasOn) {
        try {
          await _processService.start();
        } on Object catch (error, stackTrace) {
          logw("Failed to restore the desktop bridge after its stop failed", error, stackTrace);
        }
      }
      rethrow;
    }
  }
}
