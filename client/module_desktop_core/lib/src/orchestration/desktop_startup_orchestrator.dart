import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/platform/desktop_application_terminator.dart";
import "../foundation/platform/launch_at_login.dart";
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
  required final AuthSession _authSession,
  required final LaunchAtLogin _launchAtLogin,
}) {
  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;
  new({
    required DesktopInstanceService instanceService,
    required BridgeProcessService processService,
    required DesktopApplicationTerminator applicationTerminator,
    required WindowBoundsService windowBoundsService,
    required AuthSession authSession,
    required LaunchAtLogin launchAtLogin,
  }) : this._create(
         instanceService: instanceService,
         processService: processService,
         applicationTerminator: applicationTerminator,
         windowBoundsService: windowBoundsService,
         authSession: authSession,
         launchAtLogin: launchAtLogin,
       );

  /// Starts observing only after the control dispatcher can serve a helper.
  Future<void> applyFirstRunBridgeDefaults() async {
    _authSubscription ??= _authSession.authStateStream.listen((state) {
      if (state is AuthAuthenticated) unawaited(_applyFirstRunDefaults());
    });
    await _applyFirstRunDefaults();
  }

  Future<void> _applyFirstRunDefaults() async {
    if (_disposed || _authSession.currentState is! AuthAuthenticated) return;
    try {
      if (!await _instanceService.initializeFirstRunBridgeState()) return;
      if (_disposed || _authSession.currentState is! AuthAuthenticated) return;
      // Admit start before the native preference await: a later Stop/logout
      // then owns process intent rather than being followed by a late start.
      unawaited(_startFirstRunBridge());
      await _launchAtLogin.enable();
    } on Object catch (error, stackTrace) {
      logw("Failed to apply desktop first-run startup defaults", error, stackTrace);
    }
  }

  Future<void> _startFirstRunBridge() async {
    try {
      await _processService.start();
    } on Object catch (error, stackTrace) {
      logw("Failed to start the desktop bridge after first sign-in", error, stackTrace);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _authSubscription?.cancel();
  }

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
