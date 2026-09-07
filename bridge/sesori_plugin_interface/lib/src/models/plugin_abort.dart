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

/// Whether the plugin completed the requested descendant-stop policy.
sealed class const PluginAbortSubAgentCoverage();

/// Native/plugin authority covered every descendant in the request scope.
final class const PluginAbortSubAgentsHandled() extends PluginAbortSubAgentCoverage;

/// Exact known descendants remain outside plugin/native stop authority.
///
/// The repository derives handled ids from its request-time catalog snapshot,
/// so handled and unhandled sets cannot overlap inside the plugin result.
final class const PluginAbortSubAgentsPartiallyHandled({
  required final List<String> unhandledSessionIds,
}) extends PluginAbortSubAgentCoverage;

/// The plugin cannot authoritatively classify descendant coverage.
///
/// The client retains its legacy visible-child fanout for this result.
final class const PluginAbortSubAgentsLegacyFanout() extends PluginAbortSubAgentCoverage;

/// The stop was performed. [workKept] is true only when resident work (running
/// sub-agents) was deliberately left alive, so the caller knows the session
/// will still finish something later. [subAgentCoverage] makes full, partial,
/// and legacy coverage mutually exclusive.
final class const PluginAbortAccepted({
  required final bool workKept,
  required final PluginAbortSubAgentCoverage subAgentCoverage,
}) extends PluginAbortResult;

/// A `confirm` stop refused because sub-agents are running.
final class const PluginAbortRejectedSubAgentsRunning({
  required final int runningSubAgentCount,
  required final bool mainAgentRunning,

  /// Whether the plugin can interrupt a running main agent while leaving its
  /// sub-agents alive (`keep`). Claude cannot: its interrupt stops both.
  required final bool mainAgentOnlySupported,
}) extends PluginAbortResult;
