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
/// timestamps (`last_activity_at`, `last_seen_at`, `last_user_message_at`),
/// including removing rows for sessions that no longer exist.
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

  /// The active plugin's id, stamped onto any session row this repository
  /// creates ([ensureRootSessionActivity]).
  final String _pluginId;

  SessionUnseenRepository({
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required AppDatabase db,
    required SessionUnseenCalculator calculator,
    required String pluginId,
  }) : _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _db = db,
       _calculator = calculator,
       _pluginId = pluginId;

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

  /// Ensures a ROOT session row exists for [sessionId] and stamps its activity
  /// at [activityAt] so a brand-new session is immediately unseen even before
  /// any list fetch. When [advanceSeen] is true (a phone is already viewing it),
  /// the seen timestamp is advanced too so it does not bold under the watcher.
  /// When [isUserMessage] is true, the user-message marker is stamped so the
  /// user's own first message doesn't bold the session.
  ///
  /// [createdAt] is the row-creation guard timestamp and MUST be bridge-local:
  /// the vanished-session reconcile compares it against a locally-captured
  /// fetch-start time to protect rows created during an in-flight fetch, so a
  /// backend-domain value here (skewed behind the local clock) could get a
  /// freshly-created session's row wrongly reconcile-deleted. [activityAt] may
  /// live in the backend's clock domain.
  /// Wrapped in a transaction so the project FK cannot fire.
  Future<void> ensureRootSessionActivity({
    required String sessionId,
    required String projectId,
    required int createdAt,
    required int activityAt,
    required bool advanceSeen,
    required bool isUserMessage,
  }) async {
    await _db.transaction(() async {
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSessionsIfMissing(
        pluginId: _pluginId,
        sessions: [(sessionId: sessionId, projectId: projectId, createdAt: createdAt, archivedAt: null)],
      );
      await _sessionDao.setActivityTimestamps(
        sessionId: sessionId,
        activityAt: activityAt,
        userMessageAt: isUserMessage ? activityAt : null,
        seenAt: advanceSeen ? activityAt : null,
      );
    });
  }

  /// Removes the persisted session row (used when a session is deleted live so
  /// a stale unseen row can't keep its project's aggregate bold). No-op if the
  /// row doesn't exist.
  Future<void> deleteSession({required String sessionId}) {
    return _sessionDao.deleteSession(sessionId: sessionId);
  }

  /// Removes the rows of sessions that vanished from the authoritative
  /// complete session list for [projectId] (deleted while the bridge was
  /// offline / backend-side without a `session.deleted` event), returning the
  /// deleted ids. Rows created at/after [createdBefore] (the time the fetch
  /// started) are kept — they are legitimately absent from the stale snapshot.
  /// Scoped to the active plugin: the list is only authoritative for the
  /// plugin that produced it, so rows another plugin recorded for the same
  /// project are never reconciled away.
  Future<List<String>> deleteSessionsNotIn({
    required String projectId,
    required List<String> keepSessionIds,
    required int createdBefore,
  }) {
    return _sessionDao.deleteSessionsForProjectNotIn(
      projectId: projectId,
      keepSessionIds: keepSessionIds,
      createdBefore: createdBefore,
      pluginId: _pluginId,
    );
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
