import "../../api/database/daos/session_dao.dart";
import "session_unseen_calculator.dart";

/// The unseen-relevant timestamps for a single session, plus its project id.
typedef UnseenRow = ({
  String projectId,
  int? userMessageAt,
  int? seenAt,
  int? activityAt,
});

/// Layer-2 owner of all reads and writes of a session's unseen-changes
/// timestamps (`last_activity_at`, `last_seen_at`, `last_user_message_at`),
/// including removing rows for sessions that no longer exist.
///
/// Writes are intentionally UPDATE-only for the activity/seen mutators;
/// project-level aggregation decides that durable child rows do not contribute
/// independently.
class SessionUnseenRepository {
  final SessionDao _sessionDao;
  final SessionUnseenCalculator _calculator;

  SessionUnseenRepository({
    required SessionDao sessionDao,
    required SessionUnseenCalculator calculator,
  }) : _sessionDao = sessionDao,
       _calculator = calculator;

  /// Returns the unseen timestamps + project id for [sessionId], or null when
  /// the session has no persisted row.
  Future<UnseenRow?> getUnseenRow({required String sessionId}) async {
    final dto = await _sessionDao.getSession(sessionId: sessionId);
    if (dto == null) return null;
    return (
      projectId: dto.projectId,
      userMessageAt: dto.lastUserMessageAt,
      seenAt: dto.lastSeenAt,
      activityAt: dto.lastActivityAt,
    );
  }

  /// Records activity at [at] for [sessionId] (UPDATE-only — see class doc).
  /// When [isUserMessage] is true, also advances `last_user_message_at`.
  /// When [advanceSeen] is true (the session is actively being viewed), also
  /// advances `last_seen_at` so it never bolds while watched.
  Future<void> recordActivity({
    required String sessionId,
    required int at,
    required bool isUserMessage,
    required bool advanceSeen,
  }) async {
    await _sessionDao.setActivityTimestamps(
      sessionId: sessionId,
      activityAt: at,
      userMessageAt: isUserMessage ? at : null,
      seenAt: advanceSeen ? at : null,
    );
  }

  /// Advances ONLY the user-message marker for [sessionId] (UPDATE-only).
  /// Used for user messages carrying their own creation time: engagement is
  /// recorded without touching the activity/seen timeline, so a re-emitted
  /// (old) user message can never clear unseen activity.
  Future<void> recordUserMessage({required String sessionId, required int at}) {
    return _sessionDao.setUserMessageAt(sessionId: sessionId, userMessageAt: at);
  }

  /// Marks [sessionId] seen as of [at] ("Mark as Read" / viewing).
  Future<void> markSessionSeen({required String sessionId, required int at}) {
    return _sessionDao.setSeenAt(sessionId: sessionId, seenAt: at);
  }

  /// Forces [sessionId] unread for an explicit "Mark as Unread" at [at]. Unlike
  /// clearing `last_seen_at` alone, this reliably bolds even baseline sessions
  /// and sessions whose latest activity was the user's own message.
  Future<void> markSessionUnseen({required String sessionId, required int at}) {
    return _sessionDao.forceUnseen(sessionId: sessionId, activityAt: at);
  }

  /// Removes the persisted session row (used when a session is deleted live so
  /// a stale unseen row can't keep its project's aggregate bold). No-op if the
  /// row doesn't exist.
  Future<void> deleteSession({required String sessionId}) {
    return _sessionDao.deleteSession(sessionId: sessionId);
  }

  /// Whether [sessionId] currently has unseen changes.
  Future<bool> isUnseen({required String sessionId}) async {
    final row = await getUnseenRow(sessionId: sessionId);
    if (row == null) return false;
    return unseenForRow(row);
  }

  /// Whether an already-fetched [row] currently has unseen changes. Lets callers
  /// avoid a re-read when they already hold the row.
  bool unseenForRow(UnseenRow row) {
    return _calculator.isUnseen(
      activity: row.activityAt,
      userMessage: row.userMessageAt,
      seen: row.seenAt,
    );
  }
}
