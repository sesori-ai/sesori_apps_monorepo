import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// One live compaction: the message its row lives on, when the bridge saw it
/// start (Grok's queue entry carries no time), and what started it.
typedef GrokRunningCompaction = ({String messageId, int startedAtMs, PluginCompactionTrigger trigger});

/// Owns each session's live compaction. Grok's compaction notifications carry
/// only the session id, so the row a start creates is remembered here until
/// the matching completion or failure settles it.
final class GrokCompactionTracker({required final ServerClock clock}) {
  final Map<String, GrokRunningCompaction> _running = {};
  var _sequence = 0;

  /// Records a start, or returns the compaction already running in
  /// [sessionId]: every queue change during a `/compact` repeats its running
  /// entry, and must keep one row and one timer. A retry after a failure
  /// gets its own row, even when it starts in the same millisecond.
  GrokRunningCompaction start({required String sessionId, required PluginCompactionTrigger trigger}) =>
      _running.putIfAbsent(sessionId, () {
        final startedAtMs = clock.now().millisecondsSinceEpoch;
        return (
          messageId: "$sessionId-compaction-$startedAtMs-${_sequence++}",
          startedAtMs: startedAtMs,
          trigger: trigger,
        );
      });

  /// Removes and returns the compaction running in [sessionId], if any.
  GrokRunningCompaction? finish({required String sessionId}) => _running.remove(sessionId);

  void forgetSession({required String sessionId}) => _running.remove(sessionId);
}
