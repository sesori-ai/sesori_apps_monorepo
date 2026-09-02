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

sealed class const PluginAbortResult();

final class const PluginAbortAccepted() extends PluginAbortResult;

/// A `confirm` stop refused because sub-agents are running.
final class const PluginAbortRejectedSubAgentsRunning({
  required final int runningSubAgentCount,
  required final bool mainAgentRunning,
}) extends PluginAbortResult;
