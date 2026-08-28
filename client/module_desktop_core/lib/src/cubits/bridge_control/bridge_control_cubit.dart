import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/platform/desktop_application_terminator.dart";
import "../../foundation/platform/system_tray.dart";
import "../../foundation/platform/window_host.dart";
import "../../repositories/bridge_process_log_repository.dart";
import "../../services/bridge_process_service.dart";
import "../../services/bridge_process_state.dart";
import "../../trackers/bridge_control_status.dart";
import "../../trackers/bridge_status_tracker.dart";
import "bridge_control_state.dart";

/// Layer-4 owner of desktop bridge tray/window controls and lifecycle commands.
///
/// Platform adapters only render [SystemTrayMenu], emit typed events, and
/// perform native window operations. This cubit derives presentation from
/// Layer-2/3 snapshots, sequences On/Off, and exits only after expected bridge
/// teardown succeeds.
class BridgeControlCubit._create({
  required final BridgeProcessService _processService,
  required final BridgeStatusTracker _statusTracker,
  required final SystemTray _systemTray,
  required final WindowHost _windowHost,
  required final DesktopApplicationTerminator _applicationTerminator,
  required final BridgeProcessLogRepository _logRepository,
  required final UrlLauncher _urlLauncher,
}) extends Cubit<BridgeControlState> {
  new({
    required BridgeProcessService processService,
    required BridgeStatusTracker statusTracker,
    required SystemTray systemTray,
    required WindowHost windowHost,
    required DesktopApplicationTerminator applicationTerminator,
    required BridgeProcessLogRepository logRepository,
    required UrlLauncher urlLauncher,
  }) : this._create(
         processService: processService,
         statusTracker: statusTracker,
         systemTray: systemTray,
         windowHost: windowHost,
         applicationTerminator: applicationTerminator,
         logRepository: logRepository,
         urlLauncher: urlLauncher,
       );

  this
    : super(
        BridgeControlState(
          trayAvailability: SystemTrayAvailability.initializing,
          menu: _buildMenu(
            processState: _processService.state,
            desiredState: _processService.desiredState,
            status: _statusTracker.status,
            activity: BridgeControlActivity.idle,
          ),
          activity: BridgeControlActivity.idle,
          statusLabel: _statusLabel(processState: _processService.state, status: _statusTracker.status),
          processState: _processService.state,
          desiredState: _processService.desiredState,
          toggleTarget: _toggleTarget(
            processState: _processService.state,
            desiredState: _processService.desiredState,
          ),
          controlStatus: _statusTracker.status,
        ),
      );

  StreamSubscription<BridgeProcessState>? _processSubscription;
  StreamSubscription<BridgeControlStatus>? _statusSubscription;
  StreamSubscription<SystemTrayCommand>? _commandSubscription;
  StreamSubscription<WindowHostEvent>? _windowSubscription;
  SystemTrayAvailability _trayAvailability = SystemTrayAvailability.initializing;
  BridgeControlActivity _activity = BridgeControlActivity.idle;
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

    final SystemTrayAvailability availability;
    try {
      availability = await _systemTray.initialize(menu: state.menu);
    } on Object catch (error, stackTrace) {
      logw("System tray initialization failed; keeping the desktop window visible", error, stackTrace);
      if (!isClosed) {
        _trayAvailability = SystemTrayAvailability.unavailable;
        _rebuildMenu(syncTray: false);
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
    if (availability.isAvailable) {
      await _setMenu(menu: state.menu);
    }
  }

  void _onCommand({required SystemTrayCommand command}) {
    switch (command) {
      case SystemTrayCommand.openWindow:
        unawaited(showWindow());
      case SystemTrayCommand.toggleBridge:
        if (!_activity.locksCommands) {
          unawaited(toggleBridge());
        }
      case SystemTrayCommand.quit:
        if (!_activity.locksCommands) {
          unawaited(quit());
        }
    }
  }

  void _onWindowEvent({required WindowHostEvent event}) {
    switch (event) {
      case WindowHostEvent.closeRequested:
        if (_activity.locksCommands) {
          return;
        }
        if (_trayAvailability.isAvailable) {
          unawaited(hideWindow());
        } else {
          unawaited(quit());
        }
    }
  }

  Future<void> toggleBridge() async {
    _activity = BridgeControlActivity.toggling;
    _rebuildMenu();
    try {
      switch (_toggleTarget(
        processState: _processService.state,
        desiredState: _processService.desiredState,
      )) {
        case BridgeProcessDesiredState.on:
          await _processService.start();
        case BridgeProcessDesiredState.off:
          await _processService.stop();
      }
    } on Object catch (error, stackTrace) {
      logw("Bridge tray lifecycle command failed", error, stackTrace);
    } finally {
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
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
    _activity = BridgeControlActivity.quitting;
    _rebuildMenu();
    try {
      await _processService.stop();
    } on Object catch (error, stackTrace) {
      logw("Desktop quit stopped because the supervised bridge could not stop", error, stackTrace);
      if (!isClosed) {
        _activity = BridgeControlActivity.idle;
        _rebuildMenu();
      }
      return;
    }

    try {
      await _systemTray.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose the system tray during desktop quit", error, stackTrace);
    }
    try {
      await _windowHost.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose the desktop window host during quit", error, stackTrace);
    }
    _applicationTerminator.terminate(exitCode: 0);
  }

  void _rebuildMenu({bool syncTray = true}) {
    if (isClosed) {
      return;
    }
    final BridgeProcessState processState = _processService.state;
    final BridgeProcessDesiredState desiredState = _processService.desiredState;
    final BridgeControlStatus controlStatus = _statusTracker.status;
    final SystemTrayMenu menu = _buildMenu(
      processState: processState,
      desiredState: desiredState,
      status: controlStatus,
      activity: _activity,
    );
    emit(
      BridgeControlState(
        trayAvailability: _trayAvailability,
        menu: menu,
        activity: _activity,
        statusLabel: _statusLabel(processState: processState, status: controlStatus),
        processState: processState,
        desiredState: desiredState,
        toggleTarget: _toggleTarget(processState: processState, desiredState: desiredState),
        controlStatus: controlStatus,
      ),
    );
    if (syncTray && _trayAvailability.isAvailable) {
      unawaited(_setMenu(menu: menu));
    }
  }

  Future<void> _setMenu({required SystemTrayMenu menu}) async {
    try {
      await _systemTray.setMenu(menu: menu);
    } on Object catch (error, stackTrace) {
      logw("Failed to update the system tray menu", error, stackTrace);
    }
  }

  static SystemTrayMenu _buildMenu({
    required BridgeProcessState processState,
    required BridgeProcessDesiredState desiredState,
    required BridgeControlStatus status,
    required BridgeControlActivity activity,
  }) {
    final BridgeProcessDesiredState toggleTarget = _toggleTarget(
      processState: processState,
      desiredState: desiredState,
    );
    return SystemTrayMenu(
      entries: <SystemTrayMenuEntry>[
        const SystemTrayCommandItem(
          command: SystemTrayCommand.openWindow,
          label: "Open Sesori",
          enabled: true,
        ),
        const SystemTraySeparator(),
        SystemTrayTextItem(
          label: _statusLabel(processState: processState, status: status),
        ),
        SystemTrayTextItem(label: "Active sessions: ${status.activeSessionCount}"),
        const SystemTraySeparator(),
        SystemTrayCommandItem(
          command: SystemTrayCommand.toggleBridge,
          label: toggleTarget == BridgeProcessDesiredState.off ? "Turn Bridge Off" : "Turn Bridge On",
          enabled: !activity.locksCommands,
        ),
        const SystemTraySeparator(),
        SystemTrayCommandItem(
          command: SystemTrayCommand.quit,
          label: "Quit Sesori",
          enabled: !activity.locksCommands,
        ),
      ],
    );
  }

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
    await _windowSubscription?.cancel();
    await _commandSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _processSubscription?.cancel();
    return await super.close();
  }
}
