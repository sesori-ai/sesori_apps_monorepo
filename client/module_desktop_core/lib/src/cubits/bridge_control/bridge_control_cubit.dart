import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/bridge_process_desired_state.dart";
import "../../foundation/platform/desktop_application_terminator.dart";
import "../../foundation/platform/launch_at_login.dart";
import "../../foundation/platform/system_tray.dart";
import "../../foundation/platform/window_host.dart";
import "../../orchestration/desktop_bridge_takeover_orchestrator.dart";
import "../../repositories/bridge_process_log_repository.dart";
import "../../services/bridge_process_service.dart";
import "../../services/bridge_process_state.dart";
import "../../services/desktop_instance_service.dart";
import "../../services/window_bounds_service.dart";
import "../../trackers/bridge_control_status.dart";
import "../../trackers/bridge_status_tracker.dart";
import "../../trackers/desktop_logout_tracker.dart";
import "bridge_control_state.dart";

/// Layer-4 owner of desktop bridge tray/window controls and lifecycle commands.
///
/// Platform adapters only render [SystemTrayMenu], emit typed events, and
/// perform native window operations. This cubit derives presentation from
/// Layer-2/3 snapshots, sequences bridge and launch-at-login actions, applies
/// hidden-startup tray fallback, and exits only after expected bridge teardown
/// succeeds.
class BridgeControlCubit._create({
  required final BridgeProcessService _processService,
  required final BridgeStatusTracker _statusTracker,
  required final SystemTray _systemTray,
  required final WindowHost _windowHost,
  required final WindowBoundsService _windowBoundsService,
  required final DesktopApplicationTerminator _applicationTerminator,
  required final BridgeProcessLogRepository _logRepository,
  required final DesktopInstanceService _instanceService,
  required final DesktopBridgeTakeoverOrchestrator _takeoverOrchestrator,
  required final DesktopLogoutTracker _logoutTracker,
  required final UrlLauncher _urlLauncher,
  required final LaunchAtLogin _launchAtLogin,
  required final bool _hiddenLaunch,
}) extends Cubit<BridgeControlState> {
  new({
    required BridgeProcessService processService,
    required BridgeStatusTracker statusTracker,
    required SystemTray systemTray,
    required WindowHost windowHost,
    required WindowBoundsService windowBoundsService,
    required DesktopApplicationTerminator applicationTerminator,
    required BridgeProcessLogRepository logRepository,
    required DesktopInstanceService instanceService,
    required DesktopBridgeTakeoverOrchestrator takeoverOrchestrator,
    required DesktopLogoutTracker logoutTracker,
    required UrlLauncher urlLauncher,
    required LaunchAtLogin launchAtLogin,
    required bool hiddenLaunch,
  }) : this._create(
         processService: processService,
         statusTracker: statusTracker,
         systemTray: systemTray,
         windowHost: windowHost,
         windowBoundsService: windowBoundsService,
         applicationTerminator: applicationTerminator,
         logRepository: logRepository,
         instanceService: instanceService,
         takeoverOrchestrator: takeoverOrchestrator,
         logoutTracker: logoutTracker,
         urlLauncher: urlLauncher,
         launchAtLogin: launchAtLogin,
         hiddenLaunch: hiddenLaunch,
       );

  this
    : super(
        BridgeControlState(
          trayAvailability: SystemTrayAvailability.initializing,
          activity: _logoutTracker.status.locksBridgeControls
              ? BridgeControlActivity.signingOut
              : BridgeControlActivity.idle,
          statusLabel: _statusLabel(processState: _processService.state, status: _statusTracker.status),
          processState: _processService.state,
          desiredState: _processService.desiredState,
          toggleTarget: _toggleTarget(
            processState: _processService.state,
            desiredState: _processService.desiredState,
          ),
          launchAtLoginEnabled: false,
          controlStatus: _statusTracker.status,
        ),
      );

  StreamSubscription<BridgeProcessState>? _processSubscription;
  StreamSubscription<BridgeControlStatus>? _statusSubscription;
  StreamSubscription<SystemTrayCommand>? _commandSubscription;
  StreamSubscription<WindowHostEvent>? _windowSubscription;
  StreamSubscription<DesktopLogoutStatus>? _logoutSubscription;
  StreamSubscription<void>? _focusRequestSubscription;
  SystemTrayAvailability _trayAvailability = SystemTrayAvailability.initializing;
  BridgeControlActivity _activity = BridgeControlActivity.idle;
  DesktopLogoutStatus _logoutStatus = DesktopLogoutStatus.idle;
  bool _quitAfterActivity = false;
  bool _launchAtLoginEnabled = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      throw StateError("BridgeControlCubit is already initialized");
    }
    _initialized = true;
    _processSubscription = _processService.states.listen((_) => _rebuildMenu());
    _statusSubscription = _statusTracker.statusStream.listen((_) => _rebuildMenu());
    _commandSubscription = _systemTray.commands.listen((command) => _onCommand(command: command));
    _windowSubscription = _windowHost.events.listen((event) => _onWindowEvent(event: event));
    _logoutSubscription = _logoutTracker.statuses.listen(_onLogoutStatus);
    _focusRequestSubscription = _instanceService.focusRequests.listen((_) => unawaited(showWindow()));

    await _loadLaunchAtLoginState();

    final SystemTrayAvailability availability;
    try {
      availability = await _systemTray.initialize(menu: state.menu);
    } on Object catch (error, stackTrace) {
      logw("System tray initialization failed; keeping the desktop window visible", error, stackTrace);
      if (!isClosed) {
        _trayAvailability = SystemTrayAvailability.unavailable;
        _rebuildMenu(syncTray: false);
        await _showWindowForUnavailableHiddenLaunch();
      }
      return;
    }
    if (isClosed) {
      return;
    }

    _trayAvailability = availability;
    if (!availability.isAvailable) {
      logw("System tray host is unavailable; keeping the desktop window visible");
    }
    _rebuildMenu(syncTray: false);
    if (!availability.isAvailable) {
      await _showWindowForUnavailableHiddenLaunch();
    }
    if (availability.isAvailable) {
      await _setMenu(menu: state.menu);
    }
  }

  void _onCommand({required SystemTrayCommand command}) {
    switch (command) {
      case SystemTrayCommand.openWindow:
        unawaited(showWindow());
      case SystemTrayCommand.toggleBridge:
        if (!_controlsLocked) {
          unawaited(toggleBridge());
        }
      case SystemTrayCommand.takeOver:
        if (!_controlsLocked) {
          unawaited(takeOver());
        }
      case SystemTrayCommand.toggleLaunchAtLogin:
        if (!_controlsLocked) {
          unawaited(toggleLaunchAtLogin());
        }
      case SystemTrayCommand.quit:
        if (!_controlsLocked) {
          unawaited(quit());
        }
    }
  }

  void _onWindowEvent({required WindowHostEvent event}) {
    switch (event) {
      case WindowHostEvent.moved || WindowHostEvent.resized:
        return;
      case WindowHostEvent.closeRequested:
        if (_trayAvailability.isAvailable) {
          unawaited(hideWindow());
          return;
        }
        if (_logoutStatus.locksBridgeControls) {
          _quitAfterActivity = true;
          return;
        }
        switch (_activity) {
          case BridgeControlActivity.idle:
            unawaited(quit());
          case BridgeControlActivity.toggling:
            _quitAfterActivity = true;
          case BridgeControlActivity.signingOut:
            _quitAfterActivity = true;
          case BridgeControlActivity.configuringLaunchAtLogin:
            _quitAfterActivity = true;
          case BridgeControlActivity.quitting:
            return;
        }
    }
  }

  void _onLogoutStatus(DesktopLogoutStatus status) {
    _logoutStatus = status;
    _rebuildMenu();
    if (!status.locksBridgeControls && _activity == BridgeControlActivity.idle && _quitAfterActivity) {
      _quitAfterActivity = false;
      _onWindowEvent(event: WindowHostEvent.closeRequested);
    }
  }

  bool get _controlsLocked => _activity.locksCommands || _logoutTracker.status.locksBridgeControls;

  Future<void> _loadLaunchAtLoginState() async {
    try {
      _launchAtLoginEnabled = await _launchAtLogin.isEnabled();
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop launch-at-login state", error, stackTrace);
    }
    if (!isClosed) {
      _rebuildMenu(syncTray: false);
    }
  }

  Future<void> _showWindowForUnavailableHiddenLaunch() async {
    if (_hiddenLaunch) {
      await showWindow();
    }
  }

  BridgeControlActivity get _presentationActivity =>
      _logoutStatus.locksBridgeControls ? BridgeControlActivity.signingOut : _activity;

  Future<void> toggleBridge() {
    final BridgeProcessDesiredState target = _toggleTarget(
      processState: _processService.state,
      desiredState: _processService.desiredState,
    );
    return _setBridgeDesiredState(target: target);
  }

  /// Requests the supervised bridge to be On without applying toggle
  /// semantics. Used by desktop recovery surfaces where the only valid intent
  /// is to start or retry the local bridge.
  Future<void> startBridge() => _setBridgeDesiredState(target: BridgeProcessDesiredState.on);

  Future<void> _setBridgeDesiredState({required BridgeProcessDesiredState target}) async {
    if (_controlsLocked) {
      return;
    }
    _activity = BridgeControlActivity.toggling;
    _rebuildMenu();
    try {
      await _instanceService.writeBridgeDesiredState(state: target);
      await switch (target) {
        BridgeProcessDesiredState.on => _processService.start(),
        BridgeProcessDesiredState.off => _processService.stop(),
      };
    } on Object catch (error, stackTrace) {
      logw("Desktop bridge lifecycle command failed", error, stackTrace);
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
        if (_quitAfterActivity) {
          _quitAfterActivity = false;
          _onWindowEvent(event: WindowHostEvent.closeRequested);
        }
      }
    }
  }

  Future<void> showWindow() async {
    try {
      await _windowHost.show();
    } on Object catch (error, stackTrace) {
      logw("Failed to show the desktop window", error, stackTrace);
    }
  }

  Future<void> hideWindow() async {
    try {
      await _windowHost.hide();
    } on Object catch (error, stackTrace) {
      logw("Failed to hide the desktop window", error, stackTrace);
    }
  }

  Future<void> takeOver() async {
    if (_controlsLocked || !_canTakeOver) {
      return;
    }
    _activity = BridgeControlActivity.toggling;
    _rebuildMenu();
    try {
      await _takeoverOrchestrator.takeOver();
    } on Object catch (error, stackTrace) {
      logw("Desktop bridge takeover command failed", error, stackTrace);
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
        if (_quitAfterActivity) {
          _quitAfterActivity = false;
          _onWindowEvent(event: WindowHostEvent.closeRequested);
        }
      }
    }
  }

  Future<void> toggleLaunchAtLogin() async {
    if (_controlsLocked) {
      return;
    }
    _activity = BridgeControlActivity.configuringLaunchAtLogin;
    _rebuildMenu();
    final bool target = !_launchAtLoginEnabled;
    try {
      if (target) {
        await _launchAtLogin.enable();
      } else {
        await _launchAtLogin.disable();
      }
      _launchAtLoginEnabled = target;
    } on Object catch (error, stackTrace) {
      logw("Launch-at-login command failed", error, stackTrace);
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
        if (_quitAfterActivity) {
          _quitAfterActivity = false;
          _onWindowEvent(event: WindowHostEvent.closeRequested);
        }
      }
    }
  }

  Future<void> openLogs() async {
    try {
      final Uri uri = await _logRepository.logFileUri;
      final bool opened = await _urlLauncher.launch(uri);
      if (!opened) {
        logw("The desktop could not open the supervised bridge log file");
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to open the supervised bridge log file", error, stackTrace);
    }
  }

  Future<void> quit() async {
    if (_controlsLocked) {
      return;
    }
    _activity = BridgeControlActivity.quitting;
    _rebuildMenu();
    _instanceService.cancelPendingBridgeRestore();
    // Stopping the helper must not rewrite the user's persisted On/Off
    // intent. An explicit Bridge Off action has already persisted Off; Quit
    // only stops the current process so a later launch can restore last-On.
    try {
      await _processService.stop();
    } on Object catch (error, stackTrace) {
      logw("Desktop quit stopped because the supervised bridge could not stop", error, stackTrace);
      _markQuitFailed();
      return;
    }

    try {
      await _systemTray.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose the system tray during desktop quit", error, stackTrace);
    }
    try {
      await _windowBoundsService.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to flush desktop window bounds during quit", error, stackTrace);
    }
    try {
      await _windowHost.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose the desktop window host during quit", error, stackTrace);
    }
    _applicationTerminator.terminate(exitCode: 0);
  }

  void _markQuitFailed() {
    if (!isClosed) {
      _activity = BridgeControlActivity.idle;
      _rebuildMenu();
    }
  }

  void _rebuildMenu({bool syncTray = true}) {
    if (isClosed) {
      return;
    }
    final BridgeProcessState processState = _processService.state;
    final BridgeProcessDesiredState desiredState = _processService.desiredState;
    final BridgeControlStatus controlStatus = _statusTracker.status;
    final BridgeControlActivity activity = _presentationActivity;
    final BridgeControlState nextState = BridgeControlState(
      trayAvailability: _trayAvailability,
      activity: activity,
      statusLabel: _statusLabel(processState: processState, status: controlStatus),
      processState: processState,
      desiredState: desiredState,
      toggleTarget: _toggleTarget(processState: processState, desiredState: desiredState),
      launchAtLoginEnabled: _launchAtLoginEnabled,
      controlStatus: controlStatus,
    );
    emit(nextState);
    if (syncTray && _trayAvailability.isAvailable) {
      unawaited(_setMenu(menu: nextState.menu));
    }
  }

  Future<void> _setMenu({required SystemTrayMenu menu}) async {
    try {
      await _systemTray.setMenu(menu: menu);
    } on Object catch (error, stackTrace) {
      logw("Failed to update the system tray menu", error, stackTrace);
    }
  }

  bool get _canTakeOver => state.canTakeOver;

  static BridgeProcessDesiredState _toggleTarget({
    required BridgeProcessState processState,
    required BridgeProcessDesiredState desiredState,
  }) {
    if (processState is BridgeProcessStopped && desiredState == BridgeProcessDesiredState.on) {
      return BridgeProcessDesiredState.on;
    }
    if (processState is BridgeProcessRunning && desiredState == BridgeProcessDesiredState.off) {
      return BridgeProcessDesiredState.off;
    }
    return desiredState == BridgeProcessDesiredState.on ? BridgeProcessDesiredState.off : BridgeProcessDesiredState.on;
  }

  static String _statusLabel({required BridgeProcessState processState, required BridgeControlStatus status}) {
    return switch (processState) {
      BridgeProcessStopped() => "Bridge: Off",
      BridgeProcessLoginRequired() => "Bridge: Login required",
      BridgeProcessStarting() => "Bridge: Starting",
      BridgeProcessRunning() => _runningStatusLabel(status: status),
      BridgeProcessStopping() => "Bridge: Stopping",
      BridgeProcessContention() => "Bridge: Another bridge is running",
      BridgeProcessCrashRetryScheduled(:final delay) => "Bridge: Restarting in ${delay.inSeconds}s",
      BridgeProcessCrashGiveUp() => "Bridge: Stopped after repeated crashes",
    };
  }

  static String _runningStatusLabel({required BridgeControlStatus status}) {
    if (!status.helperOnline) {
      return "Bridge: Connecting";
    }
    return switch (status.relay) {
      ControlRelayConnectionState.connected =>
        status.plugin == ControlPluginHealthState.degraded ? "Bridge: Degraded" : "Bridge: Connected",
      ControlRelayConnectionState.connecting => "Bridge: Connecting",
      ControlRelayConnectionState.disconnected => "Bridge: Reconnecting",
      ControlRelayConnectionState.takenOver => "Bridge: Relay taken over",
      ControlRelayConnectionState.unknown => "Bridge: Status unknown",
    };
  }

  @override
  Future<void> close() async {
    await _focusRequestSubscription?.cancel();
    await _logoutSubscription?.cancel();
    await _windowSubscription?.cancel();
    await _commandSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _processSubscription?.cancel();
    return await super.close();
  }
}
