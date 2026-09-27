import "package:flutter/foundation.dart";

/// Asks the transcript to move to a message, such as a prompt tapped on the
/// Prompts screen. The transcript takes the pending id and clears it, so
/// asking for the same message twice moves twice.
class TranscriptJumpNotifier() extends ChangeNotifier {
  String? _pendingMessageId;

  void jumpTo({required String messageId}) {
    _pendingMessageId = messageId;
    notifyListeners();
  }

  /// Takes the pending message id, leaving none.
  String? take() {
    final messageId = _pendingMessageId;
    _pendingMessageId = null;
    return messageId;
  }
}
