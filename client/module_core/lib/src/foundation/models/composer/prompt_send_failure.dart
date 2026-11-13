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

  /// The bridge refused the session's own model, which the harness does not
  /// offer, so the prompt did not run and the user may remove it. Only the
  /// user picking another model fixes it, so Retry sends with their current
  /// pick.
  const factory modelUnavailable() = ModelUnavailablePromptSend;

  /// The bridge refused an option the prompt names (agent, model, variant,
  /// fast mode or command) as one it no longer offers, so the prompt did not
  /// run. Only launch follow-ups receive it, and they resend their stored
  /// options, so a retry would be refused again and Remove is the only action.
  const factory optionsChanged() = OptionsChangedPromptSend;

  /// Whether the bridge proved the prompt did not run, so removing it is safe.
  bool get provesNotRun => switch (this) {
    RejectedPromptSend() || ModelUnavailablePromptSend() || OptionsChangedPromptSend() => true,
    UncertainPromptSend() => false,
  };
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

final class const ModelUnavailablePromptSend() extends PromptSendFailure {
  @override
  bool operator ==(Object other) => other is ModelUnavailablePromptSend;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class const OptionsChangedPromptSend() extends PromptSendFailure {
  @override
  bool operator ==(Object other) => other is OptionsChangedPromptSend;

  @override
  int get hashCode => runtimeType.hashCode;
}
