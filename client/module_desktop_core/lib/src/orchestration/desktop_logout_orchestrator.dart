import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../services/bridge_process_service.dart";

/// Result of the interim device-local desktop logout sequence.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors.
// ignore: use_primary_constructors
enum DesktopLogoutOutcome { completed, bridgeStopFailed, localSessionClearFailed }

/// Layer-4 owner of cross-service desktop logout ordering.
///
/// The supervised helper must stop while the GUI still has an authenticated
/// session. Step 11 extends this owner with unregister coordination; callers
/// remain unaware of the sequence.
@lazySingleton
class DesktopLogoutOrchestrator({
  required final BridgeProcessService processService,
  required final AuthSession authSession,
}) {
  final BridgeProcessService _processService = processService;
  final AuthSession _authSession = authSession;

  Future<DesktopLogoutOutcome> logoutCurrentDevice() async {
    try {
      await _processService.stop();
    } on Object catch (error, stackTrace) {
      logw("Desktop logout stopped because the supervised bridge could not stop", error, stackTrace);
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
}
