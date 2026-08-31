/// The argument used by the per-user login registration to request a hidden
/// tray-only startup.
const String desktopHiddenLaunchArgument = "--hidden";

/// Whether the desktop was launched by the login registration rather than by a
/// user opening the app directly.
///
/// The parser intentionally accepts only the exact flag; unrelated arguments
/// must not change the normal visible-launch behavior.
bool isDesktopHiddenLaunch({required List<String> arguments}) => arguments.contains(desktopHiddenLaunchArgument);
