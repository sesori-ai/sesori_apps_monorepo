/// One native scoped-stop authority selected by the generic ACP plugin.
sealed class const AcpScopedStopTarget();

/// Stops a session and the native descendants it owns.
final class const AcpScopedStopSessionTarget({required final String sessionId}) extends AcpScopedStopTarget;

/// Stops one retained delegated child through its exact direct parent.
final class const AcpScopedStopChildTarget({
  required final String parentSessionId,
  required final String childSessionId,
}) extends AcpScopedStopTarget;

/// The native adapter's accepted scoped-stop outcome.
final class const AcpScopedStopResult({required final bool workKept});
