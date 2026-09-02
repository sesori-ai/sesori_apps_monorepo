import "package:sesori_shared/sesori_shared.dart";

/// What a stop request came back with.
sealed class const SessionAbortOutcome() {
  const factory aborted() = SessionAbortAccepted;
  const factory rejected({required SessionAbortRejection rejection}) = SessionAbortRejected;
}

/// The bridge accepted the stop (or the attempt failed and was logged; the
/// caller has nothing further to decide either way).
final class const SessionAbortAccepted() extends SessionAbortOutcome;

/// A `confirm` stop refused because sub-agents run; the user must choose.
final class const SessionAbortRejected({required final SessionAbortRejection rejection}) extends SessionAbortOutcome;
