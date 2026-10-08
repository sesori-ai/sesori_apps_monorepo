import "package:sesori_shared/sesori_shared.dart";

/// The most UTF-16 code units an index entry's preview carries.
const promptIndexPreviewLength = 300;

/// One stored message with its position in the session's history.
typedef SequencedMessage = ({int seq, MessageWithParts message});

/// Builds a session's prompt index from its stored history.
class const PromptIndexMapper() {
  /// The prompt index of a whole transcript, oldest first: one entry per
  /// rendered user message, kinded by the shared [splitPromptTurns] rule.
  ///
  /// [messages] must be the session's complete history in `seq` order, so the
  /// numbers count every user message from the start and the fold sees every
  /// turn. A prompt in the leading segment is an opener, as the app lists it.
  List<SessionPromptIndexEntry> indexOf({required List<SequencedMessage> messages}) {
    final openerIdByMessageId = <String, String>{
      for (final segment in splitPromptTurns(messages: [for (final entry in messages) entry.message]))
        if (segment case PromptSegment(:final opener))
          for (final message in segment.messages) message.info.id: opener.info.id,
    };
    final entries = <SessionPromptIndexEntry>[];
    var number = 0;
    for (final (:seq, :message) in messages) {
      if (message.info is! MessageUser) continue;
      // A hidden user message still takes a number, as the page count does.
      number++;
      if (!message.hasRenderableUserContent) continue;
      final messageId = message.info.id;
      final createdAt = message.info.time?.created;
      final preview = _previewOf(text: message.promptText);
      entries.add(switch (openerIdByMessageId[messageId]) {
        final openerId? when openerId != messageId => SessionPromptIndexEntry.followUp(
          messageId: messageId,
          seq: seq,
          number: number,
          createdAt: createdAt,
          preview: preview,
          openerMessageId: openerId,
        ),
        _ => SessionPromptIndexEntry.opener(
          messageId: messageId,
          seq: seq,
          number: number,
          createdAt: createdAt,
          preview: preview,
        ),
      });
    }
    return entries;
  }

  /// [text] without leading whitespace, cut to [promptIndexPreviewLength] code
  /// units without splitting a surrogate pair; null when nothing is left.
  String? _previewOf({required String? text}) {
    final trimmed = text?.trimLeft();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length <= promptIndexPreviewLength) return trimmed;
    final lastKept = trimmed.codeUnitAt(promptIndexPreviewLength - 1);
    final isLeadSurrogate = lastKept >= 0xD800 && lastKept <= 0xDBFF;
    return trimmed.substring(0, isLeadSurrogate ? promptIndexPreviewLength - 1 : promptIndexPreviewLength);
  }
}
