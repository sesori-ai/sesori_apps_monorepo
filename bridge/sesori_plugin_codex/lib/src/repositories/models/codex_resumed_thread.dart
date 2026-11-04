import "codex_thread_record.dart";

/// A thread `thread/resume` subscribed this connection to.
class const CodexResumedThread({
  required final CodexThreadRecord thread,

  /// The turn Codex is still running on the thread; null when it is idle.
  required final String? runningTurnId,
});
