import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../auth/bridge_registration_service.dart";

/// Handles the supervised-mode `unregister_and_exit` control command the desktop
/// GUI sends while logging out: unregister this bridge's `bridgeId` on the auth
/// server, then terminate the process so the GUI can order logout cleanly.
///
/// It owns the logout ordering boundary: the unregister runs BEFORE the process
/// terminates, and the process still terminates even if the unregister fails, so
/// a stuck bridge can never hang the GUI's logout. A failed unregister only
/// leaks the server-side registration until the GUI's offline-unregister
/// fallback cleans it up (it keeps a readable `bridgeId` copy for exactly this,
/// ADR A13).
///
/// The dispatcher (the single inbound subscriber) invokes this on the command;
/// this class owns no subscription or correlation state of its own. The
/// process-termination effect is injected ([_terminate]) so the composition root
/// keeps ownership of the graceful-shutdown-then-exit path.
class ControlUnregisterService {
  /// The unregister DELETE is a single machine-to-server call with a
  /// GUI-supplied (already cached) token, so it should be quick. Bounding it
  /// keeps a stalled network (silent packet loss / blackhole) from hanging the
  /// GUI's logout forever — on timeout the process still terminates and the
  /// GUI's offline-unregister fallback (ADR A13) cleans up the leaked
  /// registration.
  static const Duration _defaultUnregisterTimeout = Duration(seconds: 10);

  final BridgeRegistrationService _registrationService;
  final Future<void> Function() _terminate;
  final Duration _unregisterTimeout;

  ControlUnregisterService({
    required BridgeRegistrationService registrationService,
    required Future<void> Function() terminate,
    Duration unregisterTimeout = _defaultUnregisterTimeout,
  })  : _registrationService = registrationService,
        _terminate = terminate,
        _unregisterTimeout = unregisterTimeout;

  /// Unregisters the bridge, then terminates the process. Terminates even when
  /// the unregister throws or times out, so the GUI's logout is never blocked by
  /// a bridge that can't reach the auth server.
  Future<void> handleUnregisterAndExit() async {
    try {
      await _registrationService.unregister().timeout(_unregisterTimeout);
    } on Object catch (error, stackTrace) {
      Log.w("[control] unregister on logout failed; terminating anyway", error, stackTrace);
    }
    await _terminate();
  }
}
