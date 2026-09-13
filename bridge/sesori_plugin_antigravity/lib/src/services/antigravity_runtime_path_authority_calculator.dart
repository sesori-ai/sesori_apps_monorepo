import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../foundation/antigravity_release.dart";
import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";

/// Owns the pair-aware evidence required for managed Antigravity fallback.
class const AntigravityRuntimePathAuthorityCalculator({
  required final IoHostExecutableLocator _executableLocator,
}) {
  bool provesServerAbsent({
    required AntigravityRuntimeCandidateResult candidate,
    required Map<String, String> environment,
    required PlatformTarget target,
  }) {
    if (candidate case AntigravityRuntimeCandidateMissing(
      source: AntigravityRuntimeSource.path,
      component: AntigravityRuntimeComponent.server,
    )) {
      if (!AntigravityRelease.supportsTarget(target: target)) return false;
      return _executableLocator.locate(
            executable: AntigravityRelease.serverFileName(target: target),
            environment: environment,
            workingDirectory: null,
          ) ==
          HostExecutablePresence.absent;
    }
    return false;
  }
}
