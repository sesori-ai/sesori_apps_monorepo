import "package:freezed_annotation/freezed_annotation.dart";

import "composer_attachment.dart";
import "composer_draft.dart";

part "new_session_submission_snapshot.freezed.dart";

@Freezed()
sealed class const NewSessionSubmissionSnapshot._() with _$NewSessionSubmissionSnapshot {
  const factory text({
    required ComposerDraft draft,
    required List<ComposerAttachment> attachments,
  }) = NewSessionTextSubmissionSnapshot;

  const factory command({
    required ComposerDraft draft,
    required String command,
  }) = NewSessionCommandSubmissionSnapshot;

  /// What the sending bubble shows, matching `QueuedSessionSubmission.displayText`: the
  /// command with its arguments, the prompt text, or `null` for a prompt that
  /// carries only attachments.
  String? get displayText => switch (this) {
    NewSessionCommandSubmissionSnapshot(:final draft, :final command) =>
      draft.text.trim().isEmpty ? "/$command" : "/$command ${draft.text.trim()}",
    NewSessionTextSubmissionSnapshot(:final draft) => draft.text.isEmpty ? null : draft.text,
  };
}
