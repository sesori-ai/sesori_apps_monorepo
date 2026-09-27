import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_detail_resolvers.dart";
import "transcript_turns.dart";

/// One of the user's own prompts, as the Prompts screen lists it.
@immutable
sealed class const TranscriptPromptEntry({
  required final String messageId,

  /// [fullText]'s first line that holds more than whitespace, trimmed, for a
  /// one-line row; null when there is none.
  required final String? text,

  /// The prompt's whole text, else its first attachment's name; null when it
  /// has neither.
  required final String? fullText,

  /// When the prompt was sent, in milliseconds since the epoch; null when
  /// nothing observed it.
  required final int? createdAt,

  /// Midnight of the local day the row groups under; null for the undated
  /// group.
  required final DateTime? dayKey,

  /// Its position among all the session's user messages, from 1; null when
  /// the bridge sent no count to start from.
  required final int? number,
});

/// A prompt that opened a turn, or one before the first turn opened.
final class const TranscriptPromptOpener({
  required super.messageId,
  required super.text,
  required super.fullText,
  required super.createdAt,
  required super.dayKey,
  required super.number,
}) extends TranscriptPromptEntry;

/// A prompt that joined the turn [openerMessageId] opened, such as one sent
/// while that turn ran.
final class const TranscriptPromptFollowUp({
  required super.messageId,
  required super.text,
  required super.fullText,
  required super.createdAt,
  required super.dayKey,
  required super.number,
  required final String openerMessageId,
}) extends TranscriptPromptEntry;

/// The loaded prompts, oldest first in the transcript's own order, each
/// follow-up after the prompt it belongs to.
final class const TranscriptPromptList({required final List<TranscriptPromptEntry> entries}) {
  /// Whether any listed prompt has a time; a session nothing ever timed shows
  /// no time column and no day headers.
  bool get hasTimes => entries.any((entry) => entry.createdAt != null);

  int get promptCount => entries.length;
}

/// Lists the user's rendered prompts for the Prompts screen.
///
/// Pure and stateless like [TranscriptTurnBuilder], over the same messages the
/// transcript renders. One oldest-first pass sets both the order and the
/// numbers, so nothing is reordered afterwards.
class const TranscriptPromptListBuilder() {
  TranscriptPromptList build({
    required List<MessageWithParts> messages,

    /// [TranscriptTurnBuilder]'s turns for [messages], which decide which
    /// prompts are follow-ups.
    required TranscriptTurns turns,

    /// How many user messages precede [messages] in the session; null when
    /// the bridge did not say, which leaves every row unnumbered.
    required int? userMessagesBefore,
  }) {
    final entries = <TranscriptPromptEntry>[];
    final dayKeyByOpenerId = <String, DateTime?>{};
    var userMessages = 0;
    for (final message in messages) {
      if (message.info is! MessageUser) continue;
      // A hidden user message still takes a number, as the bridge counts it.
      userMessages++;
      if (!message.hasRenderableUserContent) continue;

      final id = message.info.id;
      final createdAt = message.info.time?.created;
      final fullText = message.promptText;
      final text = fullText == null ? null : firstNonBlankLine(text: fullText);
      final number = userMessagesBefore == null ? null : userMessagesBefore + userMessages;
      final ownDay = createdAt == null ? null : _dayOf(createdAt: createdAt);
      final turnIndex = turns.turnIndexByMessageId[id];
      // Before the first prompt there is no turn to be a child of.
      switch (turnIndex == null ? null : turns.turns[turnIndex]) {
        case TranscriptPromptTurn(:final opener) when opener.info.id != id:
          entries.add(
            TranscriptPromptFollowUp(
              messageId: id,
              text: text,
              fullText: fullText,
              createdAt: createdAt,
              // An undated follow-up belongs to its turn's day.
              dayKey: ownDay ?? dayKeyByOpenerId[opener.info.id],
              number: number,
              openerMessageId: opener.info.id,
            ),
          );
        case _:
          dayKeyByOpenerId[id] = ownDay;
          entries.add(
            TranscriptPromptOpener(
              messageId: id,
              text: text,
              fullText: fullText,
              createdAt: createdAt,
              dayKey: ownDay,
              number: number,
            ),
          );
      }
    }
    return TranscriptPromptList(entries: List.unmodifiable(entries));
  }

  static DateTime _dayOf({required int createdAt}) {
    final local = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateTime(local.year, local.month, local.day);
  }
}
