import "dart:io";

/// Resolves the desktop app's private application-support directory.
///
/// The product shell implements this through its platform directory provider;
/// desktop-core storage must never fall back to the bridge CLI's shared Sesori
/// data root.
abstract class DesktopApplicationSupportDirectory() {
  Future<Directory> resolve();
}
