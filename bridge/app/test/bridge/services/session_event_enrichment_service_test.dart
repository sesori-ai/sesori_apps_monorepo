import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/log_failure_reporter.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/bridge/services/session_title_service.dart";
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
        unseenCalculator: const SessionUnseenCalculator(),
      );
      service = SessionEventEnrichmentService(
        sessionRepository: repository,
        sessionTitleService: SessionTitleService(sessionRepository: repository),
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
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
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
      final info = (result! as BridgeSseSessionCreated).info;
      expect(info["pullRequest"], isNotNull);
    });

    test("routes a session refresh through its stored owning project", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await service.enrich(
        const BridgeSseSessionsUpdated(
          sessionID: "s1",
          projectID: "/tmp/worktree",
        ),
      );

      expect(result, isA<BridgeSseSessionsUpdated>());
      expect((result! as BridgeSseSessionsUpdated).projectID, "p1");
    });

    test("drops created and updated events for a tombstoned session", () async {
      await db.sessionDao.insertSessionTombstone(
        sessionId: "gone",
        pluginId: plugin.id,
        deletedAt: 1,
      );
      const info = {
        "id": "gone",
        "projectID": "p1",
        "directory": "/repo",
        "parentID": null,
        "title": "Deleted",
        "time": null,
        "summary": null,
        "pullRequest": null,
      };

      expect(await service.enrich(const BridgeSseSessionCreated(info: info)), isNull);
      expect(await service.enrich(const BridgeSseSessionUpdated(info: info)), isNull);
    });

    group("derived-plugin title capture", () {
      late _FakeDerivedPlugin derivedPlugin;
      late SessionRepository derivedRepository;
      late SessionTitleService derivedTitleService;
      late SessionEventEnrichmentService derivedService;

      setUp(() {
        derivedPlugin = _FakeDerivedPlugin();
        derivedRepository = SessionRepository(
          plugin: derivedPlugin,
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        );
        derivedTitleService = SessionTitleService(sessionRepository: derivedRepository);
        derivedService = SessionEventEnrichmentService(
          sessionRepository: derivedRepository,
          sessionTitleService: derivedTitleService,
          failureReporter: LogFailureReporter(),
        );
      });

      Future<void> insertStored({required String? title}) async {
        await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
        await db.sessionDao.insertSession(
          pluginId: "codex",
          sessionId: "s1",
          projectId: "/repo",
          isDedicated: false,
          createdAt: 10,
          worktreePath: null,
          branchName: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
        );
        await db.sessionDao.setTitle(sessionId: "s1", title: title);
      }

      Map<String, dynamic> sessionInfo({required String? title}) => {
        "id": "s1",
        "projectID": "/repo",
        "directory": "/repo",
        "parentID": null,
        "title": title,
        "time": null,
        "summary": null,
        "pullRequest": null,
      };

      test("a session.updated persists its title before enriching", () async {
        await insertStored(title: "Old title");

        final result = await derivedService.enrich(
          BridgeSseSessionUpdated(info: sessionInfo(title: "Backend rename")),
        );

        // The wire payload carries the NEW title (captured before the
        // stored-wins overlay), and the stored copy now matches it.
        expect((result! as BridgeSseSessionUpdated).info["title"], "Backend rename");
        final stored = await db.sessionDao.getSession(sessionId: "s1");
        expect(stored?.title, "Backend rename");
      });

      test("an explicit null title on session.updated clears the stored copy", () async {
        await insertStored(title: "Old title");

        final result = await derivedService.enrich(
          BridgeSseSessionUpdated(info: sessionInfo(title: null)),
        );

        expect((result! as BridgeSseSessionUpdated).info["title"], isNull);
        final stored = await db.sessionDao.getSession(sessionId: "s1");
        expect(stored?.title, isNull);
      });

      test("a title update before row insertion is applied when the row arrives", () async {
        final result = await derivedService.enrich(
          BridgeSseSessionUpdated(info: sessionInfo(title: "Early title")),
        );
        expect((result! as BridgeSseSessionUpdated).info["title"], "Early title");
        expect(await db.sessionDao.getSession(sessionId: "s1"), isNull);

        await derivedRepository.insertStoredSession(
          sessionId: "s1",
          projectId: "/repo",
          isDedicated: false,
          createdAt: 10,
          worktreePath: null,
          branchName: null,
          baseBranch: null,
          baseCommit: null,
          agent: null,
          agentModel: null,
        );
        await derivedTitleService.applyPendingTitle(sessionId: "s1");

        final stored = await db.sessionDao.getSession(sessionId: "s1");
        expect(stored?.title, "Early title");
      });

      test("session.created does not capture titles (null means unknown, not cleared)", () async {
        await insertStored(title: "Kept title");

        final result = await derivedService.enrich(
          BridgeSseSessionCreated(info: sessionInfo(title: null)),
        );

        final stored = await db.sessionDao.getSession(sessionId: "s1");
        expect(stored?.title, "Kept title");
        // The stored-wins overlay even restores the title onto the payload.
        expect((result! as BridgeSseSessionCreated).info["title"], "Kept title");
      });
    });
  });
}

/// Minimal derive-style plugin for the title-capture tests: only the members
/// the enrichment path touches are real.
class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  @override
  String get id => "codex";

  @override
  String get launchDirectory => "/repo";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async =>
      const [];

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
