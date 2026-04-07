import "package:sesori_shared/sesori_shared.dart" show Session;

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "../persistence/database.dart";

/// Coordinates minimal project/session persistence needed for FK-safe writes.
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
    await _projectsDao.insertProjectIfMissing(projectId: projectId);
  }

  Future<void> persistSessionsForProject({
    required String projectId,
    required List<Session> sessions,
  }) async {
    await _db.transaction(() async {
      await _projectsDao.insertProjectIfMissing(projectId: projectId);
      for (final session in sessions) {
        await _sessionDao.insertSessionIfMissing(
          sessionId: session.id,
          projectId: projectId,
          createdAt: session.time?.created ?? DateTime.now().millisecondsSinceEpoch,
        );
      }
    });
  }
}
