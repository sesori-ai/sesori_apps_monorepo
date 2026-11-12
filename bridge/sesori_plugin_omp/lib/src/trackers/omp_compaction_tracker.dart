import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// One live compaction: the message its row lives on, and when the bridge saw
/// it start (OMP sends no compaction time).
typedef OmpRunningCompaction = ({String messageId, int startedAtMs});

/// Owns each session's live compaction. OMP's compaction notifications carry
/// only the session id, so the row a start creates is remembered here until
/// the matching end settles it.
final class OmpCompactionTracker({required final ServerClock clock}) {
  final Map<String, OmpRunningCompaction> _running = {};
  var _sequence = 0;

  /// Records a start. Each start gets its own row, even when a fallback
  /// method starts in the same millisecond as the failed one ended.
  OmpRunningCompaction start({required String sessionId}) {
    final startedAtMs = clock.now().millisecondsSinceEpoch;
    return _running[sessionId] = (
      messageId: "$sessionId-compaction-$startedAtMs-${_sequence++}",
      startedAtMs: startedAtMs,
    );
  }

  List<String> get runningSessionIds => _running.keys.toList(growable: false);

  /// Removes and returns the compaction running in [sessionId], if any.
  OmpRunningCompaction? finish({required String sessionId}) => _running.remove(sessionId);

  void forgetSession({required String sessionId}) => _running.remove(sessionId);

  void clear() => _running.clear();
}
