import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";

/// Shared pair-aware rule for managed fallback and mutation.
class const AntigravityRuntimePathAuthorityCalculator() {
  bool provesServerAbsent({
    required AntigravityRuntimeCandidateResult candidate,
    required AntigravityPathServerPresence serverPresence,
  }) {
    if (candidate case AntigravityRuntimeCandidateMissing(
      source: AntigravityRuntimeSource.path,
      component: AntigravityRuntimeComponent.server,
    )) {
      return serverPresence == AntigravityPathServerPresence.absent;
    }
    return false;
  }
}
