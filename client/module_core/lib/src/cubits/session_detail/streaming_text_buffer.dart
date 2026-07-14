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
  void appendDelta({required String partId, required String delta}) {
    _buffers.putIfAbsent(partId, StringBuffer.new).write(delta);
    _scheduleFlush();
  }

  /// Remove a part's buffer (e.g. when the part is finalized or removed).
  ///
  /// Recomputes any pending flush: a large finalized part must not leave its
  /// stretched interval throttling the remaining small parts, and an empty
  /// buffer set needs no flush at all (callers emit their own state when
  /// finalizing a part).
  void removePart(String partId) {
    if (_buffers.remove(partId) == null) return;
    final pending = _timer;
    if (pending == null) return;
    pending.cancel();
    _timer = null;
    if (_buffers.isNotEmpty) _scheduleFlush();
  }

  /// Returns the current accumulated text as an immutable snapshot.
  Map<String, String> snapshot() => _buffers.map((key, value) => MapEntry(key, value.toString()));

  /// Clear all buffered parts and cancel any pending flush timer.
  /// Unlike [dispose], the buffer remains usable for future [appendDelta] calls.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _buffers.clear();
  }

  /// Cancel any pending flush timer.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleFlush() {
    _timer ??= Timer(_flushInterval(), () {
      _timer = null;
      _onFlush();
    });
  }

  /// Buffered text above which the flush interval starts stretching.
  static const int _relaxedFlushThresholdChars = 8192;

  /// Upper bound for the stretched flush interval.
  static const Duration _maxFlushInterval = Duration(milliseconds: 300);

  /// Each flush makes consumers re-render the full accumulated text (the
  /// markdown of a streaming part is re-parsed and re-laid-out whole), so a
  /// fixed interval turns long streams quadratic. Stretch the interval as the
  /// buffered text grows: the base throttle while parts are small, up to
  /// [_maxFlushInterval] for very long ones.
  Duration _flushInterval() {
    var total = 0;
    for (final buffer in _buffers.values) {
      total += buffer.length;
    }
    if (total <= _relaxedFlushThresholdChars) return _throttle;
    final scaled = _throttle * (total / _relaxedFlushThresholdChars);
    return scaled > _maxFlushInterval ? _maxFlushInterval : scaled;
  }
}
