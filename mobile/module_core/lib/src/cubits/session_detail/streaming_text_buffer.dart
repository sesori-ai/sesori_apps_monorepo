import "dart:async";

/// Accumulates streaming text deltas and emits throttled snapshots.
///
/// Owns the mutable [Map<String, StringBuffer>] and a throttle [Timer],
/// isolating all mutable streaming state from the cubit. Call [dispose]
/// when the owning cubit closes.
class StreamingTextBuffer {
  final void Function() _onFlush;
  final Duration _throttle;

  final Map<String, StringBuffer> _buffers = {};
  Timer? _timer;

  StreamingTextBuffer({
    required void Function() onFlush,
    Duration throttle = const Duration(milliseconds: 50),
  }) : _onFlush = onFlush,
       _throttle = throttle;

  /// Append a text delta for [partId], scheduling a throttled flush.
  void appendDelta(String partId, String delta) {
    _buffers.putIfAbsent(partId, StringBuffer.new).write(delta);
    _scheduleFlush();
  }

  /// Remove a part's buffer (e.g. when the part is finalized or removed).
  void removePart(String partId) => _buffers.remove(partId);

  /// Returns the current accumulated text as an immutable snapshot.
  Map<String, String> snapshot() => _buffers.map((key, value) => MapEntry(key, value.toString()));

  /// Cancel any pending flush timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleFlush() {
    _timer ??= Timer(_throttle, () {
      _timer = null;
      _onFlush();
    });
  }
}
