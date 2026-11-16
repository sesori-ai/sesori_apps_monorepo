import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/grok_session_notification_dto.dart";

/// One live compaction: the message its row lives on, when it started, and
/// what started it.
typedef GrokRunningCompaction = ({String messageId, int startedAtMs, PluginCompactionTrigger trigger});

/// Owns each session's live compaction. Grok's compaction notifications carry
/// only the session id, so the row a start creates is remembered here until
/// the matching completion or failure settles it.
final class GrokCompactionTracker({required final ServerClock clock}) {
  final Map<String, GrokRunningCompaction> _running = {};
  var _sequence = 0;

  /// Records a start, or returns the compaction already running in
  /// [sessionId]: every queue change during a `/compact` repeats its running
  /// entry, and must keep one row and one timer. [key] names the row as its
  /// replay will (see [GrokSessionProtocol.compactionMessageId]); without one
  /// the row is live only. [startedAtMs] is Grok's time for the start, else
  /// the bridge stamps it.
  GrokRunningCompaction start({
    required String sessionId,
    required String? key,
    required int? startedAtMs,
    required PluginCompactionTrigger trigger,
  }) => _running.putIfAbsent(sessionId, () {
    final startedAt = startedAtMs ?? clock.now().millisecondsSinceEpoch;
    return (
      messageId: GrokSessionProtocol.compactionMessageId(
        sessionId: sessionId,
        key: key ?? "$startedAt-${_sequence++}",
      ),
      startedAtMs: startedAt,
      trigger: trigger,
    );
  });

  /// Removes and returns the compaction running in [sessionId], if any.
  GrokRunningCompaction? finish({required String sessionId}) => _running.remove(sessionId);

  void forgetSession({required String sessionId}) => _running.remove(sessionId);
}
