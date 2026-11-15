/// Where a rewind before a user prompt resumes the conversation.
sealed class const ClaudeRewindPoint();

/// The chain entry to resume at: the parent of the edited prompt.
final class const ClaudeRewindEntry({required final String entryUuid}) extends ClaudeRewindPoint;

/// The prompt has no entry Claude Code can resume at.
final class const ClaudeRewindUnavailable({required final ClaudeRewindRefusal reason}) extends ClaudeRewindPoint;

enum ClaudeRewindRefusal() {
  /// The prompt is not on the transcript's active branch, or not a prompt.
  notOnActiveBranch,

  /// The prompt opens the conversation, so nothing comes before it.
  firstMessage,

  /// A later compaction replaced the prompt with its summary: Claude Code
  /// resumes only from the latest compaction on, and refuses an earlier entry
  /// with `No message found` (verified live on 2.1.322).
  beforeCompaction,
}

/// The installed Claude Code does not support resuming at a chain entry.
final class const ClaudeRewindUnsupportedException({required final Object innerError}) implements Exception {
  @override
  String toString() => "ClaudeRewindUnsupportedException($innerError)";
}
