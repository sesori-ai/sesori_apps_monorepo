/// Whether the desktop can expose a usable system-tray surface.
enum SystemTrayAvailability({required final bool isAvailable}) {
  initializing(isAvailable: false),
  available(isAvailable: true),
  unavailable(isAvailable: false),
}

/// Commands emitted by the dumb platform tray adapter.
enum SystemTrayCommand({required final String key}) {
  openWindow(key: "open_window"),
  toggleBridge(key: "toggle_bridge"),
  toggleLaunchAtLogin(key: "toggle_launch_at_login"),
  quit(key: "quit");

  static SystemTrayCommand? fromKey({required String? key}) {
    for (final SystemTrayCommand command in values) {
      if (command.key == key) {
        return command;
      }
    }
    return null;
  }
}

/// Platform-neutral tray menu built by desktop business logic.
class SystemTrayMenu({required List<SystemTrayMenuEntry> entries}) {
  final List<SystemTrayMenuEntry> entries = List<SystemTrayMenuEntry>.unmodifiable(entries);
}

sealed class const SystemTrayMenuEntry();

/// A disabled informational line.
final class const SystemTrayTextItem({required final String label}) extends SystemTrayMenuEntry;

/// A clickable business command.
final class const SystemTrayCommandItem({
  required final SystemTrayCommand command,
  required final String label,
  required final bool enabled,
}) extends SystemTrayMenuEntry;

final class const SystemTraySeparator() extends SystemTrayMenuEntry;

/// Layer-0 capability for rendering and receiving system-tray interactions.
abstract interface class SystemTray() {
  Stream<SystemTrayCommand> get commands;

  Future<SystemTrayAvailability> initialize({required SystemTrayMenu menu});

  Future<void> setMenu({required SystemTrayMenu menu});

  Future<void> dispose();
}
