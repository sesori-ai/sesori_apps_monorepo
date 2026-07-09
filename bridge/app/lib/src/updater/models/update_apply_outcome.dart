/// The result of [UpdateApplyService.apply]: what happened during the in-place
/// swap, returned as data for the caller to present.
///
/// Persistence (the durable [UpdateAttempt] and the append-only update log) is
/// handled inside the service. This type carries only what a caller needs to
/// message the user and decide flow — the apply service itself never writes to
/// `Console`.
sealed class UpdateApplyOutcome {
  const UpdateApplyOutcome();
}

/// The staged release was swapped in and is pending activation on next launch.
///
/// [durablyRecorded] is true only when ALL post-swap bookkeeping succeeded: the
/// durable `appliedPendingActivation` record was written AND the managed-runtime
/// manifest names [version]. A false value means at least one of those writes
/// failed — the manifest may be stale, or the activation record may have been
/// cleared — so the post-swap state is not fully persisted and a chained
/// in-session apply must not proceed.
final class UpdateApplied extends UpdateApplyOutcome {
  final String version;
  final bool durablyRecorded;

  const UpdateApplied({required this.version, required this.durablyRecorded});
}

/// Another process holds the update lock; the swap was skipped (benign).
final class UpdateApplyLockBusy extends UpdateApplyOutcome {
  const UpdateApplyLockBusy();
}

/// The swap failed. [reason] is a human-readable cause; [logPath] points at the
/// durable update log with full detail.
final class UpdateApplyFailed extends UpdateApplyOutcome {
  final String reason;
  final String logPath;

  const UpdateApplyFailed({required this.reason, required this.logPath});
}
