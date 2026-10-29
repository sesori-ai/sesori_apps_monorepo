/// Whether the desktop can expose a usable system-tray surface.
enum SystemTrayAvailability({required final bool isAvailable}) {
  initializing(isAvailable: false),
  available(isAvailable: true),
  unavailable(isAvailable: false),
}

/// Commands emitted by the dumb platform tray adapter.
enum SystemTrayCommand() {
  openWindow,
  toggleBridge,
  takeOver,
  toggleLaunchAtLogin,
  restartToUpdate,
  quit,
}

/// Bridge health shown as a coloured dot on the tray icon. Only [failed]
/// asks for the user's attention.
enum SystemTrayStatus() {
  /// Green: the bridge runs and is connected to the relay.
  connected,

  /// Amber: the bridge should run and is starting, reconnecting or retrying.
  connecting,

  /// Grey: the user turned the bridge off.
  off,

  /// Red: the bridge should run but cannot until the user acts.
  failed,
}

/// Platform-neutral tray icon status and menu built by desktop business logic.
class SystemTrayMenu({required final SystemTrayStatus status, required List<SystemTrayMenuEntry> entries}) {
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
