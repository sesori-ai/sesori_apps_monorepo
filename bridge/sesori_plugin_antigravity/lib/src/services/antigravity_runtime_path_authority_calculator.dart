import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";

/// Owns the pair-aware decision that permits managed Antigravity fallback.
class const AntigravityRuntimePathAuthorityCalculator() {
  bool provesServerAbsent({required AntigravityRuntimeCandidateResult candidate}) => switch (candidate) {
    AntigravityRuntimeCandidateMissing(
      source: AntigravityRuntimeSource.path,
      component: AntigravityRuntimeComponent.server,
    ) =>
      true,
    AntigravityRuntimeCandidateResult() => false,
  };
}
