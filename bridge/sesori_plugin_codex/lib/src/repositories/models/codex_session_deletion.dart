/// The outcome of deleting a session's rollouts.
enum CodexSessionDeletion() {
  deleted,

  /// Rollouts another thread's history builds on, such as a fork's base,
  /// were kept; the rest are gone.
  keptForForks,

  /// The rollouts' absence could not be confirmed, or a write failed.
  failed,
}
