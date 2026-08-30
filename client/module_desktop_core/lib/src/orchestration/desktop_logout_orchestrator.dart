import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/control_channel_server.dart";
import "../services/bridge_process_service.dart";
import "../services/control_command_service.dart";
import "../services/desktop_instance_service.dart";
import "../trackers/bridge_status_tracker.dart";
import "../trackers/desktop_logout_tracker.dart";

/// Result of the interim device-local desktop logout sequence.
enum DesktopLogoutOutcome() {
  completed,
  desiredStatePersistenceFailed,
  bridgeStopFailed,
  localSessionClearFailed,
}

/// Layer-4 owner of cross-service desktop logout ordering.
///
/// The supervised helper must unregister/stop while the GUI still has an
/// authenticated session. The GUI then retries deletion using its persisted
/// bridge id before clearing local credentials; callers remain unaware of the
/// sequence.
@lazySingleton
class DesktopLogoutOrchestrator({
  required final BridgeProcessService processService,
  required final ControlCommandService controlCommandService,
  required final DesktopInstanceService instanceService,
  required final BridgeRepository bridgeRepository,
  required final BridgeStatusTracker statusTracker,
  required final DesktopLogoutTracker logoutTracker,
  required final AuthSession authSession,
}) {
  static const Duration _bridgeDeletionTimeout = Duration(seconds: 10);

  final BridgeProcessService _processService = processService;
  final ControlCommandService _controlCommandService = controlCommandService;
  final DesktopInstanceService _instanceService = instanceService;
  final BridgeRepository _bridgeRepository = bridgeRepository;
  final BridgeStatusTracker _statusTracker = statusTracker;
  final DesktopLogoutTracker _logoutTracker = logoutTracker;
  final AuthSession _authSession = authSession;
  Future<DesktopLogoutOutcome>? _activeLogout;

  Future<DesktopLogoutOutcome> logoutCurrentDevice() {
    final Future<DesktopLogoutOutcome>? existing = _activeLogout;
    if (existing != null) {
      return existing;
    }
    _logoutTracker.markInProgress();
    final Future<DesktopLogoutOutcome> rawOperation = _performLogout();
    late final Future<DesktopLogoutOutcome> operation;
    operation = rawOperation.whenComplete(() {
      _logoutTracker.markIdle();
      if (identical(_activeLogout, operation)) {
        _activeLogout = null;
      }
    });
    _activeLogout = operation;
    return operation;
  }

  Future<DesktopLogoutOutcome> _performLogout() async {
    _instanceService.cancelPendingBridgeRestore();
    try {
      await _instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    } on Object catch (error, stackTrace) {
      logw("Desktop logout stopped because bridge Off could not be persisted", error, stackTrace);
      return DesktopLogoutOutcome.desiredStatePersistenceFailed;
    }

    bool bridgeStopped = false;
    try {
      // The helper's own unregister path is deliberately unacknowledged and
      // best-effort. A missing socket is expected when the helper is already
      // dead; the GUI deletion below is the durable fallback in either case.
      try {
        _controlCommandService.unregisterAndExit();
      } on ControlHelperNotConnectedException catch (error, stackTrace) {
        logd("Supervised bridge is not connected for unregister; using GUI fallback", error, stackTrace);
      } on Object catch (error, stackTrace) {
        logw("Failed to send the supervised bridge unregister command", error, stackTrace);
      }

      await _processService.stop();
      bridgeStopped = true;
    } on Object catch (error, stackTrace) {
      logw("Desktop logout stopped because the supervised bridge could not stop", error, stackTrace);
    }

    // This attempt is intentionally independent of both the control command
    // and process teardown. The persisted id is what covers a dead helper and
    // a helper whose own network unregister timed out.
    await _deleteRegisteredBridge();

    if (!bridgeStopped) {
      // Preserve the pre-existing safety boundary: when a helper may still be
      // alive, do not clear the GUI's credentials out from under it.
      return DesktopLogoutOutcome.bridgeStopFailed;
    }

    try {
      await _authSession.logoutCurrentDevice();
      return DesktopLogoutOutcome.completed;
    } on Object catch (error, stackTrace) {
      logw("Device-local sign-out failed", error, stackTrace);
      return DesktopLogoutOutcome.localSessionClearFailed;
    }
  }

  Future<void> _deleteRegisteredBridge() async {
    final String? bridgeId = _statusTracker.status.bridgeId;
    if (bridgeId == null) {
      return;
    }

    final ApiResponse<void> response;
    try {
      response = await _bridgeRepository.deleteBridge(bridgeId: bridgeId).timeout(_bridgeDeletionTimeout);
    } on Object catch (error, stackTrace) {
      logw("Failed to unregister the desktop bridge; continuing local logout", error, stackTrace);
      return;
    }

    switch (response) {
      case SuccessResponse():
        try {
          await _statusTracker.clearBridgeId(bridgeId: bridgeId);
        } on Object catch (error, stackTrace) {
          // The server-side registration is already gone. Retain the local id
          // for a future retry if its cleanup cannot be persisted now.
          logw("Failed to clear the persisted desktop bridge id", error, stackTrace);
        }
      case ErrorResponse(:final error):
        logw("Failed to unregister the desktop bridge; continuing local logout", error);
    }
  }
}
