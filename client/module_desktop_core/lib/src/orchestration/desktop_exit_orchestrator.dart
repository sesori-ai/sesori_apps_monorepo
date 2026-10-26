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
/// A Linux package restart first starts the new desktop waiting for this one
/// to exit. A failed relaunch therefore leaves the running helper untouched;
/// once a package upgrade replaced the bundle, this process could not start
/// its helper again. A relaunch already started then times out waiting for
/// the lock and activates this window instead.
///
/// The helper is stopped next; when that fails, a helper that was on is
/// restored. Only then does a downloaded Velopack update start its updater,
/// which waits a bounded time for this process to exit and then replaces the
/// install, so the helper must already be gone. A Sparkle restart likewise
/// installs only after the helper stopped; a Sparkle quit installs on normal
/// termination with nothing to start here. A restart restores the helper
/// when that fails too. Failures are rethrown, so the app keeps running. A
/// quit still exits when the updater fails to start; the update stays
/// downloaded for the next exit.
@lazySingleton
class DesktopExitOrchestrator({
  required final BridgeProcessService _processService,
  required final DesktopUpdateService _updateService,
}) {
  Future<void> prepareExit({required DesktopExitIntent intent}) async {
    final bool restart = intent == DesktopExitIntent.restartToUpdate;
    if (restart) {
      await _updateService.prepareRestartToUpdate();
    }
    final bool helperWasOn = _processService.desiredState == BridgeProcessDesiredState.on;
    try {
      await _processService.stop();
      if (restart) {
        await _updateService.applyDownloadedUpdate(restart: true);
      }
    } on Object {
      if (helperWasOn) {
        try {
          await _processService.start();
        } on Object catch (error, stackTrace) {
          logw("Failed to restore the desktop bridge after its exit preparation failed", error, stackTrace);
        }
      }
      rethrow;
    }
    if (!restart) {
      try {
        await _updateService.applyDownloadedUpdate(restart: false);
      } on Object catch (error, stackTrace) {
        logw("Failed to start the desktop updater on quit; quitting without updating", error, stackTrace);
      }
    }
  }
}
