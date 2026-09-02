/// The one owner of the sub-agent session id rule: a sub-agent is addressed by
/// its transcript stem `agent-<agentId>`, live and persisted alike.
abstract final class ClaudeSubagentSessionId() {
  static const String _prefix = "agent-";

  static String fromAgentId(String agentId) => "$_prefix$agentId";

  /// The `agentId` inside a sub-agent session id, or null for a root id.
  static String? agentIdOf(String sessionId) =>
      sessionId.length > _prefix.length && sessionId.startsWith(_prefix) ? sessionId.substring(_prefix.length) : null;
}
