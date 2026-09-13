import "antigravity_runtime_resolution.dart";

sealed class const AntigravityRuntimeVersionProbeResult();

final class const AntigravityRuntimeVersionProbeSucceeded({
  required final AntigravityRuntimeSource source,
  required final String version,
}) extends AntigravityRuntimeVersionProbeResult;

final class const AntigravityRuntimeVersionProbeRejected({
  required final AntigravityRuntimeSource source,
  required final int exitCode,
}) extends AntigravityRuntimeVersionProbeResult;

final class const AntigravityRuntimeVersionProbeFailed({required final AntigravityRuntimeSource source})
    extends AntigravityRuntimeVersionProbeResult;
