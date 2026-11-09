/// A command picked from the native app menu.
enum DesktopAppMenuCommand() {
  increaseTextSize,
  decreaseTextSize,
  resetTextSize,
}

/// The native app menu's own items, on platforms that have one (macOS). Their
/// key equivalents match the app's shortcuts, so a press reaches only one of them.
abstract interface class DesktopAppMenu() {
  /// The commands the user picks from the menu; never emits where there is none.
  Stream<DesktopAppMenuCommand> get commands;
}
