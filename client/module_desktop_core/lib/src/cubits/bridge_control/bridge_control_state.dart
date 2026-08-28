import "../../foundation/platform/system_tray.dart";

/// The business operation currently owning tray commands.
enum BridgeControlActivity({required final bool locksCommands}) {
  idle(locksCommands: false),
  toggling(locksCommands: true),
  quitting(locksCommands: true);
}

/// Current tray/fallback presentation state for bridge supervision.
class const BridgeControlState({
  required final SystemTrayAvailability trayAvailability,
  required final SystemTrayMenu menu,
  required final BridgeControlActivity activity,
});
