import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_detail_resolvers.dart";
import "transcript_turns.dart";

/// Where a listed prompt's content comes from.
@immutable
sealed class const TranscriptPromptSource();

/// A prompt the transcript has loaded.
final class const TranscriptPromptLoaded({
  /// The prompt's whole text, else its first attachment's name; null when it
  /// has neither.
  required final String? fullText,
}) extends TranscriptPromptSource;

/// A prompt only the bridge's prompt index knows, older than the loaded
/// range; loading through [seq] brings it into the transcript.
final class const TranscriptPromptUnloaded({
  required final int seq,

  /// The start of the prompt's text, else its first attachment's name; null
  /// when it has neither.
  required final String? preview,
}) extends TranscriptPromptSource;

/// One of the user's own prompts, as the Prompts screen lists it.
@immutable
sealed class const TranscriptPromptEntry({
  required final String messageId,

  /// The source text's first line that holds more than whitespace, trimmed,
  /// for a one-line row; null when there is none.
  required final String? text,

  required final TranscriptPromptSource source,

  /// When the prompt was sent, in milliseconds since the epoch; null when
  /// nothing observed it.
  required final int? createdAt,

  /// Midnight of the local day the row groups under; null for the undated
  /// group.
  required final DateTime? dayKey,

  /// Its position among all the session's user messages, from 1; null when
  /// the bridge sent no count to start from.
  required final int? number,
}) {
  /// The text search matches: the whole prompt when loaded, else its preview.
  String? get searchText => switch (source) {
    TranscriptPromptLoaded(:final fullText) => fullText,
    TranscriptPromptUnloaded(:final preview) => preview,
  };
}

/// A prompt that opened a turn, or one before the first turn opened.
final class const TranscriptPromptOpener({
  required super.messageId,
  required super.text,
  required super.source,
  required super.createdAt,
  required super.dayKey,
  required super.number,
}) extends TranscriptPromptEntry;

/// A prompt that joined the turn [openerMessageId] opened, such as one sent
/// while that turn ran.
final class const TranscriptPromptFollowUp({
  required super.messageId,
  required super.text,
  required super.source,
  required super.createdAt,
  required super.dayKey,
  required super.number,
  required final String openerMessageId,
}) extends TranscriptPromptEntry;

/// The listed prompts, oldest first in the transcript's own order, each
/// follow-up after the prompt it belongs to.
final class const TranscriptPromptList({
  required final List<TranscriptPromptEntry> entries,

  /// Whether the bridge's prompt index built the list, so it holds every
  /// prompt in the history rather than only the loaded ones.
  required final bool isIndexed,
}) {
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

    /// The bridge's prompt index over the whole history, or null to list only
    /// the loaded prompts. When present it decides every listed prompt's
    /// kind, number and time, since it folds the whole history while
    /// [turns] can misread the loaded range's first prompt.
    required List<SessionPromptIndexEntry>? index,

    /// The lowest `seq` [messages] covers, or null when they start the
    /// history: an indexed prompt below it is unloaded, and one at or above
    /// it that [messages] lacks is no longer shown.
    required int? olderMessagesCursor,
  }) {
    final loaded = _loadedEntries(messages: messages, turns: turns, userMessagesBefore: userMessagesBefore);
    if (index == null) return TranscriptPromptList(entries: List.unmodifiable(loaded), isIndexed: false);

    final loadedById = {for (final entry in loaded) entry.messageId: entry};
    final entries = <TranscriptPromptEntry>[];
    final dayKeyByOpenerId = <String, DateTime?>{};
    for (final indexed in index) {
      final loadedEntry = loadedById[indexed.messageId];
      final TranscriptPromptSource source;
      final String? text;
      if (loadedEntry != null) {
        source = loadedEntry.source;
        text = loadedEntry.text;
      } else if (olderMessagesCursor != null && indexed.seq < olderMessagesCursor) {
        source = TranscriptPromptUnloaded(seq: indexed.seq, preview: indexed.preview);
        text = switch (indexed.preview) {
          final preview? => firstNonBlankLine(text: preview),
          null => null,
        };
      } else {
        continue;
      }
      final ownDay = switch (indexed.createdAt) {
        final createdAt? => _dayOf(createdAt: createdAt),
        null => null,
      };
      switch (indexed) {
        case SessionPromptIndexOpener():
          dayKeyByOpenerId[indexed.messageId] = ownDay;
          entries.add(
            TranscriptPromptOpener(
              messageId: indexed.messageId,
              text: text,
              source: source,
              createdAt: indexed.createdAt,
              dayKey: ownDay,
              number: indexed.number,
            ),
          );
        case SessionPromptIndexFollowUp(:final openerMessageId):
          entries.add(
            TranscriptPromptFollowUp(
              messageId: indexed.messageId,
              text: text,
              source: source,
              createdAt: indexed.createdAt,
              // An undated follow-up belongs to its turn's day.
              dayKey: ownDay ?? dayKeyByOpenerId[openerMessageId],
              number: indexed.number,
              openerMessageId: openerMessageId,
            ),
          );
      }
    }
    // Prompts sent after the index was fetched, as the loaded range reads them.
    final indexedIds = {for (final indexed in index) indexed.messageId};
    entries.addAll(loaded.where((entry) => !indexedIds.contains(entry.messageId)));
    return TranscriptPromptList(entries: List.unmodifiable(entries), isIndexed: true);
  }

  List<TranscriptPromptEntry> _loadedEntries({
    required List<MessageWithParts> messages,
    required TranscriptTurns turns,
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
      final source = TranscriptPromptLoaded(fullText: fullText);
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
              source: source,
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
              source: source,
              createdAt: createdAt,
              dayKey: ownDay,
              number: number,
            ),
          );
      }
    }
    return entries;
  }

  static DateTime _dayOf({required int createdAt}) {
    final local = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateTime(local.year, local.month, local.day);
  }
}
