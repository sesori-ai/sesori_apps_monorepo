import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../services/bridge_process_service.dart";
import "../services/desktop_instance_service.dart";
import "../trackers/desktop_logout_tracker.dart";

/// Result of the interim device-local desktop logout sequence.
enum DesktopLogoutOutcome() {
  completed,
  bridgeStopFailed,
  localSessionClearFailed,
}

/// Layer-4 owner of cross-service desktop logout ordering.
///
/// The supervised helper must stop while the GUI still has an authenticated
/// session. Step 11 extends this owner with unregister coordination; callers
/// remain unaware of the sequence.
@lazySingleton
class DesktopLogoutOrchestrator({
  required final BridgeProcessService processService,
  required final DesktopInstanceService instanceService,
  required final DesktopLogoutTracker logoutTracker,
  required final AuthSession authSession,
}) {
  final BridgeProcessService _processService = processService;
  final DesktopInstanceService _instanceService = instanceService;
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
    try {
      await _processService.stop();
    } on Object catch (error, stackTrace) {
      logw("Desktop logout stopped because the supervised bridge could not stop", error, stackTrace);
      return DesktopLogoutOutcome.bridgeStopFailed;
    }

    try {
      await _instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist bridge Off during desktop logout", error, stackTrace);
    }

    try {
      await _authSession.logoutCurrentDevice();
      return DesktopLogoutOutcome.completed;
    } on Object catch (error, stackTrace) {
      logw("Device-local sign-out failed", error, stackTrace);
      return DesktopLogoutOutcome.localSessionClearFailed;
    }
  }
}
