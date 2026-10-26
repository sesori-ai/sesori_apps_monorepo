import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/models/desktop_install_kind.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";
import "../foundation/velopack/velopack_bindings.dart";

/// Runs the update engine's app startup; only Velopack installs have one. The
/// shell calls it first in `main`, before DI and the first frame.
///
/// The Windows runner already answered every `--veloapp-*` hook launch, so
/// this only cleans up old packages and sets the Windows app identity. It runs
/// synchronously on the root isolate, as Velopack requires, and does only
/// local file work. A failure is logged and startup continues.
void runDesktopUpdateStartupHooks({required InstalledDesktopBundleSource bundleSource}) {
  final DesktopInstallKind installKind = DesktopInstallKind.resolve(
    compiledIdentity: bundleSource.compiledIdentity,
    isAppImage: bundleSource.isAppImage,
  );
  if (installKind != DesktopInstallKind.velopack) {
    return;
  }
  try {
    VelopackBindings.open(libraryPath: bundleSource.velopackLibraryPath).runStartupHooks();
  } on Object catch (error, stackTrace) {
    loge("Failed to run the Velopack startup hooks; updates will fail too", error, stackTrace);
  }
}
