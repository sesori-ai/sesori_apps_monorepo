import "package:sesori_shared/sesori_shared.dart";

/// A stored task: the user's definition plus the state the bridge owns.
final class const ScheduledTaskRecord({
  required final String id,
  required final ScheduledTaskDefinition definition,
  required final bool enabled,

  /// The shell command each run runs before its prompt; null for none.
  required final String? command,

  /// Null while paused or done.
  required final DateTime? nextDueAt,

  /// The session a same-session task continues; null until its first run.
  required final String? targetSessionId,

  /// When a one-off task ran.
  required final DateTime? completedAt,
  required final DateTime updatedAt,
});
