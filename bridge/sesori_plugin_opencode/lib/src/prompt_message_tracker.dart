/// Remembers which prompt created which OpenCode user message.
///
/// The bridge names the user message it asks OpenCode to create (see
/// `generateOpenCodeMessageId`), so the message OpenCode later publishes can be
/// traced back to the send that caused it. A message id this tracker does not
/// know — one OpenCode named for the TUI, or one evicted by the bound below —
/// simply resolves to null and that echo stays unattributed.
class PromptMessageTracker() {
  final Map<String, String> _promptIdsByMessage = {};

  /// Bounds the map against dispatches whose message never streams back.
  static const int _maxRecordedMessages = 64;

  /// Records that [messageId] names the user message [promptId] created.
  void record({required String messageId, required String promptId}) {
    _promptIdsByMessage[messageId] = promptId;
    if (_promptIdsByMessage.length > _maxRecordedMessages) {
      _promptIdsByMessage.remove(_promptIdsByMessage.keys.first);
    }
  }

  /// Prompt that created [messageId], or null when this bridge did not send it.
  String? promptIdFor({required String messageId}) => _promptIdsByMessage[messageId];
}
