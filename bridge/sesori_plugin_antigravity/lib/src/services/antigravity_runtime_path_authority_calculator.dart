import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show HostExecutablePresence;

import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";

/// Owns the pair-aware decision that permits managed Antigravity fallback.
class const AntigravityRuntimePathAuthorityCalculator() {
  bool requiresPhysicalServerAbsence({required AntigravityRuntimeCandidateResult candidate}) =>
      candidate is AntigravityRuntimeCandidateMissing &&
      candidate.source == AntigravityRuntimeSource.path &&
      candidate.component == AntigravityRuntimeComponent.server;

  bool provesServerAbsent({
    required AntigravityRuntimeCandidateResult candidate,
    required HostExecutablePresence serverPresence,
  }) => requiresPhysicalServerAbsence(candidate: candidate) && serverPresence == HostExecutablePresence.absent;
}
