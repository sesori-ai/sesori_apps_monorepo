import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginStartAbortedException,
        ProvisionFailed,
        ProvisionReady,
        ProvisionResolving,
        RuntimeInUseSignal,
        RuntimeProvisionProgress,
        StartAbortSignal;

import "managed_runtime_cleaner.dart";
import "managed_runtime_path_authority.dart";
import "runtime_install_service.dart";
import "runtime_manifest.dart";
import "runtime_version.dart";

/// Installs a manifest's pinned managed runtime on explicit request and
/// reports progress.
///
/// This is the on-demand counterpart of [ManagedRuntimeProvisionService]
/// (which only resolves already-present runtimes): it selects the platform
/// asset, reuses a healthy existing install, otherwise downloads, verifies,
/// extracts, validates, and places the candidate via [RuntimeInstallService],
/// then sweeps managed versions before reporting the
/// terminal event (a consumer may unsubscribe on that event).
///
/// Before either sweep or staging begins, PATH authority is revalidated at this
/// mutation boundary. Managed work proceeds only when the ordinary PATH runtime
/// is genuinely absent.
///
/// The sweep runs in two stages because the plugin may be running from an older
/// managed version while this install downloads its replacement. Versions below
/// [RuntimeManifest.minPathVersion] can never be selected, so they go before the
/// download starts; the rest go once the pinned version is verified, minus any
/// still-supported version that a live generation could be running from.
///
/// Terminal events are [ProvisionReady] (the installed binary path) or
/// [ProvisionFailed] with a sanitized user-facing message. An abort surfaces
/// as [PluginStartAbortedException].
class ManagedRuntimeInstallService({
  required final RuntimeManifest _manifest,
  required final RuntimeInstallService _installService,
  required final ManagedRuntimeCleaner _cleaner,
  required final ManagedRuntimePathAuthority _pathAuthority,
  required final RuntimeAssetResolver _assetResolver,
}) {
  Stream<RuntimeProvisionProgress> install({
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
    required RuntimeInUseSignal runtimeInUse,
  }) async* {
    _throwIfAborted(startAborted: startAborted);
    yield const ProvisionResolving();

    final String id = _manifest.runtimeId;
    final String name = _manifest.displayName;
    final bool pathAbsent;
    try {
      pathAbsent = await _pathAuthority.isPathAbsent(
        environment: environment,
        abortSignal: startAborted,
      );
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Log.w("[$id] could not revalidate PATH authority before managed mutation", error, stackTrace);
      yield ProvisionFailed(
        message: "Could not verify whether the global $name runtime is absent. Check the bridge logs and retry.",
      );
      return;
    }
    if (!pathAbsent) {
      Log.i("[$id] skipped managed $name mutation because the PATH runtime is authoritative");
      yield ProvisionFailed(
        message: "The global $name runtime now takes precedence. Retry setup detection instead.",
      );
      return;
    }
    _throwIfAborted(startAborted: startAborted);

    final RuntimeVersion bundled = _manifest.bundledVersion;
    final String managedDir = p.join(stateDirectory, id);

    bool keepUntilInstalled({required String versionName}) {
      final RuntimeVersion? version = _manifest.parseInstalledVersion(value: versionName);
      // Not a managed version directory (installer staging, stray names): the
      // post-install sweep owns those.
      if (version == null) return true;
      return version.compareTo(_manifest.minPathVersion) >= 0;
    }

    bool keepAfterInstall({required String versionName}) {
      if (versionName == bundled.raw) return true;
      // A generation started before this install may still be running from a
      // supported older version; leave its directory for a later install to
      // reclaim rather than deleting the executable out from under it.
      if (!runtimeInUse.isInUse) return false;
      return keepUntilInstalled(versionName: versionName);
    }

    // Obsolete versions are unselectable whether or not this install succeeds,
    // so they go before any bandwidth is spent.
    await _cleaner.sweep(managedDir: managedDir, keep: keepUntilInstalled);

    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error) {
      // Surfaced (and rendered) via ProvisionFailed — no separate upfront log.
      yield ProvisionFailed(
        message: "Could not determine this machine's platform for the $name runtime (${error.toString()}).",
      );
      return;
    }
    final RuntimeAsset? asset;
    try {
      asset = await _assetResolver(target: target);
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _throwIfAborted(startAborted: startAborted);
      Log.w("[$id] managed $name runtime asset resolution failed", error, stackTrace);
      yield ProvisionFailed(
        message: "Could not select the $name runtime for this machine. Check the bridge logs for details.",
      );
      return;
    }
    _throwIfAborted(startAborted: startAborted);
    if (asset == null) {
      yield ProvisionFailed(
        message: "$name has no managed runtime for this platform (${target.key}).",
      );
      return;
    }

    final String versionDir = p.join(managedDir, bundled.raw);
    final String binaryPath = p.join(versionDir, _manifest.binaryFileName);

    if (_installService.isInstalled(
      versionDir: versionDir,
      binaryFileName: _manifest.binaryFileName,
      sha256: asset.sha256,
    )) {
      // Cached candidates use the same disposable private validation context
      // as downloads; a broken cached copy falls through to a reinstall.
      final bool cachedValid;
      try {
        cachedValid = await _installService.validateCachedCandidate(
          managedDir: managedDir,
          executablePath: binaryPath,
          environment: environment,
          startAborted: startAborted,
        );
      } on PluginStartAbortedException {
        rethrow;
      } on Object catch (error, stackTrace) {
        Log.w("[$id] cached managed $name runtime validation failed", error, stackTrace);
        yield ProvisionFailed(
          message: "Could not validate the installed $name runtime. Check the bridge logs for details.",
        );
        return;
      }
      _throwIfAborted(startAborted: startAborted);
      if (cachedValid) {
        Log.i("[$id] managed $name ${bundled.toString()} already installed");
        // Sweep before the terminal event: consumers may stop listening as
        // soon as ProvisionReady arrives, which would cancel this stream and
        // leave superseded version directories behind.
        await _cleaner.sweep(managedDir: managedDir, keep: keepAfterInstall);
        yield ProvisionReady(binaryPath: binaryPath);
        return;
      }
      Log.w("[$id] cached managed runtime at '$binaryPath' failed candidate validation; reinstalling");
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
        environment: environment,
        startAborted: startAborted,
      )) {
        yield event;
      }
    } on PluginStartAbortedException {
      rethrow;
    } on RuntimeInstallException catch (error, stackTrace) {
      // The wire message must stay sanitized (install errors can carry local
      // paths and raw command output), so only the local log keeps the detail.
      Log.w("[$id] managed $name runtime install failed", error, stackTrace);
      final String message = switch (error.kind) {
        RuntimeInstallFailureKind.candidateValidation =>
          "The downloaded $name runtime is not runnable on this machine "
              "(expected '${bundled.toString()}').",
        RuntimeInstallFailureKind.general => "Could not install the $name runtime. Check the bridge logs for details.",
      };
      yield ProvisionFailed(message: message);
      return;
    } on Object catch (error, stackTrace) {
      Log.w("[$id] managed $name runtime install failed", error, stackTrace);
      yield ProvisionFailed(
        message: "Could not install the $name runtime. Check the bridge logs for details.",
      );
      return;
    }

    Log.i("[$id] installed managed $name ${bundled.toString()}");
    // Sweep before the terminal event: consumers may stop listening as soon as
    // ProvisionReady arrives, which would cancel this stream mid-sweep.
    await _cleaner.sweep(managedDir: managedDir, keep: keepAfterInstall);
    yield ProvisionReady(binaryPath: binaryPath);
  }

  void _throwIfAborted({required StartAbortSignal startAborted}) {
    if (startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
  }
}
