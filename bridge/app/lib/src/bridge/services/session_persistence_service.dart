import "package:sesori_shared/sesori_shared.dart" show Session;

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/database.dart";

/// Layer 3 service that owns the "ensure projects/sessions exist in the DB"
/// concern so handlers (Layer 4) and other repositories never need to call
/// DAOs (Layer 1) directly.
///
/// ## Architectural notes
///
/// - This service has direct Layer 1 dependencies ([ProjectsDao],
///   [SessionDao], [AppDatabase]). The bridge codebase pragmatically allows
///   Layer 3 → Layer 1 deps for persistence services — see
///   [WorktreeService] for the existing precedent.
/// - All write methods are transaction-wrapped to avoid N round-trips when
///   multiple inserts are needed.
/// - All inserts use `InsertMode.insertOrIgnore` semantics (via the
///   `insertProjectIfMissing` / `insertSessionIfMissing` DAO methods) so
///   user-set fields on existing rows (hidden, baseBranch, worktreePath,
///   branchName, etc.) are NEVER clobbered.
///
/// ## Public surface
///
/// - [ensureProject] — fast path: insert a single placeholder project row
///   if missing. Used by [CreateSessionHandler] (before insertSession) and
///   [GetSessionsHandler] (before reading sessions, to satisfy the v5 FK).
/// - [persistSessionsForProject] — bulk path: insert the project + each of
///   the given sessions inside one transaction. Called by
///   [GetSessionsHandler] post-fetch on a best-effort basis.
/// - [createSession] — full session insert: ensures the project exists then
///   inserts a session row with all worktree state in one transaction.
///   Called by Layer 4 handlers so they never mutate stored sessions through
///   a repository dependency.
/// - [deleteSession], [archiveSession], [unarchiveSession] — the remaining
///   stored-session lifecycle writes, kept here so routing stays a pure
///   consumer of repositories/services.
class SessionPersistenceService {
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final AppDatabase _db;

  SessionPersistenceService({
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required AppDatabase db,
  }) : _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _db = db;

  Future<void> ensureProject({required String projectId}) async {
    await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  }

  Future<void> persistSessionsForProject({
    required String projectId,
    required List<Session> sessions,
  }) async {
    await _db.transaction(() async {
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSessionsIfMissing(
        sessions: [
          for (final s in sessions)
            (
              sessionId: s.id,
              projectId: projectId,
              createdAt: s.time?.created ?? DateTime.now().millisecondsSinceEpoch,
              archivedAt: s.time?.archived,
            ),
        ],
      );
    });
  }

  /// Inserts a full session row with all worktree state. Wraps the project
  /// existence check + the session insert in a single transaction so the v5
  /// FK constraint cannot fire mid-write.
  ///
  /// Used by CreateSessionHandler to satisfy the architectural rule that
  /// handlers MUST NOT call Layer 1 (DAOs) directly.
  Future<void> createSession({
    required String sessionId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
  }) async {
    await _db.transaction(() async {
      await _projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      await _sessionDao.insertSession(
        sessionId: sessionId,
        projectId: projectId,
        isDedicated: isDedicated,
        createdAt: createdAt,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
      );
    });
  }

  Future<void> deleteSession({required String sessionId}) async {
    await _sessionDao.deleteSession(sessionId: sessionId);
  }

  Future<void> archiveSession({
    required String sessionId,
    required int archivedAt,
  }) async {
    await _sessionDao.setArchived(sessionId: sessionId, archivedAt: archivedAt);
  }

  Future<void> unarchiveSession({required String sessionId}) async {
    await _sessionDao.clearArchived(sessionId: sessionId);
  }
}
