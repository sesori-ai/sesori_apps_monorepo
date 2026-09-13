import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginHost,
        PluginStartAbortedException,
        ProvisionFailed,
        ProvisionReady,
        ProvisionResolving,
        RuntimeProvisionProgress;

import "managed_runtime_selection_service.dart";
import "runtime_manifest.dart";

/// Resolves an already-installed runtime without downloading or mutating it.
///
/// PATH is authoritative whenever its command exists. A supported PATH runtime
/// is selected; an outdated or otherwise unusable PATH runtime blocks startup.
/// Only when PATH is absent does selection continue to fallback candidates and
/// then the newest supported managed runtime, preferring the pinned version.
class ManagedRuntimeProvisionService({
  required final RuntimeManifest _manifest,
  required final ManagedRuntimeSelectionService _selectionService,

  /// Absolute executable paths probed after PATH, in preference order. Each is
  /// version-gated like a PATH install; a missing path fails its probe
  /// harmlessly.
  required final List<String> _fallbackExecutableCandidates,
}) {
  Stream<RuntimeProvisionProgress> provision({
    required PluginHost host,
    required String? explicitExecutablePath,
  }) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    yield const ProvisionResolving();

    final id = _manifest.runtimeId;
    final name = _manifest.displayName;
    final selection = await _selectionService.select(
      explicitExecutablePath: explicitExecutablePath,
      fallbackExecutableCandidates: _fallbackExecutableCandidates,
      environment: host.environment,
      stateDirectory: host.stateDirectory,
      abortSignal: host.startAborted,
    );
    if (selection case ManagedRuntimeSelected(
      :final binaryPath,
      :final source,
      :final version,
    )) {
      Log.i("[$id] using ${source.name} $name ${version.toString()}");
      yield ProvisionReady(binaryPath: binaryPath);
      return;
    }

    yield ProvisionFailed(
      message:
          "No usable existing $name runtime was found. Install $name locally and retry: ${_manifest.installDocsUrl}",
    );
  }
}
