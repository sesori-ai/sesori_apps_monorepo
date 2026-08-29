import "../../foundation/bridge_process_desired_state.dart";
import "../../foundation/platform/system_tray.dart";
import "../../services/bridge_process_state.dart";
import "../../trackers/bridge_control_status.dart";

/// The business operation currently owning bridge controls.
enum BridgeControlActivity({required final bool locksCommands}) {
  idle(locksCommands: false),
  toggling(locksCommands: true),
  signingOut(locksCommands: true),
  quitting(locksCommands: true),
}

/// Current tray and window presentation state for bridge supervision.
class const BridgeControlState({
  required final SystemTrayAvailability trayAvailability,
  required final SystemTrayMenu menu,
  required final BridgeControlActivity activity,
  required final String statusLabel,
  required final BridgeProcessState processState,
  required final BridgeProcessDesiredState desiredState,
  required final BridgeProcessDesiredState toggleTarget,
  required final BridgeControlStatus controlStatus,
});
