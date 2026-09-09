import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "antigravity_runtime_pair.dart";

enum AntigravityRuntimeSource() {
  explicit,
  path,
  managed,
}

enum AntigravityRuntimePairIssue() {
  wrongName,
  notAFile,
  notSiblings,
  notDistinct,
}

enum AntigravityRuntimeContractViolation() {
  protocolVersion,
  agentName,
  agentVersion,
  loadSession,
  listSessions,
  resumeSession,
  closeSession,
  authLogout,
  personalOauth,
}

/// Layer-2 domain projection of an ACP initialize response.
final class AntigravityRuntimeProbeSnapshot({
  required final int? protocolVersion,
  required final String? agentName,
  required final String? agentVersion,
  required final bool loadsSessions,
  required final bool listsSessions,
  required final bool resumesSessions,
  required final bool closesSessions,
  required final bool logsOutAuthentication,
  required Set<String> authenticationMethodIds,
}) {
  final Set<String> authenticationMethodIds = Set<String>.unmodifiable(authenticationMethodIds);
}

/// Exact validated contract retained with a selected pair.
final class const AntigravityRuntimeContract({
  required final String version,
  required final bool listsSessions,
  required final bool closesSessions,
});

sealed class const AntigravityRuntimeCandidateResult();

final class const AntigravityRuntimeCandidateFound({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
}) extends AntigravityRuntimeCandidateResult;

final class const AntigravityRuntimeCandidateMissing({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimeComponent component,
}) extends AntigravityRuntimeCandidateResult;

final class const AntigravityRuntimeCandidateRejected({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimeComponent component,
  required final AntigravityRuntimePairIssue issue,
}) extends AntigravityRuntimeCandidateResult;

final class const AntigravityRuntimeCandidateStorageFailed({
  required final AntigravityRuntimeSource source,
  // ignore: no_slop_linter/prefer_specific_type, caught storage failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeCandidateResult;

final class const AntigravityRuntimeCandidateUnsupported({required final PlatformTarget target})
    extends AntigravityRuntimeCandidateResult;

sealed class const AntigravityRuntimeProbeResult();

final class const AntigravityRuntimeProbeCompleted({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
  required final AntigravityRuntimeProbeSnapshot snapshot,
}) extends AntigravityRuntimeProbeResult;

final class const AntigravityRuntimeProbeBoundaryFailed({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
  // ignore: no_slop_linter/prefer_specific_type, caught probe failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeProbeResult;

sealed class const AntigravityRuntimeResolution();

final class const AntigravityRuntimeSelected({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
  required final AntigravityRuntimeContract contract,
}) extends AntigravityRuntimeResolution;

final class const AntigravityRuntimeMissing({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimeComponent component,
}) extends AntigravityRuntimeResolution;

final class const AntigravityRuntimePairRejected({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimeComponent component,
  required final AntigravityRuntimePairIssue issue,
}) extends AntigravityRuntimeResolution;

final class AntigravityRuntimeContractRejected({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
  required List<AntigravityRuntimeContractViolation> violations,
}) extends AntigravityRuntimeResolution {
  final List<AntigravityRuntimeContractViolation> violations = List<AntigravityRuntimeContractViolation>.unmodifiable(
    violations,
  );
}

final class const AntigravityRuntimeProbeFailed({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimePair pair,
  // ignore: no_slop_linter/prefer_specific_type, caught probe failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeResolution;

final class const AntigravityRuntimeStorageFailed({
  required final AntigravityRuntimeSource source,
  // ignore: no_slop_linter/prefer_specific_type, caught storage failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeResolution;

final class const AntigravityRuntimeUnsupported({required final PlatformTarget target})
    extends AntigravityRuntimeResolution;
