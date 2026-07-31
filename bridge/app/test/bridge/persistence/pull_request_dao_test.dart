import "package:sesori_bridge/src/api/database/daos/pull_request_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("PullRequestDao", () {
    const githubLogin = "octocat";
    const githubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo";
    late AppDatabase db;
    late PullRequestDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.pullRequestDao;
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertProject({
      required String projectId,
      String? prCacheGithubLogin = "octocat",
    }) async {
      await db.projectsDao.setBaseBranch(projectId: projectId, baseBranch: null);
      await db.projectsDao.setPrCacheGithubLogin(
        projectId: projectId,
        githubLogin: prCacheGithubLogin,
      );
    }

    Future<void> insertSession({
      required String sessionId,
      required String projectId,
      required String branchName,
      String currentGithubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo",
    }) async {
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: sessionId,
        backendSessionId: sessionId,
        projectId: projectId,
        isDedicated: true,
        createdAt: 900,
        worktreePath: "/tmp/$sessionId",
        branchName: branchName,
        baseBranch: "main",
        baseCommit: "abc123",

        lastAgent: null,
        lastAgentModel: null,
      );
      await db.sessionDao.updatePullRequestScopes(
        updates: [
          (
            sessionId: sessionId,
            currentBranchName: branchName,
            currentGithubRepositoryIdentity: currentGithubRepositoryIdentity,
          ),
        ],
      );
    }

    Future<void> upsertPr({
      required String projectId,
      required String branchName,
      required int prNumber,
      required PrState state,
      required String title,
      String githubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo",
      String githubLogin = "octocat",
    }) {
      return dao.upsertPr(
        pullRequest: PullRequestDto(
          projectId: projectId,
          githubRepositoryIdentity: githubRepositoryIdentity,
          githubLogin: githubLogin,
          branchName: branchName,
          prNumber: prNumber,
          url: "https://github.com/$githubRepositoryIdentity/pull/$prNumber",
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

    test("upsertPr inserts and updates within one repository scope", () async {
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
      expect(prs.single.githubRepositoryIdentity, githubRepositoryIdentity);
      expect(prs.single.githubLogin, githubLogin);
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

    test("getPrsBySessionIds returns all PRs in the matching session scope", () async {
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

      final result = await dao.getPrsBySessionIds(
        sessionIds: <String>["session-1"],
        verifiedGithubLogin: githubLogin,
      );
      expect(result, hasLength(1));
      expect(result["session-1"], hasLength(2));
      expect(result["session-1"]!.map((pr) => pr.prNumber), unorderedEquals(<int>[100, 101]));
    });

    test("getPrsBySessionIds prevents cross-repository and account leakage", () async {
      await insertProject(projectId: "proj-1");
      await insertSession(
        sessionId: "session-1",
        projectId: "proj-1",
        branchName: "feature/auth",
      );
      await upsertPr(
        projectId: "proj-1",
        branchName: "feature/auth",
        prNumber: 100,
        state: PrState.open,
        title: "Matching PR",
      );
      await upsertPr(
        projectId: "proj-1",
        githubRepositoryIdentity: "other/repository",
        branchName: "feature/auth",
        prNumber: 101,
        state: PrState.open,
        title: "Other repository",
      );
      await upsertPr(
        projectId: "proj-1",
        githubLogin: "hubot",
        branchName: "feature/auth",
        prNumber: 102,
        state: PrState.open,
        title: "Other account",
      );

      final matchingAccount = await dao.getPrsBySessionIds(
        sessionIds: ["session-1"],
        verifiedGithubLogin: githubLogin,
      );
      final hiddenAfterAccountSwitch = await dao.getPrsBySessionIds(
        sessionIds: ["session-1"],
        verifiedGithubLogin: "hubot",
      );

      expect(matchingAccount["session-1"]?.map((pr) => pr.prNumber), [100]);
      expect(hiddenAfterAccountSwitch, isEmpty);

      await db.projectsDao.setPrCacheGithubLogin(
        projectId: "proj-1",
        githubLogin: "hubot",
      );
      final switchedAccount = await dao.getPrsBySessionIds(
        sessionIds: ["session-1"],
        verifiedGithubLogin: "hubot",
      );
      expect(switchedAccount["session-1"]?.map((pr) => pr.prNumber), [102]);
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

      final result = await dao.getPrsBySessionIds(
        sessionIds: <String>["session-1"],
        verifiedGithubLogin: githubLogin,
      );
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

      final active = await dao.getActivePrsByProjectId(
        projectId: "proj-1",
        githubRepositoryIdentity: githubRepositoryIdentity,
        githubLogin: githubLogin,
      );
      expect(active, hasLength(1));
      expect(active.single.prNumber, equals(1));
    });

    test("deletePr deletes by project, repository, and PR number", () async {
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
        githubRepositoryIdentity: "other/repository",
        branchName: "feature/b",
        prNumber: 1,
        state: PrState.open,
        title: "B",
      );

      await dao.deletePr(
        projectId: "proj-1",
        githubRepositoryIdentity: githubRepositoryIdentity,
        prNumber: 1,
      );

      final prs = await dao.getPrsByProjectId(projectId: "proj-1");
      expect(prs, hasLength(1));
      expect(prs.single.prNumber, equals(1));
      expect(prs.single.githubRepositoryIdentity, "other/repository");
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
