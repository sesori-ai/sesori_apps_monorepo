import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginHost, PluginStartAbortedException, ProvisionFailed, ProvisionNotice, ProvisionReady, ProvisionResolving, RuntimeProvisionProgress;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "open_code_runtime_cleaner.dart";
import "open_code_runtime_install_service.dart";
import "open_code_runtime_manifest.dart";
import "open_code_version_validator.dart";

/// Decides which OpenCode binary the bridge should launch and ensures it exists.
///
/// Precedence (when neither attach mode nor an explicit `--opencode-bin` applies,
/// which the descriptor handles before delegating here):
/// 1. A PATH OpenCode whose version is at least
///    [OpenCodeRuntimeManifest.minSupportedVersion] — used as-is.
/// 2. Otherwise the managed runtime ([OpenCodeRuntimeManifest.bundledVersion]):
///    reuse the already-installed copy, or download/verify/extract it.
///
/// Emits [RuntimeProvisionProgress]; the terminal event is [ProvisionReady] (the
/// launch path) or [ProvisionFailed] (non-fatal). After a healthy resolution it
/// sweeps superseded managed versions. Re-throws [PluginStartAbortedException]
/// so an aborted provision aborts the start rather than reporting a failure.
class OpenCodeRuntimeProvisionService {
  final OpenCodeRuntimeManifest _manifest;
  final OpenCodeVersionValidator _versionValidator;
  final OpenCodeRuntimeInstallService _installService;
  final OpenCodeRuntimeCleaner _cleaner;

  OpenCodeRuntimeProvisionService({
    required OpenCodeRuntimeManifest manifest,
    required OpenCodeVersionValidator versionValidator,
    required OpenCodeRuntimeInstallService installService,
    required OpenCodeRuntimeCleaner cleaner,
  }) : _manifest = manifest,
       _versionValidator = versionValidator,
       _installService = installService,
       _cleaner = cleaner;

  static const String managedDirName = "opencode";

  Stream<RuntimeProvisionProgress> provision({required PluginHost host}) async* {
    yield const ProvisionResolving();

    final SemanticVersion min = OpenCodeRuntimeManifest.minSupportedVersion;
    final SemanticVersion bundled = OpenCodeRuntimeManifest.bundledVersion;

    // 1. Prefer a recent-enough OpenCode already on PATH.
    final SemanticVersion? osVersion = await _versionValidator.detectVersion(
      executable: "opencode",
      environment: host.environment,
    );
    if (osVersion != null && osVersion.compareTo(min) >= 0) {
      Log.i("[opencode] using PATH OpenCode $osVersion (>= minimum $min)");
      yield const ProvisionReady(binaryPath: "opencode");
      await _sweep(host: host, keepVersion: bundled.toString());
      return;
    }

    // 2. Fall back to the managed runtime.
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error) {
      // An unsupported/undetectable OS or CPU must degrade non-fatally, not
      // crash startup with a raw error from platform detection.
      Log.w("[opencode] could not determine the host platform target: $error");
      yield ProvisionFailed(
        message:
            "Could not determine this machine's platform for the OpenCode runtime ($error). "
            "Install OpenCode manually: https://opencode.ai/docs#install",
      );
      return;
    }
    final OpenCodeRuntimeAsset? asset = _manifest.assetFor(target: target);
    if (asset == null) {
      yield ProvisionFailed(message: _unsupportedPlatformMessage(target: target, osVersion: osVersion, min: min));
      return;
    }

    if (osVersion != null) {
      yield ProvisionNotice(
        message:
            "Installed OpenCode $osVersion is older than the minimum supported $min; "
            "using a managed OpenCode $bundled instead.",
      );
    }

    final String managedDir = p.join(host.stateDirectory, managedDirName);
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
        Log.i("[opencode] managed OpenCode $bundled already installed");
        yield ProvisionReady(binaryPath: binaryPath);
        await _sweep(host: host, keepVersion: bundled.toString());
        return;
      }
      Log.w(
        "[opencode] cached managed runtime at '$binaryPath' is version "
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
    } on OpenCodeRuntimeInstallException catch (error) {
      Log.w("[opencode] managed runtime install failed: ${error.message}");
      yield ProvisionFailed(message: "Could not install the OpenCode runtime: ${error.message}");
      return;
    } on Object catch (error, stackTrace) {
      Log.w("[opencode] managed runtime install failed unexpectedly", error, stackTrace);
      yield ProvisionFailed(message: "Could not install the OpenCode runtime: $error");
      return;
    }

    Log.i("[opencode] installed managed OpenCode $bundled");
    yield ProvisionReady(binaryPath: binaryPath);
    await _sweep(host: host, keepVersion: bundled.toString());
  }

  Future<void> _sweep({required PluginHost host, required String keepVersion}) async {
    // Cleanup runs after the runtime is already healthy (often after a terminal
    // ProvisionReady), so a filesystem error here must never turn a successful
    // provision into a startup failure.
    try {
      await _cleaner.sweep(
        managedDir: p.join(host.stateDirectory, managedDirName),
        keepVersion: keepVersion,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[opencode] failed to sweep superseded managed runtimes", error, stackTrace);
    }
  }

  String _unsupportedPlatformMessage({
    required PlatformTarget target,
    required SemanticVersion? osVersion,
    required SemanticVersion min,
  }) {
    if (osVersion != null) {
      return "Installed OpenCode $osVersion is older than the minimum supported $min, and no managed "
          "OpenCode runtime is available for ${target.key}. Upgrade OpenCode: https://opencode.ai/docs#install";
    }
    return "OpenCode is not installed and no managed OpenCode runtime is available for ${target.key}. "
        "Install OpenCode: https://opencode.ai/docs#install";
  }
}
