import "dart:async";

import "package:flutter/foundation.dart";

/// A move the transcript is asked to make, and the signal that it ended.
typedef TranscriptJump = ({String messageId, Completer<void> landed});

/// Asks the transcript to move to a message, such as a prompt tapped on the
/// Prompts screen. The transcript takes the pending jump and clears it, so
/// asking for the same message twice moves twice.
class TranscriptJumpNotifier() extends ChangeNotifier {
  TranscriptJump? _pending;

  /// Completes once the transcript has landed on [messageId] or cannot reach
  /// it, at once when no transcript is listening.
  Future<void> jumpTo({required String messageId}) {
    final jump = (messageId: messageId, landed: Completer<void>());
    _pending?.landed.complete();
    _pending = jump;
    if (hasListeners) {
      notifyListeners();
    } else {
      take()?.landed.complete();
    }
    return jump.landed.future;
  }

  /// Takes the pending jump, leaving none. The taker completes its `landed`.
  TranscriptJump? take() {
    final jump = _pending;
    _pending = null;
    return jump;
  }
}
