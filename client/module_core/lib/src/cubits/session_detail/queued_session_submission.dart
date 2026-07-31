import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";

sealed class QueuedSessionSubmission {
  const QueuedSessionSubmission();

  const factory QueuedSessionSubmission.text({
    required String text,
    required ComposerInputMode inputMode,
    required List<ComposerAttachment> attachments,
  }) = QueuedTextSubmission;

  const factory QueuedSessionSubmission.command({
    required String text,
    required String command,
    required List<ComposerAttachment> attachments,
  }) = QueuedCommandSubmission;

  String get text;
  String? get command;
  ComposerInputMode get inputMode;
  List<ComposerAttachment> get attachments;

  String get displayText => command != null
      ? text.trim().isEmpty
            ? "/$command"
            : "/$command ${text.trim()}"
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

  const QueuedTextSubmission({
    required this.text,
    required this.inputMode,
    required this.attachments,
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
  final List<ComposerAttachment> attachments;

  const QueuedCommandSubmission({
    required this.text,
    required this.command,
    required this.attachments,
  });

  @override
  ComposerInputMode get inputMode => ComposerInputMode.typed;
}
