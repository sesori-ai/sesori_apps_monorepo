import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "transcript_builder.dart";

/// One exchange of the rendered transcript: what a prompt set off, with the
/// follow-ups and automation that joined it.
@immutable
sealed class const TranscriptTurn({
  /// The rendered messages the turn covers, in transcript order.
  required final List<String> messageIds,
});

/// A turn opened by a user prompt, which stays its header.
final class const TranscriptPromptTurn({
  /// The prompt that opened the turn; always its first message.
  required final MessageWithParts opener,
  required super.messageIds,
}) extends TranscriptTurn;

/// The messages before the first loaded prompt while older pages remain. The
/// prompt they answer may be on a page that has not loaded.
final class const TranscriptPartialTurn({required super.messageIds}) extends TranscriptTurn;

/// The messages before the first prompt once the whole history is loaded,
/// such as automation that ran before the user wrote anything.
final class const TranscriptPreamble({required super.messageIds}) extends TranscriptTurn;

/// The rendered transcript split into turns.
final class const TranscriptTurns({
  /// Oldest first.
  required final List<TranscriptTurn> turns,

  /// Where in [turns] each rendered message's turn sits.
  required final Map<String, int> turnIndexByMessageId,
});

/// Splits the rendered transcript into turns.
///
/// Which user messages open a turn is the shared [splitPromptTurns] rule, the
/// same one the bridge's prompt index uses. This maps its headless leading
/// segment to a [TranscriptPartialTurn] or a [TranscriptPreamble].
///
/// Pure and stateless like [TranscriptBuilder], so the message list can run it
/// over whatever it renders.
class const TranscriptTurnBuilder() {
  TranscriptTurns build({
    required List<MessageWithParts> messages,

    /// Whether older pages remain, so the leading messages may belong to a
    /// turn whose prompt has not loaded.
    required bool hasOlderMessages,
  }) {
    final turns = <TranscriptTurn>[];
    final turnIndexByMessageId = <String, int>{};
    for (final (index, segment) in splitPromptTurns(messages: messages).indexed) {
      final messageIds = List<String>.unmodifiable([for (final message in segment.messages) message.info.id]);
      for (final id in messageIds) {
        turnIndexByMessageId[id] = index;
      }
      turns.add(switch (segment) {
        PromptSegment(:final opener) => TranscriptPromptTurn(opener: opener, messageIds: messageIds),
        LeadingPromptSegment() when hasOlderMessages => TranscriptPartialTurn(messageIds: messageIds),
        LeadingPromptSegment() => TranscriptPreamble(messageIds: messageIds),
      });
    }
    return TranscriptTurns(
      turns: List.unmodifiable(turns),
      turnIndexByMessageId: Map.unmodifiable(turnIndexByMessageId),
    );
  }
}
