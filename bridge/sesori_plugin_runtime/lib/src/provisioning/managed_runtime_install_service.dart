import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginStartAbortedException,
        ProvisionFailed,
        ProvisionReady,
        ProvisionResolving,
        RuntimeProvisionProgress,
        StartAbortSignal;

import "managed_runtime_cleaner.dart";
import "runtime_install_service.dart";
import "runtime_manifest.dart";
import "runtime_version_validator.dart";

/// Installs a manifest's pinned managed runtime on explicit request and
/// reports progress.
///
/// This is the on-demand counterpart of [ManagedRuntimeProvisionService]
/// (which only resolves already-present runtimes): it selects the platform
/// asset, reuses a healthy existing install, otherwise downloads, verifies,
/// extracts, and places the binary via [RuntimeInstallService], probes the
/// result actually runs, and finally sweeps superseded managed versions.
///
/// Terminal events are [ProvisionReady] (the installed binary path) or
/// [ProvisionFailed] with a sanitized user-facing message. An abort surfaces
/// as [PluginStartAbortedException].
class ManagedRuntimeInstallService {
  final RuntimeManifest _manifest;
  final RuntimeVersionValidator _versionValidator;
  final RuntimeInstallService _installService;
  final ManagedRuntimeCleaner _cleaner;

  ManagedRuntimeInstallService({
    required RuntimeManifest manifest,
    required RuntimeVersionValidator versionValidator,
    required RuntimeInstallService installService,
    required ManagedRuntimeCleaner cleaner,
  }) : _manifest = manifest,
       _versionValidator = versionValidator,
       _installService = installService,
       _cleaner = cleaner;

  Stream<RuntimeProvisionProgress> install({
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
  }) async* {
    _throwIfAborted(startAborted: startAborted);
    yield const ProvisionResolving();

    final String id = _manifest.runtimeId;
    final String name = _manifest.displayName;
    final SemanticVersion bundled = _manifest.bundledVersion;

    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error) {
      // Surfaced (and rendered) via ProvisionFailed — no separate upfront log.
      yield ProvisionFailed(
        message: "Could not determine this machine's platform for the $name runtime ($error).",
      );
      return;
    }
    final RuntimeAsset? asset = _manifest.assetFor(target: target);
    if (asset == null) {
      yield ProvisionFailed(
        message: "$name has no managed runtime for this platform (${target.key}).",
      );
      return;
    }

    final String managedDir = p.join(stateDirectory, id);
    final String versionDir = p.join(managedDir, bundled.toString());
    final String binaryPath = p.join(versionDir, _manifest.binaryFileName);

    if (_installService.isInstalled(
      versionDir: versionDir,
      binaryFileName: _manifest.binaryFileName,
      sha256: asset.sha256,
    )) {
      // Confirm the cached binary still runs before reporting it as the
      // install result; a broken cached copy falls through to a reinstall.
      final SemanticVersion? cachedVersion = await _versionValidator.detectVersion(
        executable: binaryPath,
        environment: environment,
      );
      _throwIfAborted(startAborted: startAborted);
      if (cachedVersion != null && cachedVersion.compareTo(bundled) == 0) {
        Log.i("[$id] managed $name $bundled already installed");
        yield ProvisionReady(binaryPath: binaryPath);
        await _cleaner.sweep(managedDir: managedDir, keepVersion: bundled.toString());
        return;
      }
      Log.w(
        "[$id] cached managed runtime at '$binaryPath' is version "
        "'${cachedVersion ?? "unrunnable"}' (expected '$bundled'); reinstalling",
      );
    }

    try {
      // await-for (not yield*) so a failure from the install stream throws
      // into this try/catch; yield* would forward the error to the consumer.
      await for (final RuntimeProvisionProgress event in _installService.install(
        managedDir: managedDir,
        versionDir: versionDir,
        binaryFileName: _manifest.binaryFileName,
        downloadUrl: _manifest.downloadUrlFor(asset: asset),
        asset: asset,
        startAborted: startAborted,
      )) {
        yield event;
      }
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      // The wire message must stay sanitized (install errors can carry local
      // paths and raw command output), so only the local log keeps the detail.
      Log.w("[$id] managed $name runtime install failed", error, stackTrace);
      yield ProvisionFailed(
        message: "Could not install the $name runtime. Check the bridge logs for details.",
      );
      return;
    }

    // Probe the freshly-placed binary before trusting it: a downloaded asset
    // that cannot execute on this host (CPU/dynamic-loader mismatch) must
    // fail honestly rather than reporting a ready path start() cannot spawn.
    final SemanticVersion? installedVersion = await _versionValidator.detectVersion(
      executable: binaryPath,
      environment: environment,
    );
    _throwIfAborted(startAborted: startAborted);
    if (installedVersion == null || installedVersion.compareTo(bundled) != 0) {
      yield ProvisionFailed(
        message:
            "The downloaded $name runtime is not runnable on this machine "
            "(reported '${installedVersion ?? "no version"}', expected '$bundled').",
      );
      return;
    }

    Log.i("[$id] installed managed $name $bundled");
    yield ProvisionReady(binaryPath: binaryPath);
    await _cleaner.sweep(managedDir: managedDir, keepVersion: bundled.toString());
  }

  void _throwIfAborted({required StartAbortSignal startAborted}) {
    if (startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
  }
}
