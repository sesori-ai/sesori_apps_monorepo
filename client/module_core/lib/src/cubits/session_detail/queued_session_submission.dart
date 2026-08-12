import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";

sealed class QueuedSessionSubmission {
  const QueuedSessionSubmission();

  const factory QueuedSessionSubmission.text({
    required String text,
    required ComposerInputMode inputMode,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required AgentModel? agentModel,
  }) = QueuedTextSubmission;

  const factory QueuedSessionSubmission.command({
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

final class QueuedTextSubmission extends QueuedSessionSubmission {
  @override
  final String text;
  @override
  final ComposerInputMode inputMode;
  @override
  final List<ComposerAttachment> attachments;
  @override
  final String? agent;
  @override
  final AgentModel? agentModel;

  const QueuedTextSubmission({
    required this.text,
    required this.inputMode,
    required this.attachments,
    required this.agent,
    required this.agentModel,
  });

  @override
  String? get command => null;
}

final class QueuedCommandSubmission extends QueuedSessionSubmission {
  @override
  final String text;
  @override
  final String command;
  @override
  final String? agent;
  @override
  final AgentModel? agentModel;

  const QueuedCommandSubmission({
    required this.text,
    required this.command,
    required this.agent,
    required this.agentModel,
  });

  @override
  ComposerInputMode get inputMode => ComposerInputMode.typed;

  /// The bridge's command paths carry only the text part, so a queued command
  /// can never hold images. Keeping that off the variant means a command
  /// submission cannot silently strip attachments on its way to the bridge.
  @override
  List<ComposerAttachment> get attachments => const [];
}
