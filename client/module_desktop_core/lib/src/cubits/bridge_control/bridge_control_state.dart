import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/bridge_process_desired_state.dart";
import "../../foundation/models/desktop_update_state.dart";
import "../../foundation/platform/system_tray.dart";
import "../../services/bridge_process_state.dart";
import "../../trackers/bridge_control_status.dart";

/// The business operation currently owning bridge controls.
enum BridgeControlActivity({required final bool locksCommands}) {
  idle(locksCommands: false),
  toggling(locksCommands: true),
  signingOut(locksCommands: true),
  configuringLaunchAtLogin(locksCommands: true),
  quitting(locksCommands: true),
}

/// Current tray, launch-at-login, and window presentation state for bridge
/// supervision.
class const BridgeControlState({
  required final SystemTrayAvailability trayAvailability,
  required final BridgeControlActivity activity,

  /// Status detail without an entity prefix; surfaces provide the heading.
  required final String statusLabel,
  required final BridgeProcessState processState,
  required final BridgeProcessDesiredState desiredState,
  required final BridgeProcessDesiredState toggleTarget,
  required final bool launchAtLoginEnabled,
  required final BridgeControlStatus controlStatus,
  required final DesktopUpdateState updateState,
}) {
  /// Whether an explicit user action can reclaim local or relay ownership.
  bool get canTakeOver =>
      processState is BridgeProcessContention || controlStatus.relay == ControlRelayConnectionState.takenOver;

  /// Tray presentation derived from this same state snapshot so tray and
  /// window controls cannot disagree about takeover availability.
  SystemTrayMenu get menu => SystemTrayMenu(
    status: _trayStatus,
    entries: <SystemTrayMenuEntry>[
      const SystemTrayCommandItem(
        command: SystemTrayCommand.openWindow,
        label: "Open Sesori",
        enabled: true,
      ),
      const SystemTraySeparator(),
      SystemTrayTextItem(label: "Bridge: $statusLabel"),
      SystemTrayTextItem(label: "Active sessions: ${controlStatus.activeSessionCount}"),
      const SystemTraySeparator(),
      if (canTakeOver) ...<SystemTrayMenuEntry>[
        SystemTrayCommandItem(
          command: SystemTrayCommand.takeOver,
          label: "Take Over",
          enabled: !activity.locksCommands,
        ),
        const SystemTraySeparator(),
      ],
      SystemTrayCommandItem(
        command: SystemTrayCommand.toggleBridge,
        label: toggleTarget == BridgeProcessDesiredState.off ? "Turn Bridge Off" : "Turn Bridge On",
        enabled: !activity.locksCommands,
      ),
      const SystemTraySeparator(),
      SystemTrayTextItem(label: "Launch at login: ${launchAtLoginEnabled ? "On" : "Off"}"),
      SystemTrayCommandItem(
        command: SystemTrayCommand.toggleLaunchAtLogin,
        label: launchAtLoginEnabled ? "Disable Launch at Login" : "Enable Launch at Login",
        enabled: !activity.locksCommands,
      ),
      const SystemTraySeparator(),
      if (updateState is DesktopUpdateReady)
        SystemTrayCommandItem(
          command: SystemTrayCommand.restartToUpdate,
          label: "Restart to Update",
          enabled: !activity.locksCommands,
        ),
      SystemTrayCommandItem(
        command: SystemTrayCommand.quit,
        label: "Quit Sesori",
        enabled: !activity.locksCommands,
      ),
    ],
  );

  /// Grey once the user wants the bridge off, unless a failed stop left it
  /// running, which keeps its live status. While it should run, red
  /// marks states only the user can resolve (a failed start, a needed sign-in,
  /// another bridge owning this machine or the relay, a crash budget spent);
  /// states the bridge recovers from on its own (starting, a scheduled crash
  /// retry, waiting for the server or authentication, reconnecting) are amber.
  SystemTrayStatus get _trayStatus {
    if (desiredState == BridgeProcessDesiredState.off && processState is! BridgeProcessRunning) {
      return SystemTrayStatus.off;
    }
    return switch (processState) {
      BridgeProcessRunning() => _runningTrayStatus,
      BridgeProcessStarting() ||
      BridgeProcessStopping() ||
      BridgeProcessCrashRetryScheduled() => SystemTrayStatus.connecting,
      // Stopped while desired On means the last start failed.
      BridgeProcessStopped() ||
      BridgeProcessStartFailed() ||
      BridgeProcessLoginRequired() ||
      BridgeProcessContention() ||
      BridgeProcessCrashGiveUp() => SystemTrayStatus.failed,
    };
  }

  SystemTrayStatus get _runningTrayStatus {
    if (!controlStatus.helperOnline || controlStatus.startup != ControlStartupState.ready) {
      return SystemTrayStatus.connecting;
    }
    return switch (controlStatus.relay) {
      ControlRelayConnectionState.connected => SystemTrayStatus.connected,
      ControlRelayConnectionState.takenOver => SystemTrayStatus.failed,
      ControlRelayConnectionState.connecting ||
      ControlRelayConnectionState.disconnected ||
      ControlRelayConnectionState.unknown => SystemTrayStatus.connecting,
    };
  }
}
