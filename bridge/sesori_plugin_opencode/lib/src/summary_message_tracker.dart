import "models/openapi/assistant_message.g.dart";
import "models/openapi/compaction_part.g.dart";
import "models/openapi/text_part.g.dart";
import "models/sse_event_data.g.dart";

/// What the live stream has shown of one compaction summary message: its
/// latest info, its latest text parts, and the `auto` flag of the compaction
/// marker it answers, when that marker was seen.
typedef SummaryMessage = ({AssistantMessage message, List<TextPart> textParts, bool? auto});

/// Records the raw facts of OpenCode's recent compaction summary messages
/// (`summary: true`) and compaction markers, so their text parts render as
/// compaction rows in the state of their message. The `message.updated`
/// naming a summary message precedes its parts.
class SummaryMessageTracker() {
  final Map<String, ({AssistantMessage message, Map<String, TextPart> textParts})> _summaries = {};
  final Map<String, bool> _markerAuto = {};

  /// Bounds each map, because nothing announces that a compaction is forgotten.
  static const int _maxRecorded = 16;

  void observe(SseEventData event) {
    switch (event) {
      case SseMessageUpdated(info: final AssistantMessage message) when message.summary ?? false:
        _summaries[message.id] = (message: message, textParts: _summaries[message.id]?.textParts ?? {});
        _bound(_summaries);
      case SseMessagePartUpdated(:final TextPart part) when part.synthetic != true:
        _summaries[part.messageID]?.textParts[part.id] = part;
      case SseMessagePartUpdated(:final CompactionPart part):
        _markerAuto[part.messageID] = part.auto;
        _bound(_markerAuto);
      case _:
    }
  }

  /// The summary message [event] belongs to, when it is a recorded one: the
  /// message a `message.updated` names or the message of an updated text part.
  SummaryMessage? summaryFor(SseEventData event) {
    final messageId = switch (event) {
      SseMessageUpdated(info: AssistantMessage(:final id)) => id,
      SseMessagePartUpdated(part: TextPart(:final messageID)) => messageID,
      _ => null,
    };
    return switch (_summaries[messageId]) {
      (:final message, :final textParts) => (
        message: message,
        textParts: List.unmodifiable(textParts.values),
        auto: _markerAuto[message.parentID],
      ),
      null => null,
    };
  }

  void clear() {
    _summaries.clear();
    _markerAuto.clear();
  }

  static void _bound(Map<String, Object> map) {
    if (map.length > _maxRecorded) map.remove(map.keys.first);
  }
}
