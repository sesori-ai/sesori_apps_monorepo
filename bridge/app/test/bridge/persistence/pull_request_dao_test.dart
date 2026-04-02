import "package:sesori_bridge/src/bridge/persistence/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PullRequestDao", () {
    late AppDatabase db;
    late PullRequestDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.pullRequestDao;
    });

    tearDown(() async {
      await db.close();
    });

    group("upsertPr", () {
      test("inserts new PR", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: "MERGEABLE",
          reviewDecision: null,
          checkStatus: "SUCCESS",
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
        expect(prs[0].prNumber, equals(42));
        expect(prs[0].title, equals("Add authentication"));
      });

      test("updates existing PR with same projectId and branchName", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: "MERGEABLE",
          reviewDecision: null,
          checkStatus: "SUCCESS",
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication (updated)",
          state: "DRAFT",
          mergeableStatus: "CONFLICTING",
          reviewDecision: "CHANGES_REQUESTED",
          checkStatus: "FAILURE",
          sessionId: null,
          lastCheckedAt: 2000,
          createdAt: 900,
        );

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
        expect(prs[0].title, equals("Add authentication (updated)"));
        expect(prs[0].state, equals("DRAFT"));
        expect(prs[0].lastCheckedAt, equals(2000));
      });

      test("allows multiple PRs for same project with different branches", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/api",
          prNumber: 43,
          url: "https://github.com/org/repo/pull/43",
          title: "Add API endpoints",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(2));
      });
    });

    group("getPrsByProjectId", () {
      test("returns empty list for unknown project", () async {
        final prs = await dao.getPrsByProjectId(projectId: "unknown");
        expect(prs, isEmpty);
      });

      test("returns all PRs for a project", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/api",
          prNumber: 43,
          url: "https://github.com/org/repo/pull/43",
          title: "Add API endpoints",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-2",
          branchName: "feature/ui",
          prNumber: 1,
          url: "https://github.com/org/repo/pull/1",
          title: "Add UI",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(2));
        expect(prs.map((p) => p.prNumber), containsAll([42, 43]));
      });
    });

    group("getPrsBySessionIds", () {
      test("returns empty map for empty session IDs", () async {
        final result = await dao.getPrsBySessionIds(sessionIds: []);
        expect(result, isEmpty);
      });

      test("returns empty map for unknown session IDs", () async {
        final result = await dao.getPrsBySessionIds(sessionIds: ["unknown-1", "unknown-2"]);
        expect(result, isEmpty);
      });

      test("returns PRs mapped by session ID", () async {
        // Insert session records first
        await db.sessionDao.insertSession(
          sessionId: "session-1",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 900,
          worktreePath: "/path/to/worktree",
          branchName: "feature/auth",
          baseBranch: "main",
          baseCommit: "abc123",
        );

        await db.sessionDao.insertSession(
          sessionId: "session-2",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 900,
          worktreePath: "/path/to/worktree2",
          branchName: "feature/api",
          baseBranch: "main",
          baseCommit: "abc123",
        );

        // Insert PRs with session IDs
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: "session-1",
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/api",
          prNumber: 43,
          url: "https://github.com/org/repo/pull/43",
          title: "Add API endpoints",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: "session-2",
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final result = await dao.getPrsBySessionIds(sessionIds: ["session-1", "session-2"]);
        expect(result, hasLength(2));
        expect(result["session-1"]?.prNumber, equals(42));
        expect(result["session-2"]?.prNumber, equals(43));
      });

      test("ignores unknown session IDs in mixed list", () async {
        await db.sessionDao.insertSession(
          sessionId: "session-1",
          projectId: "proj-1",
          isDedicated: true,
          createdAt: 900,
          worktreePath: "/path/to/worktree",
          branchName: "feature/auth",
          baseBranch: "main",
          baseCommit: "abc123",
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: "session-1",
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final result = await dao.getPrsBySessionIds(sessionIds: ["session-1", "unknown"]);
        expect(result, hasLength(1));
        expect(result["session-1"]?.prNumber, equals(42));
      });
    });

    group("getActivePrsByProjectId", () {
      test("returns empty list for unknown project", () async {
        final prs = await dao.getActivePrsByProjectId(projectId: "unknown");
        expect(prs, isEmpty);
      });

      test("returns only OPEN PRs", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/api",
          prNumber: 43,
          url: "https://github.com/org/repo/pull/43",
          title: "Add API endpoints",
          state: "MERGED",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/ui",
          prNumber: 44,
          url: "https://github.com/org/repo/pull/44",
          title: "Add UI",
          state: "CLOSED",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final prs = await dao.getActivePrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
        expect(prs[0].prNumber, equals(42));
      });

      test("is case-insensitive for OPEN state", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "open",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        final prs = await dao.getActivePrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
      });
    });

    group("deletePr", () {
      test("deletes PR by projectId and branchName", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.deletePr(projectId: "proj-1", branchName: "feature/auth");

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, isEmpty);
      });

      test("is no-op for unknown PR", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.deletePr(projectId: "proj-1", branchName: "unknown");

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
      });

      test("only deletes specified PR, not others", () async {
        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/auth",
          prNumber: 42,
          url: "https://github.com/org/repo/pull/42",
          title: "Add authentication",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.upsertPr(
          projectId: "proj-1",
          branchName: "feature/api",
          prNumber: 43,
          url: "https://github.com/org/repo/pull/43",
          title: "Add API endpoints",
          state: "OPEN",
          mergeableStatus: null,
          reviewDecision: null,
          checkStatus: null,
          sessionId: null,
          lastCheckedAt: 1000,
          createdAt: 900,
        );

        await dao.deletePr(projectId: "proj-1", branchName: "feature/auth");

        final prs = await dao.getPrsByProjectId(projectId: "proj-1");
        expect(prs, hasLength(1));
        expect(prs[0].prNumber, equals(43));
      });
    });
  });
}
