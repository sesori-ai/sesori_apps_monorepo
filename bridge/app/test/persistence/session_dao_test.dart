import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("SessionDao", () {
    late AppDatabase db;
    late SessionDao dao;
    late ProjectsDao projectsDao;

    setUp(() {
      db = createTestDatabase();
      dao = db.sessionDao;
      projectsDao = db.projectsDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("insert dedicated session then retrieve by sessionId returns matching row", () async {
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await dao.insertSession(
        sessionId: "ses-1",
        projectId: "proj-1",
        isDedicated: true,
        createdAt: createdAt,
        worktreePath: "/tmp/worktrees/ses-1",
        branchName: "feat/my-feature",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final result = await dao.getSession(sessionId: "ses-1");

      expect(result, isNotNull);
      expect(result!.sessionId, equals("ses-1"));
      expect(result.projectId, equals("proj-1"));
      expect(result.isDedicated, isTrue);
      expect(result.createdAt, equals(createdAt));
      expect(result.worktreePath, equals("/tmp/worktrees/ses-1"));
      expect(result.branchName, equals("feat/my-feature"));
      expect(result.baseBranch, equals("main"));
      expect(result.baseCommit, equals("abc123"));
      expect(result.archivedAt, isNull);
    });

    test("insert simple session supports null worktree fields", () async {
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await dao.insertSession(
        sessionId: "ses-simple",
        projectId: "proj-1",
        isDedicated: false,
        createdAt: createdAt,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );

      final result = await dao.getSession(sessionId: "ses-simple");

      expect(result, isNotNull);
      expect(result!.isDedicated, isFalse);
      expect(result.worktreePath, isNull);
      expect(result.branchName, isNull);
      expect(result.baseBranch, isNull);
      expect(result.baseCommit, isNull);
      expect(result.createdAt, equals(createdAt));
    });

    test("get non-existent sessionId returns null", () async {
      final result = await dao.getSession(sessionId: "does-not-exist");

      expect(result, isNull);
    });

    test("delete session then get returns null", () async {
      await dao.insertSession(
        sessionId: "ses-2",
        projectId: "proj-2",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-2",
        branchName: "main",
        baseBranch: "main",
        baseCommit: null,
      );

      await dao.deleteSession(sessionId: "ses-2");

      final result = await dao.getSession(sessionId: "ses-2");
      expect(result, isNull);
    });

    test("deleteSession is no-op for unknown sessionId", () async {
      await dao.insertSession(
        sessionId: "ses-3",
        projectId: "proj-3",
        isDedicated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: "/tmp/worktrees/ses-3",
        branchName: "develop",
        baseBranch: "develop",
        baseCommit: "commit-1",
      );

      await dao.deleteSession(sessionId: "does-not-exist");

      final result = await dao.getSession(sessionId: "ses-3");
      expect(result, isNotNull);
    });

    test("setArchived and clearArchived update archivedAt", () async {
      await dao.insertSession(
        sessionId: "ses-4",
        projectId: "proj-4",
        isDedicated: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );

      await dao.setArchived(sessionId: "ses-4", archivedAt: 1234567890);
      var result = await dao.getSession(sessionId: "ses-4");
      expect(result!.archivedAt, equals(1234567890));

      await dao.clearArchived(sessionId: "ses-4");
      result = await dao.getSession(sessionId: "ses-4");
      expect(result!.archivedAt, isNull);
    });

    test("getSessionsByProject and getSessionsByIds return expected sessions", () async {
      await dao.insertSession(
        sessionId: "ses-a",
        projectId: "proj-x",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp/worktrees/ses-a",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "sha-a",
      );
      await dao.insertSession(
        sessionId: "ses-b",
        projectId: "proj-x",
        isDedicated: false,
        createdAt: 2,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
      );
      await dao.insertSession(
        sessionId: "ses-c",
        projectId: "proj-y",
        isDedicated: true,
        createdAt: 3,
        worktreePath: "/tmp/worktrees/ses-c",
        branchName: "session-003",
        baseBranch: "develop",
        baseCommit: "sha-c",
      );

      final projectSessions = await dao.getSessionsByProject(projectId: "proj-x");
      expect(projectSessions.map((session) => session.sessionId), containsAll(<String>["ses-a", "ses-b"]));
      expect(projectSessions.map((session) => session.sessionId), isNot(contains("ses-c")));

      final byIds = await dao.getSessionsByIds(sessionIds: <String>["ses-a", "ses-c", "missing"]);
      expect(byIds.keys, containsAll(<String>["ses-a", "ses-c"]));
      expect(byIds.containsKey("missing"), isFalse);
      expect(byIds["ses-a"]!.projectId, equals("proj-x"));
      expect(byIds["ses-c"]!.projectId, equals("proj-y"));
    });

    group("getOtherActiveSessionsSharing", () {
      test("returns empty when both params are null", () async {
        await dao.insertSession(
          sessionId: "ses-1",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt",
          branchName: "branch-1",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-1",
          projectId: "proj-1",
          worktreePath: null,
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("finds other session sharing worktreePath", () async {
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
          branchName: "branch-b",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, hasLength(1));
        expect(result.first.sessionId, "ses-b");
      });

      test("finds other session sharing branchName", () async {
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "shared-branch",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-b",
          branchName: "shared-branch",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: null,
          branchName: "shared-branch",
        );

        expect(result, hasLength(1));
        expect(result.first.sessionId, "ses-b");
      });

      test("excludes the current session from results", () async {
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("excludes archived sessions", () async {
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/shared-wt",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/shared-wt",
          branchName: "branch-b",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.setArchived(sessionId: "ses-b", archivedAt: 99999);

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/shared-wt",
          branchName: null,
        );

        expect(result, isEmpty);
      });

      test("uses OR logic when both worktreePath and branchName provided", () async {
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-b",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-a",
          branchName: "branch-other",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-c",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 3,
          worktreePath: "/wt-other",
          branchName: "branch-a",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/wt-a",
          branchName: "branch-a",
        );

        expect(result, hasLength(2));
        expect(result.map((s) => s.sessionId), containsAll(["ses-b", "ses-c"]));
      });

      test("excludes sessions from other projects", () async {
        // Two sessions in different projects accidentally share the same branch
        // name. Cleanup of one must not be blocked by the other.
        await dao.insertSession(
          sessionId: "ses-a",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 1,
          worktreePath: "/wt-a",
          branchName: "session-001",
          baseBranch: "main",
          baseCommit: null,
        );
        await dao.insertSession(
          sessionId: "ses-b",
          projectId: "proj-2",
          isDedicated: true,
          createdAt: 2,
          worktreePath: "/wt-a",
          branchName: "session-001",
          baseBranch: "main",
          baseCommit: null,
        );

        final result = await dao.getOtherActiveSessionsSharing(
          sessionId: "ses-a",
          projectId: "proj-1",
          worktreePath: "/wt-a",
          branchName: "session-001",
        );

        expect(result, isEmpty);
      });
    });

    test(
      "insertSessionIfMissing inserts placeholder session with isDedicated=false and null nullable fields",
      () async {
        // Seed projects_table so FK constraints (post-v5) are satisfied.
        await projectsDao.hideProject(projectId: "proj-1");
        await projectsDao.unhideProject(projectId: "proj-1");

        await dao.insertSessionIfMissing(
          sessionId: "sess-1",
          projectId: "proj-1",
          createdAt: 1000,
        );

        final result = await dao.getSession(sessionId: "sess-1");

        expect(result, isNotNull);
        expect(result!.sessionId, equals("sess-1"));
        expect(result.projectId, equals("proj-1"));
        expect(result.isDedicated, isFalse);
        expect(result.createdAt, equals(1000));
        expect(result.worktreePath, isNull);
        expect(result.branchName, isNull);
        expect(result.archivedAt, isNull);
        expect(result.baseBranch, isNull);
        expect(result.baseCommit, isNull);
      },
    );

    test("insertSessionIfMissing is no-op when session exists, preserving worktreePath and branchName", () async {
      // Pre-insert a full session with worktree state.
      await dao.insertSession(
        sessionId: "sess-existing",
        projectId: "proj-1",
        isDedicated: true,
        createdAt: 500,
        worktreePath: "/tmp/wt",
        branchName: "feature-x",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      // insertSessionIfMissing must be a no-op — must NOT clobber existing fields.
      await dao.insertSessionIfMissing(
        sessionId: "sess-existing",
        projectId: "proj-1",
        createdAt: 999,
      );

      final result = await dao.getSession(sessionId: "sess-existing");

      expect(result, isNotNull);
      expect(result!.worktreePath, equals("/tmp/wt"));
      expect(result.branchName, equals("feature-x"));
      expect(result.isDedicated, isTrue);
      expect(result.createdAt, equals(500));
    });
  });
}
