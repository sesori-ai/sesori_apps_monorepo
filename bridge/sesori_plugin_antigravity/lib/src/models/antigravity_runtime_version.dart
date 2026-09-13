import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "antigravity_runtime_resolution.dart";

sealed class const AntigravityRuntimeVersionProbeResult();

final class const AntigravityRuntimeVersionProbeCompleted({
  required final AntigravityRuntimeSource source,
  required final CommandResult command,
  required final String? version,
}) extends AntigravityRuntimeVersionProbeResult;

final class const AntigravityRuntimeVersionProbeFailed({
  required final AntigravityRuntimeSource source,
  // ignore: no_slop_linter/prefer_specific_type, caught process failures remain opaque
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeVersionProbeResult;
