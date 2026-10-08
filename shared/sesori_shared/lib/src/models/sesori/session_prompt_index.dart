import "package:freezed_annotation/freezed_annotation.dart";

part "session_prompt_index.freezed.dart";
part "session_prompt_index.g.dart";

/// The body of `POST /session/prompts`: every prompt in the session's
/// history, oldest first, whether or not the app has loaded it.
@Freezed(fromJson: true, toJson: true)
sealed class SessionPromptIndexResponse with _$SessionPromptIndexResponse {
  const factory({
    required List<SessionPromptIndexEntry> entries,
  }) = _SessionPromptIndexResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptIndexResponseFromJson(json);
}

/// One user prompt the transcript renders, kinded by the shared
/// `splitPromptTurns` rule.
///
/// [number] counts every user message from the start of the session,
/// hidden ones included, as the page's `userMessagesBefore` does. [createdAt]
/// is the message's creation time in milliseconds since the epoch, null when
/// the harness gave none. [preview] is the start of the prompt's text (else its
/// first attachment's name), at most 300 UTF-16 code units; null when it has
/// nothing to show.
@Freezed(unionKey: "kind", fromJson: true, toJson: true, copyWith: false)
sealed class SessionPromptIndexEntry with _$SessionPromptIndexEntry {
  /// A prompt that opened a turn, or one before the first turn opened.
  @FreezedUnionValue("opener")
  const factory opener({
    required String messageId,
    required int seq,
    required int number,
    required int? createdAt,
    required String? preview,
  }) = SessionPromptIndexOpener;

  /// A prompt that joined the turn [openerMessageId] opened.
  @FreezedUnionValue("followUp")
  const factory followUp({
    required String messageId,
    required int seq,
    required int number,
    required int? createdAt,
    required String? preview,
    required String openerMessageId,
  }) = SessionPromptIndexFollowUp;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptIndexEntryFromJson(json);
}
