import "package:freezed_annotation/freezed_annotation.dart";

import "../session_launch/session_launch_composer.dart";
import "composer_attachment.dart";
import "composer_draft.dart";
import "queued_session_submission.dart";

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
      for (final followUp in followUps) (text: followUp.displayText, attachments: followUp.attachments),
      if (unsent case UnsentComposer(:final draft, :final command, :final attachments))
        (
          text: switch ((command: command?.name, text: draft.text.trim())) {
            (command: final String name, text: "") => "/$name",
            (command: final String name, :final text) => "/$name $text",
            (command: null, text: "") => null,
            (command: null, :final text) => text,
          },
          attachments: attachments,
        ),
    ];
    if (appended.isEmpty) return this;
    // The first draft's voice spans stay valid wherever its text keeps its
    // offsets.
    ComposerDraft merged({required ComposerDraft first}) => ComposerDraft(
      text: [
        if (first.text.isNotEmpty) first.text,
        for (final part in appended) ?part.text,
      ].join("\n\n"),
      voiceSpans: first.voiceSpans,
    );
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
