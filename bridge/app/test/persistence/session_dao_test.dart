import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("SessionDao", () {
    late AppDatabase db;
    late SessionDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.sessionDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("insert then retrieve by sessionId returns matching row", () async {
      await dao.insertMapping(
        sessionId: "ses-1",
        projectId: "proj-1",
        worktreePath: "/tmp/worktrees/ses-1",
        branchName: "feat/my-feature",
      );

      final result = await dao.getWorktreeForSession(sessionId: "ses-1");

      expect(result, isNotNull);
      expect(result!.sessionId, equals("ses-1"));
      expect(result.projectId, equals("proj-1"));
      expect(result.worktreePath, equals("/tmp/worktrees/ses-1"));
      expect(result.branchName, equals("feat/my-feature"));
    });

    test("get non-existent sessionId returns null", () async {
      final result = await dao.getWorktreeForSession(sessionId: "does-not-exist");

      expect(result, isNull);
    });

    test("delete mapping then get returns null", () async {
      await dao.insertMapping(
        sessionId: "ses-2",
        projectId: "proj-2",
        worktreePath: "/tmp/worktrees/ses-2",
        branchName: "main",
      );

      await dao.deleteSession(sessionId: "ses-2");

      final result = await dao.getWorktreeForSession(sessionId: "ses-2");
      expect(result, isNull);
    });

    test("deleteSession is no-op for unknown sessionId", () async {
      await dao.insertMapping(
        sessionId: "ses-3",
        projectId: "proj-3",
        worktreePath: "/tmp/worktrees/ses-3",
        branchName: "develop",
      );

      await dao.deleteSession(sessionId: "does-not-exist");

      final result = await dao.getWorktreeForSession(sessionId: "ses-3");
      expect(result, isNotNull);
    });
  });
}
