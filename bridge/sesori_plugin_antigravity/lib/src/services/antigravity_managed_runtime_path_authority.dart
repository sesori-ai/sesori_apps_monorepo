import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformTarget;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginStartAbortedException, StartAbortSignal;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show ManagedRuntimePathAuthority;

import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../repositories/antigravity_runtime_repository.dart";

/// Pair-aware PATH authority for Antigravity managed-runtime mutation.
class AntigravityManagedRuntimePathAuthority({
  required final AntigravityRuntimeRepository _runtimeRepository,
  required final PlatformTarget _target,
}) implements ManagedRuntimePathAuthority {
  @override
  Future<bool> isPathAbsent({
    required Map<String, String> environment,
    required StartAbortSignal abortSignal,
  }) async {
    _throwIfAborted(abortSignal: abortSignal);
    final candidate = _runtimeRepository.inspectPath(environment: environment, target: _target);
    _throwIfAborted(abortSignal: abortSignal);
    switch (candidate) {
      case AntigravityRuntimeCandidateMissing(component: AntigravityRuntimeComponent.server):
        return true;
      case AntigravityRuntimeCandidateStorageFailed(:final cause, :final stackTrace):
        Log.w("[antigravity] PATH authority inspection failed", cause, stackTrace);
        return false;
      case AntigravityRuntimeCandidateFound() ||
          AntigravityRuntimeCandidateMissing() ||
          AntigravityRuntimeCandidateRejected() ||
          AntigravityRuntimeCandidateUnsupported():
        return false;
    }
  }

  void _throwIfAborted({required StartAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
