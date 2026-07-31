import "../../foundation/models/composer/composer_draft.dart";

sealed class QueuedSessionSubmission {
  const QueuedSessionSubmission();

  const factory QueuedSessionSubmission.text({
    required String text,
    required ComposerInputMode inputMode,
  }) = QueuedTextSubmission;

  const factory QueuedSessionSubmission.command({
    required String text,
    required String command,
  }) = QueuedCommandSubmission;

  String get text;
  String? get command;
  ComposerInputMode get inputMode;

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

  const QueuedTextSubmission({required this.text, required this.inputMode});

  @override
  String? get command => null;
}

final class QueuedCommandSubmission extends QueuedSessionSubmission {
  @override
  final String text;
  @override
  final String command;

  const QueuedCommandSubmission({required this.text, required this.command});

  @override
  ComposerInputMode get inputMode => ComposerInputMode.typed;
}
