import "package:sesori_bridge/src/bridge/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    Future<void> insertProject({required String projectId}) {
      return db.projectsDao.setBaseBranch(projectId: projectId, baseBranch: null);
    }

    Future<void> insertSession({
      required String sessionId,
      required String projectId,
      required String branchName,
    }) {
      return db.sessionDao.insertSession(
        sessionId: sessionId,
        projectId: projectId,
        isDedicated: true,
        createdAt: 900,
        worktreePath: "/tmp/$sessionId",
        branchName: branchName,
        baseBranch: "main",
        baseCommit: "abc123",
      );
    }

    Future<void> upsertPr({
      required String projectId,
      required String branchName,
      required int prNumber,
      required PrState state,
      required String title,
    }) {
      return dao.upsertPr(
        pullRequest: PullRequestDto(
          projectId: projectId,
          branchName: branchName,
          prNumber: prNumber,
          url: "https://github.com/org/repo/pull/$prNumber",
          title: title,
          state: state,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1000,
          createdAt: 900,
        ),
      );
    }

    test("upsertPr inserts and updates by (projectId, prNumber)", () async {
      await insertProject(projectId: "proj-1");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 42,
        state: PrState.open,
        title: "Initial",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth-renamed",
        prNumber: 42,
        state: PrState.closed,
        title: "Updated",
      );

      final prs = await dao.getPrsByProjectId(projectId: "proj-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(42));
      expect(prs.single.branchName, equals("feature/auth-renamed"));
      expect(prs.single.title, equals("Updated"));
      expect(prs.single.state, equals(PrState.closed));
    });

    test("upsertPr allows branch reuse across different PR numbers", () async {
      await insertProject(projectId: "proj-1");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/reused",
        prNumber: 10,
        state: PrState.merged,
        title: "Old PR",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/reused",
        prNumber: 11,
        state: PrState.open,
        title: "New PR",
      );

      final prs = await dao.getPrsByProjectId(projectId: "proj-1");
      expect(prs, hasLength(2));
      expect(prs.map((pr) => pr.prNumber), containsAll(<int>[10, 11]));
    });

    test("getPrsBySessionIds joins on projectId+branch and returns all PRs grouped by session", () async {
      await insertProject(projectId: "proj-1");
      await insertSession(sessionId: "session-1", projectId: "proj-1", branchName: "feature/auth");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 100,
        state: PrState.merged,
        title: "Merged PR",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 101,
        state: PrState.open,
        title: "Open PR",
      );

      final result = await dao.getPrsBySessionIds(sessionIds: <String>["session-1"]);
      expect(result, hasLength(1));
      expect(result["session-1"], hasLength(2));
      expect(result["session-1"]!.map((pr) => pr.prNumber), unorderedEquals(<int>[100, 101]));
    });

    test("getPrsBySessionIds returns all PRs for a session (selection is repository's job)", () async {
      await insertProject(projectId: "proj-1");
      await insertSession(sessionId: "session-1", projectId: "proj-1", branchName: "feature/auth");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 100,
        state: PrState.merged,
        title: "Old PR",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 101,
        state: PrState.closed,
        title: "Newest non-open PR",
      );

      final result = await dao.getPrsBySessionIds(sessionIds: <String>["session-1"]);
      expect(result, hasLength(1));
      expect(result["session-1"], hasLength(2));
      expect(result["session-1"]!.map((pr) => pr.prNumber), unorderedEquals([100, 101]));
    });

    test("getActivePrsByProjectId returns only open pull requests", () async {
      await insertProject(projectId: "proj-1");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/open",
        prNumber: 1,
        state: PrState.open,
        title: "Open",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/closed",
        prNumber: 2,
        state: PrState.closed,
        title: "Closed",
      );

      final active = await dao.getActivePrsByProjectId(projectId: "proj-1");
      expect(active, hasLength(1));
      expect(active.single.prNumber, equals(1));
    });

    test("deletePr deletes by (projectId, prNumber)", () async {
      await insertProject(projectId: "proj-1");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/a",
        prNumber: 1,
        state: PrState.open,
        title: "A",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/b",
        prNumber: 2,
        state: PrState.open,
        title: "B",
      );

      await dao.deletePr(projectId: "proj-1", prNumber: 1);

      final prs = await dao.getPrsByProjectId(projectId: "proj-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(2));
    });

    test("deleting project cascades pull request rows", () async {
      await insertProject(projectId: "proj-1");
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 42,
        state: PrState.open,
        title: "PR",
      );

      await (db.delete(db.projectsTable)..where((t) => t.projectId.equals("proj-1"))).go();

      final prs = await dao.getPrsByProjectId(projectId: "proj-1");
      expect(prs, isEmpty);
    });
  });
}
