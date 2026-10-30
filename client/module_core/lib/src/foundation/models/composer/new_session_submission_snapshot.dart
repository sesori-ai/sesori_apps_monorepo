import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "composer_attachment.dart";
import "composer_draft.dart";
import "queued_session_submission.dart";
import "unsent_composer.dart";

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

  /// The text this submission sends. Only dictated prompt text is marked: a
  /// command sends its arguments as written.
  String get outgoingText => switch (this) {
    NewSessionCommandSubmissionSnapshot(:final draft) => draft.text,
    NewSessionTextSubmissionSnapshot(:final draft) => switch (draft.inputMode) {
      ComposerInputMode.typed => draft.text,
      ComposerInputMode.voiceAssisted => wrapDictatedText(text: draft.text),
    },
  };

  /// The words as written, matching `QueuedSessionSubmission.plainText`: the
  /// command with its arguments, the prompt text, or `null` for a prompt that
  /// carries only attachments.
  String? get plainText => switch (this) {
    NewSessionCommandSubmissionSnapshot(:final draft, :final command) =>
      draft.text.trim().isEmpty ? "/$command" : "/$command ${draft.text.trim()}",
    NewSessionTextSubmissionSnapshot(:final draft) => draft.text.isEmpty ? null : draft.text,
  };

  /// What the sending bubble shows, matching `QueuedSessionSubmission.displayText`:
  /// what the agent gets, or `null` for a prompt that carries only attachments.
  String? get displayText => switch (this) {
    NewSessionCommandSubmissionSnapshot() => plainText,
    NewSessionTextSubmissionSnapshot(:final draft) => draft.text.isEmpty ? null : outgoingText,
  };

  /// This submission with [followUps] appended in order, then [unsent], so
  /// one editable draft restores everything a failed creation could not send:
  /// each follow-up's text after a blank line, a command as its literal text
  /// (the composer holds one command, this one's), and its attachments after
  /// this one's. A command cannot carry attachments, so a command followed by
  /// images is restored as text too rather than dropping them.
  NewSessionSubmissionSnapshot withFollowUps({
    required List<QueuedSessionSubmission> followUps,
    required UnsentComposer? unsent,
  }) {
    final appended = [
      for (final followUp in followUps)
        (
          text: followUp.plainText,
          attachments: followUp.attachments,
          dictated: followUp.inputMode == ComposerInputMode.voiceAssisted,
        ),
      if (unsent case UnsentComposer(:final draft, :final command, :final attachments))
        (
          text: switch ((command: command?.name, text: draft.text.trim())) {
            (command: final String name, text: "") => "/$name",
            (command: final String name, :final text) => "/$name $text",
            (command: null, text: "") => null,
            (command: null, :final text) => text,
          },
          attachments: attachments,
          dictated: command == null && draft.inputMode == ComposerInputMode.voiceAssisted,
        ),
    ];
    if (appended.isEmpty) return this;
    // The first draft's voice spans stay valid wherever its text keeps its
    // offsets, and a dictated part keeps the restored draft dictated.
    ComposerDraft merged({required ComposerDraft first}) {
      final text = StringBuffer(first.text);
      final voiceSpans = [...first.voiceSpans];
      for (final part in appended) {
        final partText = part.text;
        if (partText == null) continue;
        if (text.isNotEmpty) text.write("\n\n");
        if (part.dictated) voiceSpans.add(VoiceOriginSpan(start: text.length, end: text.length + partText.length));
        text.write(partText);
      }
      return ComposerDraft(text: text.toString(), voiceSpans: voiceSpans);
    }

    final followUpAttachments = [for (final part in appended) ...part.attachments];
    return switch (this) {
      NewSessionTextSubmissionSnapshot(:final draft, :final attachments) => NewSessionSubmissionSnapshot.text(
        draft: merged(first: draft),
        attachments: [...attachments, ...followUpAttachments],
      ),
      NewSessionCommandSubmissionSnapshot(:final draft, :final command) when followUpAttachments.isEmpty =>
        NewSessionSubmissionSnapshot.command(
          draft: merged(first: draft),
          command: command,
        ),
      NewSessionCommandSubmissionSnapshot(:final draft, :final command) => NewSessionSubmissionSnapshot.text(
        draft: merged(first: ComposerDraft.typed(text: "/$command ${draft.text}".trim())),
        attachments: followUpAttachments,
      ),
    };
  }
}
