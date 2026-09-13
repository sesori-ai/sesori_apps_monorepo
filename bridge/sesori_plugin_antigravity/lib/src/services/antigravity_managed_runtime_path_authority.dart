import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show HostExecutablePresence, IoHostExecutableLocator, PlatformTarget;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginStartAbortedException, StartAbortSignal;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show ManagedRuntimePathAuthority;

import "../foundation/antigravity_release.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../repositories/antigravity_runtime_repository.dart";
import "antigravity_runtime_path_authority_calculator.dart";

/// Pair-aware PATH authority for Antigravity managed-runtime mutation.
class AntigravityManagedRuntimePathAuthority({
  required final AntigravityRuntimeRepository _runtimeRepository,
  required final AntigravityRuntimePathAuthorityCalculator _pathAuthorityCalculator,
  required final IoHostExecutableLocator _executableLocator,
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
    if (candidate case AntigravityRuntimeCandidateStorageFailed(:final cause, :final stackTrace)) {
      Log.w("[antigravity] PATH authority inspection failed", cause, stackTrace);
    }
    final serverPresence = AntigravityRelease.supportsTarget(target: _target)
        ? _executableLocator.locate(
            executable: AntigravityRelease.serverFileName(target: _target),
            environment: environment,
            workingDirectory: null,
          )
        : HostExecutablePresence.unknown;
    _throwIfAborted(abortSignal: abortSignal);
    return _pathAuthorityCalculator.provesServerAbsent(
      candidate: candidate,
      serverPresence: serverPresence,
    );
  }

  void _throwIfAborted({required StartAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
