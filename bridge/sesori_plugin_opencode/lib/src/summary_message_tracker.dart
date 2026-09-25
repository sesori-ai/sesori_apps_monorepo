import "dart:collection";

import "models/openapi/assistant_message.g.dart";
import "models/sse_event_data.g.dart";

/// Remembers OpenCode's recent compaction summary messages (`summary: true`),
/// whose text parts render as compaction rows. The `message.updated` naming a
/// summary message precedes its parts.
class SummaryMessageTracker() {
  final Set<String> _messageIds = {};

  /// Bounds the set, because nothing announces that a summary message is done.
  static const int _maxRecordedMessages = 16;

  void observe(SseEventData event) {
    if (event case SseMessageUpdated(info: AssistantMessage(summary: true, :final id))) {
      _messageIds.add(id);
      if (_messageIds.length > _maxRecordedMessages) _messageIds.remove(_messageIds.first);
    }
  }

  Set<String> get messageIds => UnmodifiableSetView(_messageIds);

  void clear() {
    _messageIds.clear();
  }
}
