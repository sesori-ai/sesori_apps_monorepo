import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/log_failure_reporter.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("SessionEventEnrichmentService", () {
    late AppDatabase db;
    late FakeBridgePlugin plugin;
    late SessionRepository repository;
    late SessionEventEnrichmentService service;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      service = SessionEventEnrichmentService(
        sessionRepository: repository,
        failureReporter: LogFailureReporter(),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("falls back to original event when enrichment fails", () async {
      const event = BridgeSseSessionUpdated(
        info: {"id": "s1", "projectID": 42},
      );

      final result = await service.enrich(event);

      expect(result, same(event));
    });

    test("returns enriched session event when repository lookup succeeds", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 9,
          url: "https://github.com/org/repo/pull/9",
          title: "PR 9",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      final result = await service.enrich(
        const BridgeSseSessionCreated(
          info: {
            "id": "s1",
            "projectID": "p1",
            "directory": "/tmp/worktree",
            "parentID": null,
            "title": "session",
            "time": null,
            "summary": null,
            "pullRequest": null,
          },
        ),
      );

      expect(result, isA<BridgeSseSessionCreated>());
      final info = (result as BridgeSseSessionCreated).info;
      expect(info["pullRequest"], isNotNull);
    });
  });
}
