import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
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
      await projectsDao.insertProjectIfMissing(projectId: "X");
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

    test("persistSessionsForProject rolls back all inserts on failure", () async {
      final failingDao = _ThrowingSessionDao(db: db, throwOnCall: 3);
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
  });
}

Session _session({
  required String id,
  required String projectId,
  required int createdAt,
}) {
  return Session(
    id: id,
    projectID: projectId,
    directory: "/tmp/$projectId",
    parentID: null,
    title: null,
    time: SessionTime(created: createdAt, updated: createdAt, archived: null),
    summary: null,
    pullRequest: null,
  );
}

class _ThrowingSessionDao extends SessionDao {
  final int throwOnCall;
  int _calls = 0;

  _ThrowingSessionDao({required AppDatabase db, required this.throwOnCall}) : super(db);

  @override
  Future<void> insertSessionIfMissing({
    required String sessionId,
    required String projectId,
    required int createdAt,
  }) async {
    _calls++;
    if (_calls == throwOnCall) {
      throw StateError("boom");
    }
    await super.insertSessionIfMissing(
      sessionId: sessionId,
      projectId: projectId,
      createdAt: createdAt,
    );
  }
}
