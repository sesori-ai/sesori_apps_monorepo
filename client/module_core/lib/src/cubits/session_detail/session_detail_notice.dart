/// One-shot outcomes the session-detail shell should surface to the user.
enum SessionDetailNotice() {
  /// A send used stale agent/model/variant data; fresh options were applied and
  /// the queued submission is being retried automatically.
  promptOptionsUpdated,

  /// Fresh options could not be applied, or the corrected selection was still
  /// rejected; the submission remains queued.
  promptOptionsRecoveryFailed,
}
