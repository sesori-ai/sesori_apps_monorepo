import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";

sealed class const QueuedSessionSubmission() {
  const factory text({
    required String text,
    required ComposerInputMode inputMode,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required AgentModel? agentModel,
  }) = QueuedTextSubmission;

  const factory command({
    required String text,
    required String command,
    required String? agent,
    required AgentModel? agentModel,
  }) = QueuedCommandSubmission;

  String get text;
  String? get command;
  ComposerInputMode get inputMode;
  List<ComposerAttachment> get attachments;
  String? get agent;
  AgentModel? get agentModel;

  /// What the queued bubble should render, or `null` when the submission
  /// carries no text of its own — an attachment-only prompt. Callers decide
  /// what to show in its place rather than reading an empty string as absence.
  String? get displayText => command != null
      ? text.trim().isEmpty
            ? "/$command"
            : "/$command ${text.trim()}"
      : text.isEmpty
      ? null
      : text;

  bool get isCommand => command != null;
}

final class const QueuedTextSubmission({
  @override required final String text,
  @override required final ComposerInputMode inputMode,
  @override required final List<ComposerAttachment> attachments,
  @override required final String? agent,
  @override required final AgentModel? agentModel,
}) extends QueuedSessionSubmission {
  @override
  String? get command => null;
}

final class const QueuedCommandSubmission({
  @override required final String text,
  @override required final String command,
  @override required final String? agent,
  @override required final AgentModel? agentModel,
}) extends QueuedSessionSubmission {
  @override
  ComposerInputMode get inputMode => ComposerInputMode.typed;

  /// The bridge's command paths carry only the text part, so a queued command
  /// can never hold images. Keeping that off the variant means a command
  /// submission cannot silently strip attachments on its way to the bridge.
  @override
  List<ComposerAttachment> get attachments => const [];
}
