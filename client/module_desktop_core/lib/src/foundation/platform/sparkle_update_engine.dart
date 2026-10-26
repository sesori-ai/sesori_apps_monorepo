/// Layer-0 seam over Sparkle in the macOS runner. Sparkle schedules its own
/// background checks, downloads silently and verifies each update's EdDSA
/// signature against the runner's `SUPublicEDKey`; normal updates show no
/// Sparkle UI.
abstract interface class SparkleUpdateEngine() {
  /// Starts Sparkle on [feedUri]. Runs once, before any other call.
  Future<void> start({required Uri feedUri, required bool automaticChecks});

  Future<void> setAutomaticChecks({required bool enabled});

  /// Checks once in the background; a newer update downloads silently and
  /// then appears on [downloadedVersions].
  Future<void> checkNow();

  /// The display version of each update Sparkle has downloaded and verified.
  /// It installs when the app terminates normally.
  Stream<String> get downloadedVersions;

  /// Installs the downloaded update now. Sparkle then asks the app to quit and
  /// opens the new version once it has exited.
  Future<void> installAndRelaunch();
}
