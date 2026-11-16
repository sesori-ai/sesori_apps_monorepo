import "package:clock/clock.dart";
import "package:sesori_shared/sesori_shared.dart";

/// When each session last showed activity, which is when its harness last
/// used its prompt cache. Auto-compact measures its quiet window from it.
///
/// It lives in memory only, so after a restart every session reads as active
/// at the bridge's start: the window can only restart, never pass early.
/// `sessions.lastActivityAt` cannot serve: the unseen tracking stops moving it
/// once an unattended session is unseen.
// ponytail: one entry per active session for the bridge's lifetime; drop
// entries on session deletion if bridges ever run long with many sessions.
class ScheduledTaskActivityTracker({required final Clock _clock}) {
  final DateTime _startedAt = _clock.now();
  final Map<String, DateTime> _lastActivity = {};

  /// Stamps the event's session with the current time, when it has one.
  void recordEvent({required SesoriSseEvent event}) {
    final sessionId = switch (event) {
      SesoriSessionStatus(:final sessionID) => sessionID,
      SesoriMessageUpdated(:final info) => info.sessionID,
      SesoriMessagePartUpdated(:final part) => part.sessionID,
      _ => null,
    };
    if (sessionId != null) _lastActivity[sessionId] = _clock.now();
  }

  /// When [sessionId] last showed activity, or the bridge's start when it has
  /// shown none since.
  DateTime lastActivity({required String sessionId}) => _lastActivity[sessionId] ?? _startedAt;
}
