import "package:sesori_auth/sesori_auth.dart";

/// How the bridge answered an edit and resend.
sealed class const SessionRewindResult();

/// The bridge removed the message and what followed it, and sent the edit.
final class const SessionRewindAccepted() extends SessionRewindResult;

/// The session is running a turn, so it must stop before the edit.
final class const SessionRewindBusy() extends SessionRewindResult;

/// The message cannot be edited. [reason] is the harness's explanation,
/// safe to show, or null when it gave none.
final class const SessionRewindUnavailable({required final String? reason}) extends SessionRewindResult;

/// The edit named an agent, model or variant the harness no longer offers.
final class const SessionRewindOptionsChanged() extends SessionRewindResult;

/// The bridge refused the edit and nothing changed. [reason] is the plugin's
/// explanation, safe to show, or null when it gave none.
final class const SessionRewindRejected({required final String? reason}) extends SessionRewindResult;

/// The answer never arrived or proves nothing, so the edit may have run. A
/// retry with the same prompt id is safe: the bridge does not rewind twice.
final class const SessionRewindFailed({required final ApiError error}) extends SessionRewindResult;
