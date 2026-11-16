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

/// An edit's Resend found the session running a turn. The shell offers to
/// stop it first; see `SessionDetailCubit.stopAndResendEdit`.
final class const SessionDetailEditBusy() extends SessionDetailNotice;

/// The bridge refused an edit and nothing changed. [reason] is the harness's
/// explanation, safe to show, or null when it gave none.
final class const SessionDetailEditRefused({required final String? reason}) extends SessionDetailNotice;

/// The edit named an agent, model or variant the harness no longer offers.
/// The options were refreshed; the edit waits for the user to resend.
final class const SessionDetailEditOptionsChanged() extends SessionDetailNotice;

/// The session did not stop, so the edit was not sent.
final class const SessionDetailEditStopFailed() extends SessionDetailNotice;

/// The bridge's answer never arrived, so the edit may or may not have run.
/// Resending is safe: the bridge never applies one edit twice.
final class const SessionDetailEditFailed() extends SessionDetailNotice;
