import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PullRequestRepository", () {
    test("upsertFromGhPr ensures project exists before inserting PR", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      // RED: This constructor call is missing `projectsDao` — it will fail to
      // compile once we add the required parameter in the GREEN phase.
      // For now it uses the OLD constructor to prove the test exists.
      final repo = PullRequestRepository(
        pullRequestDao: db.pullRequestDao,
        projectsDao: db.projectsDao,
      );

      const fakeGhPr = GhPullRequest(
        number: 42,
        url: "https://github.com/org/repo/pull/42",
        title: "Test PR",
        state: PrState.open,
        headRefName: "feature-branch",
        mergeable: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.reviewRequired,
        statusCheckRollup: PrCheckStatus.success,
      );

      // (a) No FK exception thrown — project row is created automatically.
      await expectLater(
        () => repo.upsertFromGhPr(
          projectId: "X",
          pr: fakeGhPr,
          createdAt: 1,
          lastCheckedAt: 2,
        ),
        returnsNormally,
      );

      // (b) projects_table has row "X".
      final projectRows = await db.select(db.projectsTable).get();
      expect(
        projectRows.map((r) => r.projectId).toList(),
        contains("X"),
        reason: "upsertFromGhPr must insert the project row if missing",
      );

      // (c) pull_requests_table has the PR row.
      final prRows = await db.pullRequestDao.getActivePrsByProjectId(projectId: "X");
      expect(prRows, hasLength(1));
      expect(prRows.first.prNumber, equals(42));
      expect(prRows.first.projectId, equals("X"));
    });
  });
}
