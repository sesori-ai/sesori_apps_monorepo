import "package:injectable/injectable.dart";

import "../api/desktop_relaunch_api.dart";
import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_update_state.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";

/// Layer-2 update engine for this install kind. Only Linux packages have an
/// engine so far; macOS and Velopack installs keep the manual download.
@lazySingleton
class DesktopUpdateRepository._create({
  required final InstalledDesktopBundleSource _bundleSource,
  required final DesktopRelaunchApi _relaunchApi,
}) {
  new({required InstalledDesktopBundleSource bundleSource, required DesktopRelaunchApi relaunchApi})
    : this._create(bundleSource: bundleSource, relaunchApi: relaunchApi);

  late final DesktopInstallKind installKind = DesktopInstallKind.resolve(
    compiledIdentity: _bundleSource.compiledIdentity,
    isAppImage: _bundleSource.isAppImage,
  );

  /// The state before any check has run.
  DesktopUpdateState initialState() => switch ((installKind, _bundleSource.compiledIdentity)) {
    (DesktopInstallKind.linuxPackage, _) => const DesktopUpdateManagedBySystem(),
    (DesktopInstallKind.macosSparkle || DesktopInstallKind.velopack, final DesktopBundleIdentity identity) =>
      DesktopUpdateManualDownload(downloadsUri: _downloadsUri(identity: identity)),
    _ => const DesktopUpdateUnavailable(reason: DesktopUpdateUnavailableReason.developmentBuild),
  };

  /// Ready once the package manager has installed a different bundle than the
  /// one this process is running.
  DesktopUpdateState readInstalledPackageState() {
    final DesktopBundleIdentity installed = _bundleSource.readInstalledIdentity();
    if (installed == _bundleSource.compiledIdentity) {
      return const DesktopUpdateManagedBySystem();
    }
    return DesktopUpdateReady(version: installed.version);
  }

  Future<void> relaunchInstalledPackage() => _relaunchApi.relaunchInstalledPackage();

  Uri _downloadsUri({required DesktopBundleIdentity identity}) {
    final String section = "${_bundleSource.channel.name}-${identity.os.name}-${identity.architecture.name}";
    return Uri(
      scheme: "https",
      host: "sesori.com",
      path: "/desktop/",
      fragment: _bundleSource.isAppImage ? "$section-appimage" : section,
    );
  }
}
