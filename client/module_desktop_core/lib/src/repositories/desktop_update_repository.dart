import "package:injectable/injectable.dart";

import "../api/desktop_relaunch_api.dart";
import "../api/desktop_update_feed_api.dart";
import "../api/velopack_update_api.dart";
import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_update_state.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";
import "desktop_update_feed_validator.dart";

/// Layer-2 update engine for this install kind. Linux packages and Velopack
/// installs have one; macOS keeps the manual download until Sparkle lands.
@lazySingleton
class DesktopUpdateRepository._create({
  required final InstalledDesktopBundleSource _bundleSource,
  required final DesktopRelaunchApi _relaunchApi,
  required final DesktopUpdateFeedApi _feedApi,
  required final DesktopUpdateFeedValidator _feedValidator,
  required final VelopackUpdateApi _velopackApi,
}) {
  new({
    required InstalledDesktopBundleSource bundleSource,
    required DesktopRelaunchApi relaunchApi,
    required DesktopUpdateFeedApi feedApi,
    required DesktopUpdateFeedValidator feedValidator,
    required VelopackUpdateApi velopackApi,
  }) : this._create(
         bundleSource: bundleSource,
         relaunchApi: relaunchApi,
         feedApi: feedApi,
         feedValidator: feedValidator,
         velopackApi: velopackApi,
       );

  late final DesktopInstallKind installKind = DesktopInstallKind.resolve(
    compiledIdentity: _bundleSource.compiledIdentity,
    isAppImage: _bundleSource.isAppImage,
  );

  /// The state before any check has run.
  DesktopUpdateState initialState() => switch ((installKind, _bundleSource.compiledIdentity)) {
    (DesktopInstallKind.linuxPackage, _) => const DesktopUpdateManagedBySystem(),
    (DesktopInstallKind.velopack, _) => const DesktopUpdateIdle(),
    (DesktopInstallKind.macosSparkle, final DesktopBundleIdentity identity) => DesktopUpdateManualDownload(
      downloadsUri: Uri(
        scheme: "https",
        host: "sesori.com",
        path: "/desktop/",
        fragment: "${_bundleSource.channel.name}-${identity.os.name}-${identity.architecture.name}",
      ),
    ),
    _ => const DesktopUpdateUnavailable(reason: DesktopUpdateUnavailableReason.developmentBuild),
  };

  /// One check of this install kind's engine. Throws on any failure.
  Future<DesktopUpdateState> check() async => switch ((installKind, _bundleSource.compiledIdentity)) {
    (DesktopInstallKind.linuxPackage, _) => _readInstalledPackageState(),
    (DesktopInstallKind.velopack, final DesktopBundleIdentity identity) => await _checkVelopack(identity: identity),
    _ => initialState(),
  };

  Future<void> relaunchInstalledPackage() => _relaunchApi.relaunchInstalledPackage();

  /// Starts Velopack's updater for the downloaded package; it installs once this process exits.
  Future<void> applyDownloadedUpdate({required bool restart}) => _velopackApi.applyPendingRelease(restart: restart);

  /// Ready once the package manager has installed a different bundle than the
  /// one this process is running.
  DesktopUpdateState _readInstalledPackageState() {
    final DesktopBundleIdentity installed = _bundleSource.readInstalledIdentity();
    if (installed == _bundleSource.compiledIdentity) {
      return const DesktopUpdateManagedBySystem();
    }
    return DesktopUpdateReady(version: installed.version);
  }

  /// Ready once Velopack holds a verified newer package. Fetches the signed
  /// feed, verifies it, and downloads the package only when Velopack's own
  /// check finds one newer than the running version.
  Future<DesktopUpdateState> _checkVelopack({required DesktopBundleIdentity identity}) async {
    final String? pendingVersion = await _velopackApi.readPendingVersion();
    if (pendingVersion != null) {
      return DesktopUpdateReady(version: pendingVersion);
    }
    final DesktopUpdateFeed feed = await _feedApi.fetchFeed(identity: identity);
    await _feedValidator.verify(feed: feed);
    final VelopackStagedRelease? release = await _velopackApi.stageFeed(feed: feed.bytes);
    if (release == null) {
      return const DesktopUpdateIdle();
    }
    await _feedApi.downloadPackage(
      identity: identity,
      fileName: release.fileName,
      destination: await _velopackApi.stagedPackageFile(release: release),
    );
    return DesktopUpdateReady(version: await _velopackApi.downloadStagedRelease());
  }
}
