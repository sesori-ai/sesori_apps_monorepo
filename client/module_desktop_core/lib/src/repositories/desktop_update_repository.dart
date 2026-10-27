import "package:injectable/injectable.dart";

import "../api/desktop_relaunch_api.dart";
import "../api/desktop_update_feed_api.dart";
import "../api/velopack_update_api.dart";
import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_release_channel.dart";
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
  Stream<DesktopUpdateState> get sparkleDownloads => _sparkleEngine.downloadedUpdates.map(
    (update) => _ready(version: update.version, buildNumber: update.buildNumber),
  );

  /// Each "Restart to Update" chosen in the macOS app menu or update window.
  Stream<void> get sparkleRestartRequests => _sparkleEngine.restartRequests;

  /// Starts Sparkle on this install's appcast; Sparkle schedules its own checks.
  Future<void> startSparkle({required bool automaticChecks}) => switch (_bundleSource.compiledIdentity) {
    final DesktopBundleIdentity identity => _sparkleEngine.start(
      feedUri: _feedApi.appcastUri(identity: identity),
      automaticChecks: automaticChecks,
      showsBuildNumber: _bundleSource.channel == DesktopReleaseChannel.internal,
    ),
    null => throw StateError("A source build has no update feed"),
  };

  Future<void> setSparkleAutomaticChecks({required bool enabled}) =>
      _sparkleEngine.setAutomaticChecks(enabled: enabled);

  /// Completes when Sparkle's check ends and throws when it failed. Sparkle
  /// reports a downloaded update on [sparkleDownloads], not here.
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
    return _ready(version: installed.version, buildNumber: installed.buildNumber);
  }

  /// Ready once Velopack holds a verified newer package. Fetches the signed
  /// feed and verifies it on every check, so a build published while an older
  /// one waits replaces it; the package downloads only when Velopack's own
  /// check names one newer than the running version that is not already waiting.
  Future<DesktopUpdateState> _checkVelopack({required DesktopBundleIdentity identity}) async {
    final String? pendingVersion = await _velopackApi.readPendingVersion();
    final DesktopUpdateFeed feed = await _feedApi.fetchFeed(identity: identity);
    await _feedValidator.verify(feed: feed);
    final VelopackStagedRelease? release = await _velopackApi.stageFeed(feed: feed.bytes);
    if (release == null || release.version == pendingVersion) {
      return switch (pendingVersion) {
        final String version => _velopackReady(packVersion: version),
        null => const DesktopUpdateIdle(),
      };
    }
    await _feedApi.downloadPackage(
      identity: identity,
      fileName: release.fileName,
      destination: await _velopackApi.stagedPackageFile(release: release),
    );
    return _velopackReady(packVersion: await _velopackApi.downloadStagedRelease());
  }

  /// Internal Velopack packages carry the build in their SemVer, as
  /// `<version>-internal.<build>`; stable ones are the plain version.
  DesktopUpdateState _velopackReady({required String packVersion}) =>
      switch (_internalPackVersion.firstMatch(packVersion)?.groups(<int>[1, 2])) {
        [final String version?, final String build?] => _ready(version: version, buildNumber: int.parse(build)),
        _ => DesktopUpdateReady(version: packVersion, internalBuildNumber: null),
      };

  DesktopUpdateReady _ready({required String version, required int buildNumber}) => DesktopUpdateReady(
    version: version,
    internalBuildNumber: _bundleSource.channel == DesktopReleaseChannel.internal ? buildNumber : null,
  );

  static final RegExp _internalPackVersion = RegExp(r"^(.+)-internal\.(\d+)$");
}
