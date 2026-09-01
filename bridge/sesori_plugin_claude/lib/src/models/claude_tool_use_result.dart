/// The typed `tool_use_result` Claude Code attaches to a tool-result frame and
/// persists on the matching transcript record.
///
/// Every tool carries one; only the `Agent` shapes are modelled because they
/// are the only ones a lifecycle decision depends on. Anything else is
/// [ClaudeToolUseResultUnknown], and a frame without the field is
/// [ClaudeToolUseResultAbsent].
sealed class const ClaudeToolUseResult() {
  static ClaudeToolUseResult parse(Object? raw) {
    if (raw == null) return const ClaudeToolUseResultAbsent();
    if (raw is! Map) return const ClaudeToolUseResultUnknown();
    final agentId = raw["agentId"];
    final knownAgentId = agentId is String && agentId.isNotEmpty ? agentId : null;
    return switch (raw["status"]) {
      "async_launched" when knownAgentId != null => ClaudeToolUseResultAsyncLaunched(agentId: knownAgentId),
      "completed" => ClaudeToolUseResultCompleted(agentId: knownAgentId),
      _ => const ClaudeToolUseResultUnknown(),
    };
  }
}

/// A background sub-agent was launched; its tool result is not its outcome.
final class const ClaudeToolUseResultAsyncLaunched({required final String agentId}) extends ClaudeToolUseResult;

/// A foreground sub-agent finished; the tool result carries its final report.
final class const ClaudeToolUseResultCompleted({required final String? agentId}) extends ClaudeToolUseResult;

final class const ClaudeToolUseResultAbsent() extends ClaudeToolUseResult;

final class const ClaudeToolUseResultUnknown() extends ClaudeToolUseResult;
