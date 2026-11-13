import "package:meta/meta.dart";

/// How a prompt send failed, as far as this client can tell.
@immutable
sealed class const PromptSendFailure() {
  /// The bridge answered with a client error, so the prompt did not run and
  /// the user may remove it. [reason] is the harness's explanation, written
  /// for the user, when it gave one.
  const factory rejected({required String? reason}) = RejectedPromptSend;

  /// A server error, timeout or lost response. The prompt may already have
  /// been accepted, so only a same-id Retry is safe.
  const factory uncertain() = UncertainPromptSend;
}

final class const RejectedPromptSend({required final String? reason}) extends PromptSendFailure {
  @override
  bool operator ==(Object other) => other is RejectedPromptSend && other.reason == reason;

  @override
  int get hashCode => Object.hash(runtimeType, reason);
}

final class const UncertainPromptSend() extends PromptSendFailure {
  @override
  bool operator ==(Object other) => other is UncertainPromptSend;

  @override
  int get hashCode => runtimeType.hashCode;
}
