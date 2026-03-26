import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Tracks bytes sent to mobile and logs periodic bandwidth summaries.
///
/// Call [record] every time data is sent. Call [start] to begin the periodic
/// log timer (every 60 s) and [stop] to cancel it. The timer logs totals for
/// the last 1 minute, 10 minutes, and 1 hour.
class BandwidthTracker {
  final List<_Record> _records = [];
  Timer? _timer;

  /// Record [bytes] sent at the current time.
  void record({required int bytes}) {
    _records.add(_Record(DateTime.now(), bytes));
    _prune();
  }

  /// Start the periodic stats timer (logs every 60 seconds).
  void start() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _logStats());
  }

  /// Stop the periodic stats timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _logStats() {
    final now = DateTime.now();
    final last1m = _sumSince(now.subtract(const Duration(minutes: 1)));
    final last10m = _sumSince(now.subtract(const Duration(minutes: 10)));
    final last1h = _sumSince(now.subtract(const Duration(hours: 1)));

    Log.i(
      "[bandwidth] last 1m: ${formatBytes(last1m)} "
      "| last 10m: ${formatBytes(last10m)} "
      "| last 1h: ${formatBytes(last1h)}",
    );
  }

  int _sumSince(DateTime since) {
    int sum = 0;
    for (final r in _records) {
      if (r.time.isAfter(since)) sum += r.bytes;
    }
    return sum;
  }

  /// Remove entries older than 1 hour to bound memory.
  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _records.removeWhere((r) => r.time.isBefore(cutoff));
  }

  /// Format a byte count as a human-readable string (B / KB / MB).
  static String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }
}

class _Record {
  final DateTime time;
  final int bytes;
  const _Record(this.time, this.bytes);
}
