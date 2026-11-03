import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/bridge_process_desired_state.dart";
import "../../foundation/models/desktop_update_state.dart";
import "../../foundation/platform/desktop_application_terminator.dart";
import "../../foundation/platform/launch_at_login.dart";
import "../../foundation/platform/system_tray.dart";
import "../../foundation/platform/window_host.dart";
import "../../orchestration/desktop_bridge_takeover_orchestrator.dart";
import "../../orchestration/desktop_exit_orchestrator.dart";
import "../../repositories/bridge_process_log_repository.dart";
import "../../services/bridge_process_service.dart";
import "../../services/bridge_process_state.dart";
import "../../services/desktop_instance_service.dart";
import "../../services/desktop_relay_connection_service.dart";
import "../../services/desktop_update_service.dart";
import "../../services/window_bounds_service.dart";
import "../../trackers/bridge_control_status.dart";
import "../../trackers/bridge_status_tracker.dart";
import "../../trackers/desktop_logout_tracker.dart";
import "bridge_control_state.dart";

/// The status line and its optional secondary text.
typedef _StatusText = ({String label, String? detail});

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
  required final DesktopRelayConnectionService _relayConnectionService,
  required final DesktopBridgeTakeoverOrchestrator _takeoverOrchestrator,
  required final DesktopLogoutTracker _logoutTracker,
  required final UrlLauncher _urlLauncher,
  required final LaunchAtLogin _launchAtLogin,
  required final DesktopUpdateService _updateService,
  required final DesktopExitOrchestrator _exitOrchestrator,
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
    required DesktopRelayConnectionService relayConnectionService,
    required DesktopBridgeTakeoverOrchestrator takeoverOrchestrator,
    required DesktopLogoutTracker logoutTracker,
    required UrlLauncher urlLauncher,
    required LaunchAtLogin launchAtLogin,
    required DesktopUpdateService updateService,
    required DesktopExitOrchestrator exitOrchestrator,
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
         relayConnectionService: relayConnectionService,
         takeoverOrchestrator: takeoverOrchestrator,
         logoutTracker: logoutTracker,
         urlLauncher: urlLauncher,
         launchAtLogin: launchAtLogin,
         updateService: updateService,
         exitOrchestrator: exitOrchestrator,
         hiddenLaunch: hiddenLaunch,
       );

  this
    : super(
        BridgeControlState(
          trayAvailability: SystemTrayAvailability.initializing,
          activity: _logoutTracker.status.locksBridgeControls
              ? BridgeControlActivity.signingOut
              : BridgeControlActivity.idle,
          statusLabel: _statusText(processState: _processService.state, status: _statusTracker.status).label,
          statusDetail: _statusText(processState: _processService.state, status: _statusTracker.status).detail,
          processState: _processService.state,
          desiredState: _processService.desiredState,
          toggleTarget: _toggleTarget(
            processState: _processService.state,
            desiredState: _processService.desiredState,
          ),
          launchAtLoginEnabled: false,
          controlStatus: _statusTracker.status,
          updateState: _updateService.currentState,
        ),
      );

  StreamSubscription<BridgeProcessState>? _processSubscription;
  StreamSubscription<BridgeControlStatus>? _statusSubscription;
  StreamSubscription<SystemTrayCommand>? _commandSubscription;
  StreamSubscription<WindowHostEvent>? _windowSubscription;
  StreamSubscription<DesktopLogoutStatus>? _logoutSubscription;
  StreamSubscription<void>? _focusRequestSubscription;
  StreamSubscription<DesktopUpdateState>? _updateSubscription;
  StreamSubscription<void>? _restartRequestSubscription;
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
    _updateSubscription = _updateService.states.listen((_) => _rebuildMenu());
    _restartRequestSubscription = _updateService.restartRequests.listen((_) {
      if (_controlsLocked) {
        // The runner's menu cannot see the lock, so a restart chosen meanwhile is dropped.
        logi("Ignoring a Sparkle restart request while desktop controls are locked");
        return;
      }
      unawaited(restartToUpdate());
    });

    await _loadLaunchAtLoginState();
    if (!isClosed) {
      _rebuildMenu(syncTray: false);
    }

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
      case SystemTrayCommand.restartToUpdate:
        if (!_controlsLocked) {
          unawaited(restartToUpdate());
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
        _quitWhenIdle();
      case WindowHostEvent.quitRequested:
        _quitWhenIdle();
    }
  }

  /// Quits now, or after the running lifecycle operation; a running quit
  /// already covers the request.
  void _quitWhenIdle() {
    if (_logoutStatus.locksBridgeControls) {
      _quitAfterActivity = true;
      return;
    }
    switch (_activity) {
      case BridgeControlActivity.idle:
        unawaited(quit());
      case BridgeControlActivity.toggling ||
          BridgeControlActivity.signingOut ||
          BridgeControlActivity.configuringLaunchAtLogin:
        _quitAfterActivity = true;
      case BridgeControlActivity.quitting:
        return;
    }
  }

  void _onLogoutStatus(DesktopLogoutStatus status) {
    _logoutStatus = status;
    _rebuildMenu();
    if (!status.locksBridgeControls && _activity == BridgeControlActivity.idle && _quitAfterActivity) {
      _quitAfterActivity = false;
      _quitWhenIdle();
    }
  }

  bool get _controlsLocked => _activity.locksCommands || _logoutTracker.status.locksBridgeControls;

  /// Reconciles General preferences with the OS without racing a quick toggle.
  Future<void> refreshLaunchAtLogin() async {
    if (isClosed || _controlsLocked) return;
    _activity = BridgeControlActivity.configuringLaunchAtLogin;
    _rebuildMenu();
    try {
      await _loadLaunchAtLoginState();
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
        if (_quitAfterActivity) {
          _quitAfterActivity = false;
          _quitWhenIdle();
        }
      }
    }
  }

  Future<void> _loadLaunchAtLoginState() async {
    try {
      _launchAtLoginEnabled = await _launchAtLogin.isEnabled();
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop launch-at-login state", error, stackTrace);
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
  /// semantics. Used when only the local helper needs recovery.
  Future<void> startBridge() => _setBridgeDesiredState(target: BridgeProcessDesiredState.on);

  /// An explicit Stop must not become Start if the helper exits before dispatch.
  Future<void> stopBridge() => _setBridgeDesiredState(target: BridgeProcessDesiredState.off);

  /// Recovers both desktop connection owners through their Layer-3 services.
  Future<void> recoverConnection() {
    if (_controlsLocked) {
      return Future<void>.value();
    }
    return Future.wait<void>([
      startBridge(),
      _relayConnectionService.recoverForAuthenticatedDestination(),
    ]);
  }

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
          _quitWhenIdle();
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
          _quitWhenIdle();
        }
      }
    }
  }

  Future<void> toggleLaunchAtLogin() => setLaunchAtLogin(enabled: !_launchAtLoginEnabled);

  Future<void> setLaunchAtLogin({required bool enabled}) async {
    if (_controlsLocked) {
      return;
    }
    _activity = BridgeControlActivity.configuringLaunchAtLogin;
    _rebuildMenu();
    try {
      if (enabled) {
        await _launchAtLogin.enable();
      } else {
        await _launchAtLogin.disable();
      }
      _launchAtLoginEnabled = enabled;
    } on Object catch (error, stackTrace) {
      logw("Launch-at-login command failed", error, stackTrace);
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
        if (_quitAfterActivity) {
          _quitAfterActivity = false;
          _quitWhenIdle();
        }
      }
    }
  }

  Future<void> openLogs() async {
    try {
      final Uri uri = await _logRepository.logDirectoryUri;
      final bool opened = await _urlLauncher.launch(uri);
      if (!opened) {
        logw("The desktop could not open the logs directory");
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to open the logs directory", error, stackTrace);
    }
  }

  Future<void> quit() => _exit(intent: DesktopExitIntent.quit);

  /// Quits so the installed update starts in its place.
  Future<void> restartToUpdate() => _exit(intent: DesktopExitIntent.restartToUpdate);

  Future<void> _exit({required DesktopExitIntent intent}) async {
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
      await _exitOrchestrator.prepareExit(intent: intent);
    } on Object catch (error, stackTrace) {
      logw("Desktop ${intent.name} stopped because preparing the exit failed", error, stackTrace);
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
    await flushLogs(timeout: const Duration(seconds: 2));
    _applicationTerminator.terminate();
  }

  void _markQuitFailed() {
    _applicationTerminator.cancelTermination();
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
    final statusText = _statusText(processState: processState, status: controlStatus);
    final BridgeControlState nextState = BridgeControlState(
      trayAvailability: _trayAvailability,
      activity: activity,
      statusLabel: statusText.label,
      statusDetail: statusText.detail,
      processState: processState,
      desiredState: desiredState,
      toggleTarget: _toggleTarget(processState: processState, desiredState: desiredState),
      launchAtLoginEnabled: _launchAtLoginEnabled,
      controlStatus: controlStatus,
      updateState: _updateService.currentState,
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
    if ((processState is BridgeProcessStopped || processState is BridgeProcessStartFailed) &&
        desiredState == BridgeProcessDesiredState.on) {
      return BridgeProcessDesiredState.on;
    }
    if (processState is BridgeProcessRunning && desiredState == BridgeProcessDesiredState.off) {
      return BridgeProcessDesiredState.off;
    }
    return desiredState == BridgeProcessDesiredState.on ? BridgeProcessDesiredState.off : BridgeProcessDesiredState.on;
  }

  static _StatusText _statusText({required BridgeProcessState processState, required BridgeControlStatus status}) {
    return switch (processState) {
      BridgeProcessStopped() => (label: "Off", detail: null),
      BridgeProcessLoginRequired() => (label: "Login required", detail: null),
      BridgeProcessStarting() => (label: "Starting", detail: null),
      BridgeProcessStartFailed() => (label: "Repair required", detail: null),
      BridgeProcessRunning() => _runningStatusText(status: status),
      BridgeProcessStopping() => (label: "Stopping", detail: null),
      BridgeProcessContention() => (label: "Another bridge is running", detail: null),
      BridgeProcessCrashRetryScheduled(:final delay) => (label: "Restarting in ${delay.inSeconds}s", detail: null),
      BridgeProcessCrashGiveUp() => (label: "Stopped after repeated crashes", detail: null),
    };
  }

  static _StatusText _runningStatusText({required BridgeControlStatus status}) {
    if (!status.helperOnline) {
      return (label: "Connecting", detail: null);
    }
    return switch (status.startup) {
      ControlStartupState.unknown => (label: "Status unknown", detail: null),
      ControlStartupState.starting => (label: "Starting", detail: null),
      ControlStartupState.waitingForServer => (
        label: "Starting — waiting for server (retrying every minute)",
        detail: null,
      ),
      ControlStartupState.waitingForAuthentication => (
        label: "Starting — waiting for desktop authentication (retrying every minute)",
        detail: null,
      ),
      ControlStartupState.ready => switch (status.relay) {
        ControlRelayConnectionState.connected => _connectedStatusText(unhealthyPlugins: status.unhealthyPlugins),
        ControlRelayConnectionState.connecting => (label: "Connecting", detail: null),
        ControlRelayConnectionState.disconnected => (label: "Reconnecting", detail: null),
        ControlRelayConnectionState.takenOver => (label: "Relay taken over", detail: null),
      },
    };
  }

  /// Names the unhealthy plugins in the status, grouped under their state with
  /// the worst first ("Failed · Codex; Degraded · Pi"), and carries their
  /// hints as the detail, each prefixed with its plugin's name once several
  /// need attention.
  static _StatusText _connectedStatusText({required List<ControlUnhealthyPlugin> unhealthyPlugins}) {
    if (unhealthyPlugins.isEmpty) {
      return (label: "Connected", detail: null);
    }
    final groups = [
      for (final state in const [ControlUnhealthyPluginState.failed, ControlUnhealthyPluginState.degraded])
        if (unhealthyPlugins.where((plugin) => plugin.state == state).map((plugin) => plugin.displayName).toList()
            case final names when names.isNotEmpty)
          "${_unhealthyStateLabel(state)} · ${names.join(", ")}",
    ];
    final hints = [
      for (final plugin in unhealthyPlugins)
        if (plugin.actionHint case final hint?) unhealthyPlugins.length == 1 ? hint : "${plugin.displayName}: $hint",
    ];
    return (label: groups.join("; "), detail: hints.isEmpty ? null : hints.join("\n"));
  }

  static String _unhealthyStateLabel(ControlUnhealthyPluginState state) => switch (state) {
    ControlUnhealthyPluginState.failed => "Failed",
    ControlUnhealthyPluginState.degraded => "Degraded",
  };

  @override
  Future<void> close() async {
    await _updateSubscription?.cancel();
    await _restartRequestSubscription?.cancel();
    await _focusRequestSubscription?.cancel();
    await _logoutSubscription?.cancel();
    await _windowSubscription?.cancel();
    await _commandSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _processSubscription?.cancel();
    return await super.close();
  }
}
