/// An update Sparkle has downloaded and verified: the appcast's display
/// version and its `sparkle:version`, which is the build number.
class const SparkleDownloadedUpdate({required final String version, required final int buildNumber});

/// Layer-0 seam over Sparkle in the macOS runner. Sparkle schedules its own
/// background checks, downloads silently and verifies each update's EdDSA
/// signature against the runner's `SUPublicEDKey`; normal updates show no
/// Sparkle UI. The runner also adds "Check for Updates…" to the app menu and
/// reports that check's result in its own window.
abstract interface class SparkleUpdateEngine() {
  /// Starts Sparkle on [feedUri]. Runs once, before any other call.
  /// [showsBuildNumber] makes the runner's update window name the build.
  Future<void> start({required Uri feedUri, required bool automaticChecks, required bool showsBuildNumber});

  Future<void> setAutomaticChecks({required bool enabled});

  /// Checks once in the background and completes when Sparkle's update cycle
  /// ends; throws when the check failed. A newer update downloads silently
  /// and appears on [downloadedUpdates] before this completes.
  Future<void> checkNow();

  /// Each update Sparkle has downloaded and verified. It installs when the
  /// app terminates normally.
  Stream<SparkleDownloadedUpdate> get downloadedUpdates;

  /// Each "Restart to Update" chosen in the app menu or the update window.
  Stream<void> get restartRequests;

  /// Installs the downloaded update now. Sparkle then asks the app to quit and
  /// opens the new version once it has exited.
  Future<void> installAndRelaunch();
}
