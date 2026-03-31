import "package:sesori_shared/sesori_shared.dart";

class SseEvent {
  final SesoriSseEvent data;
  final String? directory;

  /// The session this event belongs to, or null for non-session-scoped events.
  ///
  /// Computed lazily on first access. Use this to filter events by session
  /// via [ConnectionService.sessionEvents].
  late final String? sessionId = _extractSessionId(data);

  static String? _extractSessionId(SesoriSseEvent event) {
    if (event case SesoriSessionCreated(:final info)) return info.id;
    if (event case SesoriSessionUpdated(:final info)) return info.id;
    if (event case SesoriSessionDeleted(:final info)) return info.id;
    if (event case SesoriSessionDiff(:final sessionID)) return sessionID;
    if (event case SesoriSessionError(:final sessionID)) return sessionID;
    if (event case SesoriSessionCompacted(:final sessionID)) return sessionID;
    if (event case SesoriSessionStatus(:final sessionID)) return sessionID;
    // ignore: deprecated_member_use, retained for backward-compatible SSE payloads
    if (event case SesoriSessionIdle(:final sessionID)) return sessionID;
    if (event case SesoriMessageUpdated(:final info)) return info.sessionID;
    if (event case SesoriMessageRemoved(:final sessionID)) return sessionID;
    if (event case SesoriMessagePartUpdated(:final part)) return part.sessionID;
    if (event case SesoriMessagePartDelta(:final sessionID)) return sessionID;
    if (event case SesoriMessagePartRemoved(:final sessionID)) return sessionID;
    if (event case SesoriPermissionAsked(:final sessionID)) return sessionID;
    if (event case SesoriQuestionAsked(:final sessionID)) return sessionID;
    if (event case SesoriQuestionReplied(:final sessionID)) return sessionID;
    if (event case SesoriQuestionRejected(:final sessionID)) return sessionID;
    if (event case SesoriTodoUpdated(:final sessionID)) return sessionID;
    return null;
  }

  SseEvent({required this.data, this.directory});
}
