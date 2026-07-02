import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionDao.insertSession UPSERT", () {
    late AppDatabase db;
    late SessionDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.sessionDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("adopts the create flow's canonical project id over a placeholder", () async {
      // A placeholder row keyed to the plugin-supplied (pre-canonicalization)
      // worktree path, e.g. inserted by the unseen service from a live
      // session.created before the create handler persists the row.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo/.worktrees/s1"]);
      await dao.insertSessionsIfMissing(
        sessions: [(sessionId: "s1", projectId: "/repo/.worktrees/s1", createdAt: 100, archivedAt: null)],
      );

      // The create flow inserts the same session under the original project id
      // (its project row exists first, satisfying the FK).
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await dao.insertSession(
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 200,
        worktreePath: "/repo/.worktrees/s1",
        branchName: "s1",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final dto = await dao.getSession(sessionId: "s1");
      // The session is re-keyed to the canonical project, and created_at (which
      // a placeholder may have set) is preserved.
      expect(dto?.projectId, equals("/repo"));
      expect(dto?.createdAt, equals(100));
    });
  });
}
