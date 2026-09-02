import "package:sesori_shared/sesori_shared.dart";

/// What a stop request came back with.
sealed class const SessionAbortOutcome() {
  const factory aborted() = SessionAbortAccepted;
  const factory rejected({required SessionAbortRejection rejection}) = SessionAbortRejected;
  const factory failed() = SessionAbortFailed;
}

/// The bridge accepted the stop.
final class const SessionAbortAccepted() extends SessionAbortOutcome;

/// A `confirm` stop refused because sub-agents run; the user must choose.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortOutcome;

/// The stop request failed (transport or bridge error); already logged.
final class const SessionAbortFailed() extends SessionAbortOutcome;
