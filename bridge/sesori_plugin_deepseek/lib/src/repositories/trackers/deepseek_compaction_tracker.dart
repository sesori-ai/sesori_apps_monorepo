import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// One live compaction: the message its row lives on, and when the bridge saw
/// it start (DeepSeek sends no compaction time).
typedef DeepSeekRunningCompaction = ({String messageId, int startedAtMs});

/// Owns each session's live compaction. DeepSeek's compaction status
/// notifications carry only the session id, so the row a start creates is
/// remembered here until the completion settles it.
final class DeepSeekCompactionTracker({required final ServerClock clock}) {
  final Map<String, DeepSeekRunningCompaction> _running = {};

  /// Records a start, or returns the compaction already running in
  /// [sessionId], so a repeated start keeps one row and one timer.
  DeepSeekRunningCompaction start({required String sessionId}) => _running.putIfAbsent(sessionId, () {
    final startedAtMs = clock.now().millisecondsSinceEpoch;
    return (messageId: "$sessionId-compaction-$startedAtMs", startedAtMs: startedAtMs);
  });

  /// Removes and returns the compaction running in [sessionId], if any.
  DeepSeekRunningCompaction? finish({required String sessionId}) => _running.remove(sessionId);

  void forgetSession({required String sessionId}) => _running.remove(sessionId);

  void clear() => _running.clear();
}
