import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/platform/desktop_application_terminator.dart";
import "../../foundation/platform/system_tray.dart";
import "../../services/bridge_process_service.dart";
import "../../services/bridge_process_state.dart";
import "../../trackers/bridge_control_status.dart";
import "../../trackers/bridge_status_tracker.dart";
import "bridge_control_state.dart";

/// Layer-4 owner of the desktop bridge tray and its lifecycle commands.
///
/// The platform adapter only renders [SystemTrayMenu] and emits commands. This
/// cubit derives the menu from Layer-2/3 snapshots, sequences On/Off, and exits
/// the process only after expected bridge teardown succeeds.
class BridgeControlCubit._create({
  required final BridgeProcessService _processService,
  required final BridgeStatusTracker _statusTracker,
  required final SystemTray _systemTray,
  required final DesktopApplicationTerminator _applicationTerminator,
}) extends Cubit<BridgeControlState> {
  new({
    required BridgeProcessService processService,
    required BridgeStatusTracker statusTracker,
    required SystemTray systemTray,
    required DesktopApplicationTerminator applicationTerminator,
  }) : this._create(
         processService: processService,
         statusTracker: statusTracker,
         systemTray: systemTray,
         applicationTerminator: applicationTerminator,
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
        ),
      );

  StreamSubscription<BridgeProcessState>? _processSubscription;
  StreamSubscription<BridgeControlStatus>? _statusSubscription;
  StreamSubscription<SystemTrayCommand>? _commandSubscription;
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
    if (_activity.locksCommands) {
      return;
    }
    switch (command) {
      case SystemTrayCommand.toggleBridge:
        unawaited(_toggleBridge());
      case SystemTrayCommand.quit:
        unawaited(_quit());
    }
  }

  Future<void> _toggleBridge() async {
    _activity = BridgeControlActivity.toggling;
    _rebuildMenu();
    try {
      switch (_processService.desiredState) {
        case BridgeProcessDesiredState.off:
          await _processService.start();
        case BridgeProcessDesiredState.on:
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

  Future<void> _quit() async {
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
    _applicationTerminator.terminate(exitCode: 0);
  }

  void _rebuildMenu({bool syncTray = true}) {
    if (isClosed) {
      return;
    }
    final SystemTrayMenu menu = _buildMenu(
      processState: _processService.state,
      desiredState: _processService.desiredState,
      status: _statusTracker.status,
      activity: _activity,
    );
    emit(
      BridgeControlState(
        trayAvailability: _trayAvailability,
        menu: menu,
        activity: _activity,
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
    return SystemTrayMenu(
      entries: <SystemTrayMenuEntry>[
        SystemTrayTextItem(
          label: _statusLabel(processState: processState, status: status),
        ),
        SystemTrayTextItem(label: "Active sessions: ${status.activeSessionCount}"),
        const SystemTraySeparator(),
        SystemTrayCommandItem(
          command: SystemTrayCommand.toggleBridge,
          label: desiredState == BridgeProcessDesiredState.on ? "Turn Bridge Off" : "Turn Bridge On",
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
    await _commandSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _processSubscription?.cancel();
    return await super.close();
  }
}
