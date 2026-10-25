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
/// Stops the helper, then runs the install kind's update step for a restart to
/// update. When either fails, a helper that was on is restored and the failure
/// is rethrown, so the app keeps running as before.
@lazySingleton
class DesktopExitOrchestrator({
  required final BridgeProcessService _processService,
  required final DesktopUpdateService _updateService,
}) {
  Future<void> prepareExit({required DesktopExitIntent intent}) async {
    final bool helperWasOn = _processService.desiredState == BridgeProcessDesiredState.on;
    try {
      await _processService.stop();
      switch (intent) {
        case DesktopExitIntent.quit:
          break;
        case DesktopExitIntent.restartToUpdate:
          await _updateService.prepareRestartToUpdate();
      }
    } on Object {
      if (helperWasOn) {
        try {
          await _processService.start();
        } on Object catch (error, stackTrace) {
          logw("Failed to restart the desktop bridge after preparing the ${intent.name} failed", error, stackTrace);
        }
      }
      rethrow;
    }
  }
}
