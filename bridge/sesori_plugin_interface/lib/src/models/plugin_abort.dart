/// What a stop should do about sub-agents the session is still running.
/// Plugins without sub-agents ignore it and stop as they always have.
enum PluginAbortSubAgentPolicy() {
  /// Refuse while sub-agents run, so the caller can confirm the scope.
  confirm,

  /// Interrupt the main agent only; running sub-agents keep going.
  keep,

  /// Interrupt the main agent and every running sub-agent.
  stop,
}

/// Why a plugin could not safely perform a requested stop.
enum PluginAbortRefusalReason() {
  residentWorkCompletionUnknown,
}

sealed class const PluginAbortResult();

/// The stop was performed. [workKept] is true only when resident work (running
/// sub-agents) was deliberately left alive, so the caller knows the session
/// will still finish something later.
final class const PluginAbortAccepted({
  required final bool workKept,
  required final bool subAgentsHandled,
}) extends PluginAbortResult;

/// A `confirm` stop refused because sub-agents are running.
final class const PluginAbortRejectedSubAgentsRunning({
  required final int runningSubAgentCount,
  required final bool mainAgentRunning,

  /// Whether the plugin can interrupt a running main agent while leaving its
  /// sub-agents alive (`keep`). Claude cannot: its interrupt stops both.
  required final bool mainAgentOnlySupported,
}) extends PluginAbortResult;

/// The stop was not attempted because the plugin cannot prove it is safe.
final class const PluginAbortNotPerformed({
  required final PluginAbortRefusalReason reason,
}) extends PluginAbortResult;
