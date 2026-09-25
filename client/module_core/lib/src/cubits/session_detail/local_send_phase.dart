import "package:meta/meta.dart";

import "queued_session_submission.dart";

/// How a failed send ended.
enum LocalSendFailure() {
  /// The bridge answered with a rejection, so the prompt did not run and the
  /// user may remove it.
  rejected,

  /// The request timed out or its response was lost. The bridge may already
  /// have accepted the prompt, so only a same-id Retry is safe.
  uncertain,
}

/// The head of this surface's local send queue: idle, in flight, or failed.
@immutable
sealed class const LocalSendPhase() {
  const factory idle() = LocalSendIdle;
  const factory sending({required QueuedSessionSubmission submission}) = LocalSendSending;
  const factory failed({required QueuedSessionSubmission submission, required LocalSendFailure failure}) =
      LocalSendFailed;
}

final class const LocalSendIdle() extends LocalSendPhase {
  @override
  bool operator ==(Object other) => other is LocalSendIdle;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class const LocalSendSending({required final QueuedSessionSubmission submission}) extends LocalSendPhase {
  @override
  bool operator ==(Object other) => other is LocalSendSending && identical(other.submission, submission);

  @override
  int get hashCode => identityHashCode(submission);
}

final class const LocalSendFailed({
  required final QueuedSessionSubmission submission,
  required final LocalSendFailure failure,
}) extends LocalSendPhase {
  @override
  bool operator ==(Object other) =>
      other is LocalSendFailed && identical(other.submission, submission) && other.failure == failure;

  @override
  int get hashCode => Object.hash(identityHashCode(submission), failure);
}
