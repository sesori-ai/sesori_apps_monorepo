import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Tracks bytes sent to mobile and logs periodic bandwidth summaries.
///
/// Subscribes to [bytesSent] on construction and starts a periodic timer that
/// logs rolling totals (last 1 m / 10 m / 1 h) every 60 seconds. Call
/// [dispose] to cancel the timer and the stream subscription.
class BandwidthTracker {
  final List<_Record> _records = [];
  late final Timer _timer;
  late final StreamSubscription<int> _subscription;

  BandwidthTracker({required Stream<int> bytesSent}) {
    _subscription = bytesSent.listen((bytes) {
      _records.add(_Record(DateTime.now(), bytes));
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _logStats());
  }

  /// Stop the periodic timer and cancel the stream subscription.
  void dispose() {
    _timer.cancel();
    _subscription.cancel();
  }

  void _logStats() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));
    _records.removeWhere((r) => r.time.isBefore(cutoff));

    final last1m = _sumSince(now.subtract(const Duration(minutes: 1)));
    final last10m = _sumSince(now.subtract(const Duration(minutes: 10)));
    final last1h = _sumSince(now.subtract(const Duration(hours: 1)));

    Log.d(
      "[bandwidth] last 1m: ${formatBytes(last1m)} "
      "| last 10m: ${formatBytes(last10m)} "
      "| last 1h: ${formatBytes(last1h)}",
    );
  }

  int _sumSince(DateTime since) {
    int sum = 0;
    for (final r in _records.reversed) {
      if (r.time.isAfter(since)) {
        sum += r.bytes;
      } else {
        break;
      }
    }
    return sum;
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
