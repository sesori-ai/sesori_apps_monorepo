import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/database.dart";
import "session_unseen_calculator.dart";

/// The unseen-relevant timestamps for a single session, plus its project id.
typedef UnseenRow = ({
  String projectId,
  int? userMessageAt,
  int? seenAt,
  int? activityAt,
});

/// Layer-2 owner of all reads and writes of a session's unseen-changes
/// timestamps (`last_activity_at`, `last_seen_at`, `last_user_message_at`).
///
/// Writes are intentionally UPDATE-only for the activity/seen mutators: a child
/// (subagent) session is never persisted in `sessions_table` (the plugin lists
/// roots only), so an update for such a session affects zero rows — exactly the
/// "ignore children" behaviour we want. New ROOT sessions get a row via
/// [ensureRootSessionActivity].
class SessionUnseenRepository {
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final AppDatabase _db;
  final SessionUnseenCalculator _calculator;

  SessionUnseenRepository({
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required AppDatabase db,
    required SessionUnseenCalculator calculator,
  }) : _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _db = db,
       _calculator = calculator;

  /// Returns the unseen timestamps + project id for [sessionId], or null when
  /// the session has no persisted row (e.g. a child session, or one not yet
  /// learned via a list fetch).
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

  /// Marks [sessionId] seen as of [at] ("Mark as Read" / viewing).
  Future<void> markSessionSeen({required String sessionId, required int at}) {
    return _sessionDao.setSeenAt(sessionId: sessionId, seenAt: at);
  }

  /// Marks [sessionId] unread by clearing `last_seen_at`. It then bolds iff
  /// activity is newer than the user's last message.
  Future<void> markSessionUnseen({required String sessionId}) {
    return _sessionDao.clearSeenAt(sessionId: sessionId);
  }

  /// Ensures a ROOT session row exists for [sessionId] and stamps its activity
  /// at [createdAt] so a brand-new session is immediately unseen even before any
  /// list fetch. Wrapped in a transaction so the project FK cannot fire.
  Future<void> ensureRootSessionActivity({
    required String sessionId,
    required String projectId,
    required int createdAt,
  }) async {
    await _db.transaction(() async {
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSessionsIfMissing(
        sessions: [(sessionId: sessionId, projectId: projectId, createdAt: createdAt, archivedAt: null)],
      );
      await _sessionDao.setActivityTimestamps(
        sessionId: sessionId,
        activityAt: createdAt,
        userMessageAt: null,
        seenAt: null,
      );
    });
  }

  /// Whether [sessionId] currently has unseen changes.
  Future<bool> isUnseen({required String sessionId}) async {
    final row = await getUnseenRow(sessionId: sessionId);
    if (row == null) return false;
    return _calculator.isUnseen(
      activity: row.activityAt,
      userMessage: row.userMessageAt,
      seen: row.seenAt,
    );
  }
}
