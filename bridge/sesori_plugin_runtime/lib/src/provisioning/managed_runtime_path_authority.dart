import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginStartAbortedException, StartAbortSignal;

import "runtime_manifest.dart";
import "runtime_version_validator.dart";

/// Revalidates whether managed-runtime mutation may proceed.
///
/// Implementations must return true only when the ordinary PATH runtime is
/// genuinely absent. Every other result keeps PATH authoritative.
abstract interface class ManagedRuntimePathAuthority() {
  Future<bool> isPathAbsent({
    required Map<String, String> environment,
    required StartAbortSignal abortSignal,
  });
}

/// PATH authority backed by a bounded `<runtime> --version` probe.
class RuntimeVersionManagedRuntimePathAuthority({
  required final RuntimeManifest _manifest,
  required final RuntimeVersionValidator _versionValidator,
}) implements ManagedRuntimePathAuthority {
  @override
  Future<bool> isPathAbsent({
    required Map<String, String> environment,
    required StartAbortSignal abortSignal,
  }) async {
    _throwIfAborted(abortSignal: abortSignal);
    final outcome = await _versionValidator.probe(
      executable: _manifest.pathExecutableName,
      environment: environment,
    );
    _throwIfAborted(abortSignal: abortSignal);
    return outcome is RuntimeProbeMissing;
  }

  void _throwIfAborted({required StartAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
