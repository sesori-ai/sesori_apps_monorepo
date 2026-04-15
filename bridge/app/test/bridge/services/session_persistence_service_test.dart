import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionPersistenceService", () {
    late AppDatabase db;
    late ProjectsDao projectsDao;
    late SessionDao sessionDao;
    late SessionPersistenceService service;

    setUp(() {
      db = createTestDatabase();
      projectsDao = db.projectsDao;
      sessionDao = db.sessionDao;
      service = SessionPersistenceService(
        projectsDao: projectsDao,
        sessionDao: sessionDao,
        db: db,
      );
    });

    tearDown(() => db.close());

    test("ensureProject inserts row if missing, preserves existing fields", () async {
      await service.ensureProject(projectId: "p1");

      var projects = await db.select(db.projectsTable).get();
      expect(projects, hasLength(1));
      expect(projects.single.projectId, equals("p1"));
      expect(projects.single.hidden, isFalse);

      await projectsDao.hideProject(projectId: "p1");
      await service.ensureProject(projectId: "p1");

      projects = await db.select(db.projectsTable).get();
      expect(projects, hasLength(1));
      expect(projects.single.hidden, isTrue);
    });

    test("persistSessionsForProject inserts project + all sessions in a transaction", () async {
      final sessions = List<Session>.generate(
        5,
        (index) => _session(
          id: "s$index",
          projectId: "X",
          createdAt: 1000 + index,
        ),
      );

      await service.persistSessionsForProject(projectId: "X", sessions: sessions);

      final projects = await db.select(db.projectsTable).get();
      final rows = await db.select(db.sessionTable).get();

      expect(projects.map((project) => project.projectId), equals(["X"]));
      expect(rows, hasLength(5));
      for (final session in sessions) {
        final row = rows.singleWhere((item) => item.sessionId == session.id);
        expect(row.projectId, equals("X"));
        expect(row.isDedicated, isFalse);
        expect(row.worktreePath, isNull);
        expect(row.createdAt, equals(session.time!.created));
      }
    });

    test("persistSessionsForProject is idempotent and preserves worktree state", () async {
      await projectsDao.insertProjectsIfMissing(projectIds: ["X"]);
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "X",
        isDedicated: true,
        createdAt: 123,
        worktreePath: "/tmp/wt",
        branchName: "main",
        baseBranch: null,
        baseCommit: null,
      );

      await service.persistSessionsForProject(
        projectId: "X",
        sessions: [_session(id: "s1", projectId: "X", createdAt: 999)],
      );

      final row = await sessionDao.getSession(sessionId: "s1");
      expect(row, isNotNull);
      expect(row?.worktreePath, equals("/tmp/wt"));
      expect(row?.branchName, equals("main"));
      expect(row?.isDedicated, isTrue);
      expect(row?.createdAt, equals(123));
    });

    test("createSession inserts a full session row with all fields and ensures project exists", () async {
      await service.createSession(
        sessionId: "sess-full",
        projectId: "proj-full",
        isDedicated: true,
        createdAt: 42000,
        worktreePath: "/tmp/wt/sess-full",
        branchName: "feat/full-session",
        baseBranch: "main",
        baseCommit: "deadbeef",
      );

      // (a) projects_table has the projectId
      final projects = await db.select(db.projectsTable).get();
      expect(projects, hasLength(1));
      expect(projects.single.projectId, equals("proj-full"));

      // (b) sessions_table has the session with all fields populated
      final rows = await db.select(db.sessionTable).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.sessionId, equals("sess-full"));
      expect(row.projectId, equals("proj-full"));
      expect(row.worktreePath, equals("/tmp/wt/sess-full"));
      expect(row.branchName, equals("feat/full-session"));
      expect(row.baseBranch, equals("main"));
      expect(row.baseCommit, equals("deadbeef"));
      expect(row.createdAt, equals(42000));

      // (c) isDedicated: true
      expect(row.isDedicated, isTrue);
    });

    test("persistSessionsForProject preserves archivedAt from session.time?.archived", () async {
      final sessions = [
        _session(id: "s-archived", projectId: "X", createdAt: 1000, archivedAt: 5555),
        _session(id: "s-active", projectId: "X", createdAt: 2000, archivedAt: null),
      ];

      await service.persistSessionsForProject(projectId: "X", sessions: sessions);

      final archived = await sessionDao.getSession(sessionId: "s-archived");
      expect(archived, isNotNull);
      expect(archived!.archivedAt, equals(5555));

      final active = await sessionDao.getSession(sessionId: "s-active");
      expect(active, isNotNull);
      expect(active!.archivedAt, isNull);
    });

    test("persistSessionsForProject rolls back all inserts on failure", () async {
      final failingDao = _ThrowingSessionDao(db: db, throwOnCall: 1);
      final failingService = SessionPersistenceService(
        projectsDao: projectsDao,
        sessionDao: failingDao,
        db: db,
      );

      await expectLater(
        () => failingService.persistSessionsForProject(
          projectId: "X",
          sessions: List<Session>.generate(
            5,
            (index) => _session(id: "s$index", projectId: "X", createdAt: index),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final projects = await db.select(db.projectsTable).get();
      final rows = await db.select(db.sessionTable).get();
      expect(projects, isEmpty);
      expect(rows, isEmpty);
    });

    test("deleteSession removes an existing stored session", () async {
      await projectsDao.insertProjectsIfMissing(projectIds: ["proj-delete"]);
      await sessionDao.insertSession(
        sessionId: "sess-delete",
        projectId: "proj-delete",
        isDedicated: true,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );

      await service.deleteSession(sessionId: "sess-delete");

      expect(await sessionDao.getSession(sessionId: "sess-delete"), isNull);
    });

    test("archiveSession sets archivedAt on an existing stored session", () async {
      await projectsDao.insertProjectsIfMissing(projectIds: ["proj-archive"]);
      await sessionDao.insertSession(
        sessionId: "sess-archive",
        projectId: "proj-archive",
        isDedicated: true,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );

      await service.archiveSession(sessionId: "sess-archive", archivedAt: 777);

      expect((await sessionDao.getSession(sessionId: "sess-archive"))?.archivedAt, equals(777));
    });

    test("unarchiveSession clears archivedAt on an existing stored session", () async {
      await projectsDao.insertProjectsIfMissing(projectIds: ["proj-unarchive"]);
      await sessionDao.insertSession(
        sessionId: "sess-unarchive",
        projectId: "proj-unarchive",
        isDedicated: true,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );
      await sessionDao.setArchived(sessionId: "sess-unarchive", archivedAt: 888);

      await service.unarchiveSession(sessionId: "sess-unarchive");

      expect((await sessionDao.getSession(sessionId: "sess-unarchive"))?.archivedAt, isNull);
    });
  });
}

Session _session({
  required String id,
  required String projectId,
  required int createdAt,
  int? archivedAt,
}) {
  return Session(
    id: id,
    projectID: projectId,
    directory: "/tmp/$projectId",
    parentID: null,
    title: null,
    branchName: null,
    time: SessionTime(created: createdAt, updated: createdAt, archived: archivedAt),
    summary: null,
    pullRequest: null,
  );
}

class _ThrowingSessionDao extends SessionDao {
  final int throwOnCall;
  int _calls = 0;

  _ThrowingSessionDao({required AppDatabase db, required this.throwOnCall}) : super(db);

  @override
  Future<void> insertSessionsIfMissing({
    required List<({String sessionId, String projectId, int createdAt, int? archivedAt})> sessions,
  }) async {
    _calls++;
    if (_calls == throwOnCall) {
      throw StateError("boom");
    }
    await super.insertSessionsIfMissing(sessions: sessions);
  }
}
