/// One-shot outcomes the session-detail shell should surface to the user.
sealed class const SessionDetailNotice();

/// Cancellation was refused or could not be confirmed by the bridge.
final class const SessionDetailQueueCancellationFailed() extends SessionDetailNotice;

/// A send used stale agent/model/variant data; fresh options were applied and
/// the queued submission is being retried automatically.
final class const SessionDetailPromptOptionsUpdated() extends SessionDetailNotice;

/// Fresh options could not be applied, or the corrected selection was still
/// rejected; the submission remains queued.
final class const SessionDetailPromptOptionsRecoveryFailed() extends SessionDetailNotice;

/// Fresh options could not be applied because this harness has no authenticated
/// provider/model available in the requested scope. [actionHint] is bounded,
/// privacy-safe presentation supplied by the plugin.
final class const SessionDetailAuthenticationRequired({required final String actionHint}) extends SessionDetailNotice;

/// A refreshed command catalog no longer contains the queued command. The
/// command remains visible but blocked until the user removes it.
final class const SessionDetailCommandUnavailable() extends SessionDetailNotice;

final class const SessionDetailAutoContinuationUnavailable() extends SessionDetailNotice;

final class const SessionDetailAutoContinuationUpdateFailed() extends SessionDetailNotice;

/// Disabling prevents future sends, but cannot retract an accepted prompt.
final class const SessionDetailAutoContinuationAlreadySubmitted() extends SessionDetailNotice;

/// The bridge did not acknowledge a change to the session's approval mode.
final class const SessionDetailApprovalUpdateFailed() extends SessionDetailNotice;
