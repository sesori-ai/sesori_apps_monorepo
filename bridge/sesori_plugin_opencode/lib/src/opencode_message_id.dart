import "dart:math";

/// Base62 alphabet OpenCode uses for the random half of an identifier.
const String _base62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

/// Random suffix length, matching OpenCode's 26-character body minus the
/// 12 hex characters of encoded time.
const int _randomLength = 14;

final Random _random = Random();

int _lastMilliseconds = 0;
int _counter = 0;

/// Generates a user-message id in OpenCode's own ascending format.
///
/// OpenCode accepts a caller-supplied `messageID` on its prompt and command
/// endpoints and uses it verbatim for the user message, which is what lets a
/// dispatch be matched to the message OpenCode later publishes. Because
/// OpenCode orders messages by id, the id must stay chronologically sortable:
/// 12 hex characters of `milliseconds * 0x1000 + counter` followed by 14
/// random base62 characters, exactly as OpenCode builds its own.
String generateOpenCodeMessageId() {
  final milliseconds = DateTime.now().millisecondsSinceEpoch;
  if (milliseconds != _lastMilliseconds) {
    _lastMilliseconds = milliseconds;
    _counter = 0;
  }
  _counter++;
  // OpenCode encodes the counted time in six bytes, so the value wraps at 48
  // bits exactly as it does upstream.
  final time = ((milliseconds * 0x1000 + _counter) & 0xFFFFFFFFFFFF).toRadixString(16).padLeft(12, "0");
  final suffix = String.fromCharCodes(
    List.generate(_randomLength, (_) => _base62.codeUnitAt(_random.nextInt(_base62.length))),
  );
  return "msg_$time$suffix";
}
