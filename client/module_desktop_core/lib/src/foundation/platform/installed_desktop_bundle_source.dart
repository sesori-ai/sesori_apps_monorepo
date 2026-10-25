import "../models/desktop_bundle_identity.dart";
import "../models/desktop_release_channel.dart";

/// Layer-0 build and install facts provided by the desktop shell.
abstract interface class InstalledDesktopBundleSource() {
  /// Identity compiled into the running GUI; null for source builds.
  DesktopBundleIdentity? get compiledIdentity;

  DesktopReleaseChannel get channel;

  /// Whether the running GUI was started from a portable Linux AppImage.
  bool get isAppImage;

  /// Reads the `desktop-bundle.json` currently installed beside the running
  /// GUI. It differs from [compiledIdentity] once a package upgrade replaced
  /// the files on disk. Throws when the manifest is missing or malformed.
  DesktopBundleIdentity readInstalledIdentity();
}
