import "package:sesori_shared/sesori_shared.dart";

class SseEvent {
  final SesoriSseEvent data;
  final String? directory;

  /// The session this event belongs to, or null for non-session-scoped events.
  ///
  /// Computed lazily on first access. Use this to filter events by session
  /// via [ConnectionService.sessionEvents].
  late final String? sessionId = _extractSessionId(data);

  static String? _extractSessionId(SesoriSseEvent event) => switch (event) {
    SesoriSessionCreated(:final info) => info.id,
    SesoriSessionUpdated(:final info) => info.id,
    SesoriSessionDeleted(:final info) => info.id,
    SesoriSessionDiff(:final sessionID) => sessionID,
    SesoriSessionError(:final sessionID) => sessionID,
    SesoriSessionCompacted(:final sessionID) => sessionID,
    SesoriSessionStatus(:final sessionID) => sessionID,
    // ignore: deprecated_member_use, retained for backward-compatible SSE payloads
    SesoriSessionIdle(:final sessionID) => sessionID,
    SesoriMessageUpdated(:final info) => info.sessionID,
    SesoriMessageRemoved(:final sessionID) => sessionID,
    SesoriMessagePartUpdated(:final part) => part.sessionID,
    SesoriMessagePartDelta(:final sessionID) => sessionID,
    SesoriMessagePartRemoved(:final sessionID) => sessionID,
    SesoriPermissionAsked(:final sessionID) => sessionID,
    SesoriQuestionAsked(:final sessionID) => sessionID,
    SesoriQuestionReplied(:final sessionID) => sessionID,
    SesoriQuestionRejected(:final sessionID) => sessionID,
    SesoriTodoUpdated(:final sessionID) => sessionID,
    _ => null,
  };

  SseEvent({required this.data, this.directory});
}
