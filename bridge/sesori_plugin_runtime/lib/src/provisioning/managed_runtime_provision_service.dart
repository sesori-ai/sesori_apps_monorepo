import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginHost, PluginStartAbortedException, ProvisionFailed, ProvisionNotice, ProvisionReady, ProvisionResolving, RuntimeProvisionProgress;

import "managed_runtime_cleaner.dart";
import "runtime_install_service.dart";
import "runtime_manifest.dart";
import "runtime_version_validator.dart";

/// Decides which runtime binary the bridge should launch and ensures it exists.
///
/// Precedence (when an explicit override is configured, the descriptor handles
/// it before delegating here):
/// 1. A PATH runtime ([RuntimeManifest.pathExecutableName]) whose version is at
///    least [RuntimeManifest.minPathVersion] — used as-is.
/// 2. Otherwise the managed runtime ([RuntimeManifest.bundledVersion]): reuse
///    the already-installed copy, or download/verify/extract it.
///
/// Emits [RuntimeProvisionProgress]; the terminal event is [ProvisionReady] (the
/// launch path) or [ProvisionFailed] (non-fatal). After a healthy resolution it
/// sweeps superseded managed versions. Re-throws [PluginStartAbortedException]
/// so an aborted provision aborts the start rather than reporting a failure.
///
/// Generic over the harness: everything backend-specific (versions, asset table,
/// URLs, names, install URL, display name) comes from the injected [RuntimeManifest].
class ManagedRuntimeProvisionService {
  final RuntimeManifest _manifest;
  final RuntimeVersionValidator _versionValidator;
  final RuntimeInstallService _installService;
  final ManagedRuntimeCleaner _cleaner;

  ManagedRuntimeProvisionService({
    required RuntimeManifest manifest,
    required RuntimeVersionValidator versionValidator,
    required RuntimeInstallService installService,
    required ManagedRuntimeCleaner cleaner,
  }) : _manifest = manifest,
       _versionValidator = versionValidator,
       _installService = installService,
       _cleaner = cleaner;

  Stream<RuntimeProvisionProgress> provision({required PluginHost host}) async* {
    yield const ProvisionResolving();

    final String id = _manifest.runtimeId;
    final String name = _manifest.displayName;
    final SemanticVersion min = _manifest.minPathVersion;
    final SemanticVersion bundled = _manifest.bundledVersion;

    // 1. Prefer a recent-enough runtime already on PATH.
    final SemanticVersion? osVersion = await _versionValidator.detectVersion(
      executable: _manifest.pathExecutableName,
      environment: host.environment,
    );
    if (osVersion != null && osVersion.compareTo(min) >= 0) {
      Log.i("[$id] using PATH $name $osVersion (>= minimum $min)");
      yield ProvisionReady(binaryPath: _manifest.pathExecutableName);
      await _sweep(host: host, keepVersion: bundled.toString());
      return;
    }

    // 2. Fall back to the managed runtime.
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error) {
      // An unsupported/undetectable OS or CPU must degrade non-fatally, not
      // crash startup with a raw error from platform detection. The failure is
      // surfaced (and rendered) via ProvisionFailed, so no separate log here.
      yield ProvisionFailed(
        message:
            "Could not determine this machine's platform for the $name runtime ($error). "
            "Install $name manually: ${_manifest.installDocsUrl}",
      );
      return;
    }
    final RuntimeAsset? asset = _manifest.assetFor(target: target);
    if (asset == null) {
      yield ProvisionFailed(message: _unsupportedPlatformMessage(target: target, osVersion: osVersion, min: min));
      return;
    }

    if (osVersion != null) {
      yield ProvisionNotice(
        message:
            "Installed $name $osVersion is older than the minimum supported $min; "
            "using a managed $name $bundled instead.",
      );
    }

    final String managedDir = p.join(host.stateDirectory, id);
    final String versionDir = p.join(managedDir, bundled.toString());
    final String binaryPath = p.join(versionDir, _manifest.binaryFileName);

