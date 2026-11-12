import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// One live compaction: the message its row lives on, and when the bridge saw
/// it start (OMP sends no compaction time).
typedef OmpRunningCompaction = ({String messageId, int startedAtMs});

/// Owns each session's live compaction. OMP's compaction notifications carry
/// only the session id, so the row a start creates is remembered here until
/// the matching end settles it.
final class OmpCompactionTracker({required final ServerClock clock}) {
  final Map<String, OmpRunningCompaction> _running = {};

  /// Records a start. Each start gets its own row, so a compaction whose end
  /// never arrived cannot capture a later one.
  OmpRunningCompaction start({required String sessionId}) {
    final startedAtMs = clock.now().millisecondsSinceEpoch;
    return _running[sessionId] = (messageId: "$sessionId-compaction-$startedAtMs", startedAtMs: startedAtMs);
  }

  /// Removes and returns the compaction running in [sessionId], if any.
  OmpRunningCompaction? finish({required String sessionId}) => _running.remove(sessionId);

  void forgetSession({required String sessionId}) => _running.remove(sessionId);
}
