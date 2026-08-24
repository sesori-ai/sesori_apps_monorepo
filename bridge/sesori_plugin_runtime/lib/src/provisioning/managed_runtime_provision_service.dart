import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginHost,
        PluginStartAbortedException,
        ProvisionFailed,
        ProvisionNotice,
        ProvisionReady,
        ProvisionResolving,
        RuntimeProvisionProgress;

import "managed_runtime_selection_service.dart";
import "runtime_manifest.dart";

/// Resolves an already-installed runtime without downloading or mutating it.
///
/// Precedence is a sufficiently recent PATH runtime, then the first
/// sufficiently recent fallback executable candidate (e.g. a CLI bundled by a
/// backend's desktop app, enumerated by the owning plugin), then the pinned
/// managed runtime when that exact version is already present and runnable.
class ManagedRuntimeProvisionService({
  required final RuntimeManifest _manifest,
  required final ManagedRuntimeSelectionService _selectionService,

  /// Absolute executable paths probed after PATH, in preference order. Each is
  /// version-gated like a PATH install; a missing path fails its probe
  /// harmlessly.
  required final List<String> _fallbackExecutableCandidates,
}) {
  Stream<RuntimeProvisionProgress> provision({required PluginHost host, required String? explicitExecutablePath}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    yield const ProvisionResolving();

    final id = _manifest.runtimeId;
    final name = _manifest.displayName;
    final minimum = _manifest.minPathVersion;
    final bundled = _manifest.bundledVersion;
    final selection = await _selectionService.select(
      explicitExecutablePath: explicitExecutablePath,
      fallbackExecutableCandidates: _fallbackExecutableCandidates,
      environment: host.environment,
      stateDirectory: host.stateDirectory,
      abortSignal: host.startAborted,
      managedVersionPolicy: ManagedRuntimeVersionPolicy.exact,
    );
    if (selection case ManagedRuntimeSelected(
      :final binaryPath,
      :final source,
      :final version,
    )) {
      if (selection case ManagedRuntimeManagedSelected(:final rejectedPathVersion) when rejectedPathVersion != null) {
        yield ProvisionNotice(
          message:
              "Installed $name ${rejectedPathVersion.toString()} is older than the minimum supported ${minimum.toString()}; "
              "using the existing managed $name ${bundled.toString()} instead.",
        );
      }
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
