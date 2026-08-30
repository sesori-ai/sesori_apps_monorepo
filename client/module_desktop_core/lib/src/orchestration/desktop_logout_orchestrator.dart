import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show AuthUser;

import "../api/bridge_registration_record.dart";
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
/// account-bound bridge registration before clearing local credentials; callers
/// remain unaware of the sequence.
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
      // Claim the stop before sending the command so an immediate helper exit
      // is marked expected. An ordinary stop already in flight owns its
      // shutdown request; sending unregister after it would dispose the
      // helper's token service too early.
      final BridgeProcessStopRequest stopRequest = _processService.requestStopForLogout();
      if (stopRequest.shouldSendUnregister) {
        bool unregisterDelivered = false;
        try {
          // The helper's own unregister path is deliberately unacknowledged
          // and best-effort. A missing socket is expected when the helper is
          // already dead; the GUI deletion below is the durable fallback.
          _controlCommandService.unregisterAndExit();
          unregisterDelivered = true;
        } on ControlHelperNotConnectedException catch (error, stackTrace) {
          logd("Supervised bridge is not connected for unregister; using GUI fallback", error, stackTrace);
        } on Object catch (error, stackTrace) {
          logw("Failed to send the supervised bridge unregister command", error, stackTrace);
        }
        if (!unregisterDelivered) {
          // Wake the same pending stop and let the process service send one
          // ordinary shutdown signal instead of waiting for the full grace
          // period as though a command had been delivered.
          await _processService.fallbackStopAfterUnregisterFailure();
        }
      } else {
        logd("Joining the existing ordinary bridge stop; unregister command not sent");
      }
      await stopRequest.completion;
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
    final BridgeRegistrationRecord? registration = _statusTracker.registeredBridge;
    if (registration == null) {
      return;
    }

    final String? currentAccountId = await _resolveCurrentAccountId();
    if (currentAccountId != registration.accountId) {
      // The record may belong to an earlier account that logged out while
      // offline, or the locally valid token may not yet have a recoverable
      // user record. Never submit its id with an unverified bearer token, and
      // retain it so the owning account can retry later.
      logd("Skipping desktop bridge deletion because its owner is not verified as signed in");
      return;
    }

    final ApiResponse<void> response;
    try {
      response = await _bridgeRepository.deleteBridge(bridgeId: registration.bridgeId).timeout(_bridgeDeletionTimeout);
    } on Object catch (error, stackTrace) {
      logw("Failed to unregister the desktop bridge; continuing local logout", error, stackTrace);
      return;
    }

    switch (response) {
      case SuccessResponse():
        try {
          await _statusTracker.clearBridgeId(registration: registration);
        } on Object catch (error, stackTrace) {
          // The server-side registration is already gone. Retain the local id
          // for a future retry if its cleanup cannot be persisted now.
          logw("Failed to clear the persisted desktop bridge id", error, stackTrace);
        }
      case ErrorResponse(:final error):
        logw("Failed to unregister the desktop bridge; continuing local logout", error);
    }
  }

  Future<String?> _resolveCurrentAccountId() async {
    final AuthState authState = _authSession.currentState;
    if (authState case AuthAuthenticated(:final user)) {
      return user.id;
    }
    if (authState is! AuthInitial) {
      return null;
    }

    // AuthGate supports a token-only signed-in posture when the cached user
    // was unavailable. Ask the auth session to verify that token before using
    // the persisted registration owner for an authenticated DELETE.
    final AuthUser? recoveredUser;
    try {
      recoveredUser = await _authSession.getCurrentUser();
    } on Object catch (error, stackTrace) {
      logw("Failed to verify the current account before desktop bridge deletion", error, stackTrace);
      return null;
    }
    if (recoveredUser == null) {
      return null;
    }

    // A concurrent auth transition may have changed the account while the
    // verification request was in flight. Accept the token-only posture only
    // if it is still the initial state; any authenticated replacement must
    // match the verified user exactly.
    final AuthState latestState = _authSession.currentState;
    if (latestState case AuthAuthenticated(:final user)) {
      return user.id == recoveredUser.id ? recoveredUser.id : null;
    }
    return latestState is AuthInitial ? recoveredUser.id : null;
  }
}
