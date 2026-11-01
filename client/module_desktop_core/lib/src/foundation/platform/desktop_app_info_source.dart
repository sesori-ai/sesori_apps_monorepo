import "../models/desktop_bundle_identity.dart";

/// Layer-0 facts about the running app, provided by the desktop shell.
abstract interface class DesktopAppInfoSource() {
  /// The OS the app is running on, or null outside the desktop OSes.
  DesktopBundleOs? get platform;

  /// The version as packaged, which may carry a `+build` suffix. Throws when it
  /// can't be read.
  Future<String> readVersion();
}