    if (_installService.isInstalled(
      versionDir: versionDir,
      binaryFileName: _manifest.binaryFileName,
      sha256: asset.sha256,
    )) {
      // Confirm the cached binary still runs: a sentinel match proves the bytes
      // were verified at install, but the binary could have since lost its
      // executable bit or been corrupted. If it no longer runs, fall through and
      // reinstall rather than emitting a ProvisionReady that start() can't spawn.
      final SemanticVersion? managedVersion = await _versionValidator.detectVersion(
        executable: binaryPath,
        environment: host.environment,
      );
      if (managedVersion != null && managedVersion.compareTo(bundled) == 0) {
        Log.i("[$id] managed $name $bundled already installed");
        yield ProvisionReady(binaryPath: binaryPath);
        await _sweep(host: host, keepVersion: bundled.toString());
        return;
      }
      Log.w(
        "[$id] cached managed runtime at '$binaryPath' is version "
        "'${managedVersion ?? "unrunnable"}' (expected '$bundled'); reinstalling",
      );
    }

    try {
      // await-for (not yield*) so a failure from the install stream throws into
      // this try/catch; yield* would instead forward the error to the consumer.
      await for (final RuntimeProvisionProgress event in _installService.install(
        managedDir: managedDir,
        versionDir: versionDir,
        binaryFileName: _manifest.binaryFileName,
        downloadUrl: _manifest.downloadUrlFor(asset: asset),
        asset: asset,
        startAborted: host.startAborted,
      )) {
        yield event;
      }
    } on PluginStartAbortedException {
      // An aborted provision is an aborted start, surfaced as a stream error so
      // the runner aborts startup rather than treating it as a failure.
      rethrow;
    } on RuntimeInstallException catch (error) {
      // Surfaced (and rendered) via ProvisionFailed — no separate upfront log.
      yield ProvisionFailed(message: "Could not install the $name runtime: ${error.message}");
      return;
    } on Object catch (error) {
      yield ProvisionFailed(message: "Could not install the $name runtime: $error");
      return;
    }

    // Probe the freshly-placed binary before trusting it (the same check the
    // cached path runs above): a downloaded asset that can't execute on this
    // host (CPU/dynamic-loader mismatch) must degrade via ProvisionFailed, not
    // crash start() with a PluginStartException.
    final SemanticVersion? installedVersion = await _versionValidator.detectVersion(
      executable: binaryPath,
      environment: host.environment,
    );
    if (installedVersion == null || installedVersion.compareTo(bundled) != 0) {
      yield ProvisionFailed(
        message:
            "The downloaded $name runtime is not runnable on this machine "
            "(reported '${installedVersion ?? "no version"}', expected '$bundled'). "
            "Install $name manually: ${_manifest.installDocsUrl}",
      );
      return;
    }

    Log.i("[$id] installed managed $name $bundled");
    yield ProvisionReady(binaryPath: binaryPath);
    await _sweep(host: host, keepVersion: bundled.toString());
  }

  Future<void> _sweep({required PluginHost host, required String keepVersion}) async {
    // Cleanup runs after the runtime is already healthy (often after a terminal
    // ProvisionReady), so a filesystem error here must never turn a successful
    // provision into a startup failure.
    try {
      await _cleaner.sweep(
        managedDir: p.join(host.stateDirectory, _manifest.runtimeId),
        keepVersion: keepVersion,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[${_manifest.runtimeId}] failed to sweep superseded managed runtimes", error, stackTrace);
    }
  }

  String _unsupportedPlatformMessage({
    required PlatformTarget target,
    required SemanticVersion? osVersion,
    required SemanticVersion min,
  }) {
    final String name = _manifest.displayName;
    final String url = _manifest.installDocsUrl;
    if (osVersion != null) {
      return "Installed $name $osVersion is older than the minimum supported $min, and no managed "
          "$name runtime is available for ${target.key}. Upgrade $name: $url";
    }
    return "$name is not installed and no managed $name runtime is available for ${target.key}. "
        "Install $name: $url";
  }
}
