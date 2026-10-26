import "package:injectable/injectable.dart";

import "../api/desktop_relaunch_api.dart";
import "../api/desktop_update_feed_api.dart";
import "../api/velopack_update_api.dart";
import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_update_state.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";
import "../foundation/platform/sparkle_update_engine.dart";
import "desktop_update_feed_validator.dart";

/// Layer-2 update engine for this install kind: Sparkle on macOS, Velopack on
/// Windows and AppImage, and the package manager for DEB and RPM.
@lazySingleton
class DesktopUpdateRepository._create({
  required final InstalledDesktopBundleSource _bundleSource,
  required final DesktopRelaunchApi _relaunchApi,
  required final DesktopUpdateFeedApi _feedApi,
  required final DesktopUpdateFeedValidator _feedValidator,
  required final VelopackUpdateApi _velopackApi,
  required final SparkleUpdateEngine _sparkleEngine,
}) {
  new({
    required InstalledDesktopBundleSource bundleSource,
    required DesktopRelaunchApi relaunchApi,
    required DesktopUpdateFeedApi feedApi,
    required DesktopUpdateFeedValidator feedValidator,
    required VelopackUpdateApi velopackApi,
    required SparkleUpdateEngine sparkleEngine,
  }) : this._create(
         bundleSource: bundleSource,
         relaunchApi: relaunchApi,
         feedApi: feedApi,
         feedValidator: feedValidator,
         velopackApi: velopackApi,
         sparkleEngine: sparkleEngine,
       );

  late final DesktopInstallKind installKind = DesktopInstallKind.resolve(
    compiledIdentity: _bundleSource.compiledIdentity,
    isAppImage: _bundleSource.isAppImage,
  );

  /// The state before any check has run.
  DesktopUpdateState initialState() => switch (installKind) {
    DesktopInstallKind.linuxPackage => const DesktopUpdateManagedBySystem(),
    DesktopInstallKind.velopack || DesktopInstallKind.macosSparkle => const DesktopUpdateIdle(),
    DesktopInstallKind.development => const DesktopUpdateUnavailable(
      reason: DesktopUpdateUnavailableReason.developmentBuild,
    ),
  };

  /// One check of the Linux package or Velopack engine. Throws on any failure.
  Future<DesktopUpdateState> check() async => switch ((installKind, _bundleSource.compiledIdentity)) {
    (DesktopInstallKind.linuxPackage, _) => _readInstalledPackageState(),
    (DesktopInstallKind.velopack, final DesktopBundleIdentity identity) => await _checkVelopack(identity: identity),
    _ => initialState(),
  };

  Future<void> relaunchInstalledPackage() => _relaunchApi.relaunchInstalledPackage();

  /// Ready for each update Sparkle has downloaded and verified.
  Stream<DesktopUpdateState> get sparkleDownloads =>
      _sparkleEngine.downloadedVersions.map((version) => DesktopUpdateReady(version: version));

  /// Starts Sparkle on this install's appcast; Sparkle schedules its own checks.
  Future<void> startSparkle({required bool automaticChecks}) => switch (_bundleSource.compiledIdentity) {
    final DesktopBundleIdentity identity => _sparkleEngine.start(
      feedUri: _feedApi.appcastUri(identity: identity),
      automaticChecks: automaticChecks,
    ),
    null => throw StateError("A source build has no update feed"),
  };

  Future<void> setSparkleAutomaticChecks({required bool enabled}) =>
      _sparkleEngine.setAutomaticChecks(enabled: enabled);

  /// Sparkle reports a downloaded update on [sparkleDownloads], not here.
  Future<void> checkSparkle() => _sparkleEngine.checkNow();

  Future<void> installSparkleUpdateAndRelaunch() => _sparkleEngine.installAndRelaunch();

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
