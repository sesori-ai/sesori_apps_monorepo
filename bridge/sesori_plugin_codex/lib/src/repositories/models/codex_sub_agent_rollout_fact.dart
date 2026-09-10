/// Repository-owned facts projected from Codex rollout records.
sealed class const CodexSubAgentRolloutFact();

/// Exact delegated input from one parent-local `spawn_agent` call.
final class const CodexSubAgentSpawnFact({
  required final String callId,
  required final String agent,
  required final String message,
}) extends CodexSubAgentRolloutFact;

/// Persisted child identity for a completed `SubAgentActivity` start item.
final class const CodexSubAgentStartedActivityFact({
  required final String callId,
  required final String childThreadId,
  required final String agentPath,
}) extends CodexSubAgentRolloutFact;

/// Initial child input associated with its owning child turn.
final class const CodexSubAgentInitialInputFact({
  required final String turnId,
  required final CodexSubAgentInitialInput input,
}) extends CodexSubAgentRolloutFact;

sealed class const CodexSubAgentInitialInput();

/// Genuine child-owned plaintext from a complete native `NEW_TASK` envelope.
final class const CodexSubAgentPlaintextInput({required final String message}) extends CodexSubAgentInitialInput;

/// Native input contains opaque encrypted content and cannot be projected.
final class const CodexSubAgentEncryptedInput() extends CodexSubAgentInitialInput;
