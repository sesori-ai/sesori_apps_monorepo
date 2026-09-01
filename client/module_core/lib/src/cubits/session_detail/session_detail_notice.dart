/// One-shot outcomes the session-detail shell should surface to the user.
sealed class const SessionDetailNotice();

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
