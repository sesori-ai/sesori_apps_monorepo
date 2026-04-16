import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_sessions_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionsHandler", () {
    late FakeBridgePlugin plugin;
    late FakeSessionDao sessionDao;
    late FakePullRequestRepository pullRequestRepository;
    late FakePrSyncService prSyncService;
    late FakeSessionRepository sessionRepository;
    late AppDatabase db;
    late SessionPersistenceService sessionPersistenceService;
    late GetSessionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      sessionDao = FakeSessionDao();
      pullRequestRepository = FakePullRequestRepository();
      prSyncService = FakePrSyncService();
      db = createTestDatabase();
      sessionRepository = FakeSessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        pullRequestRepository: pullRequestRepository,
      );
      sessionPersistenceService = SessionPersistenceService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        db: db,
      );
      handler = GetSessionsHandler(
        sessionRepository: sessionRepository,
        prSyncService: prSyncService,
        sessionPersistenceService: sessionPersistenceService,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /sessions", () {
      expect(handler.canHandle(makeRequest("POST", "/sessions")), isTrue);
    });

    test("does not handle GET /sessions", () {
      expect(handler.canHandle(makeRequest("GET", "/sessions")), isFalse);
    });

    test("does not handle GET /session/:id/message", () {
      expect(handler.canHandle(makeRequest("GET", "/session/abc/message")), isFalse);
    });

    test("throws 400 when projectId is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/sessions"),
          body: const SessionListRequest(projectId: "", start: null, limit: null),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("forwards projectId to plugin.getSessions", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/home/user/proj", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsWorktree, equals("/home/user/proj"));
    });

    test("forwards start and limit from body as ints", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: 5, limit: 20),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsStart, equals(5));
      expect(plugin.lastGetSessionsLimit, equals(20));
    });

    test("ensures project exists before calling SessionRepository", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "one",
          time: PluginSessionTime(created: 1, updated: 1, archived: null),
          summary: null,
        ),
        const PluginSession(
          id: "s2",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "two",
          time: PluginSessionTime(created: 2, updated: 2, archived: null),
          summary: null,
        ),
        const PluginSession(
          id: "s3",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "three",
          time: PluginSessionTime(created: 3, updated: 3, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: 2, limit: 3),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final projects = await db.select(db.projectsTable).get();
      expect(projects, hasLength(1));
      expect(projects.single.projectId, equals("project-1"));
      expect(sessionRepository.getSessionsCallCount, equals(1));
      expect(sessionRepository.lastGetSessionsArgs, equals((projectId: "project-1", start: 2, limit: 3)));
      expect(result.items.map((session) => session.id), equals(["s1", "s2", "s3"]));
    });

    test("persists sessions after successful fetch", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 10, updated: 10, archived: null),
          summary: null,
        ),
        const PluginSession(
          id: "s2",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 11, updated: 11, archived: null),
          summary: null,
        ),
        const PluginSession(
          id: "s3",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 12, updated: 12, archived: null),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final rows = await db.select(db.sessionTable).get();
      expect(rows.map((row) => row.sessionId).toList()..sort(), equals(["s1", "s2", "s3"]));
    });

    test("start and limit are null when absent from body", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsStart, isNull);
      expect(plugin.lastGetSessionsLimit, isNull);
    });

    test("returns typed SessionListResponse", () async {
      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(result, isA<SessionListResponse>());
    });

    test("maps PluginSession id, projectID, directory, and title", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "My session",
          time: null,
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final session = result.items.first;
      expect(session.id, equals("s1"));
      expect(session.projectID, equals("p1"));
      expect(session.directory, equals("/tmp"));
      expect(session.title, equals("My session"));
    });

    test("maps PluginSessionTime when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, isNull);
    });

    test("maps PluginSessionSummary when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
          summary: PluginSessionSummary(additions: 10, deletions: 3, files: 2),
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final summary = result.items.first.summary;
      expect(summary?.additions, equals(10));
      expect(summary?.deletions, equals(3));
      expect(summary?.files, equals(2));
    });

    test("time and summary are null when absent", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final session = result.items.first;
      expect(session.time, isNull);
      expect(session.summary, isNull);
    });

    test("overrides time.archived with DB archivedAt when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, equals(999));
    });

    test("keeps plugin time.archived when no DB record exists", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, equals(300));
    });

    test("sets time.archived to null when DB has null archivedAt", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, isNull);
    });

    test("handles multiple sessions with mixed DB/plugin archive status", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
        const PluginSession(
          id: "s2",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 400),
          summary: null,
        ),
        const PluginSession(
          id: "s3",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 500),
          summary: null,
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );
      sessionDao.setSession(
        const SessionDto(
          sessionId: "s2",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.length, equals(3));
      expect(result.items[0].time?.archived, equals(999));
      expect(result.items[1].time?.archived, isNull);
      expect(result.items[2].time?.archived, equals(500));
    });

    test("hasWorktree is true when DB record has worktreePath", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: null),
          summary: null,
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: "/repo/.worktrees/session-001",
          branchName: "session-001",
          isDedicated: true,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.first.hasWorktree, isTrue);
    });

    test("hasWorktree is false when DB record has null worktreePath", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: null),
          summary: null,
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.first.hasWorktree, isFalse);
    });

    test("hasWorktree is false when no DB record exists", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.first.hasWorktree, isFalse);
    });

    test("merges pull request metadata when session has a PR", () async {
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session with pr",
          time: null,
          summary: null,
        ),
      ];

      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          prNumber: 42,
          branchName: "feature/one",
          url: "https://github.com/org/repo/pull/42",
          title: "Add PR merge support",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final pr = result.items.single.pullRequest;
      expect(pr?.number, equals(42));
      expect(pr?.url, equals("https://github.com/org/repo/pull/42"));
      expect(pr?.title, equals("Add PR merge support"));
      expect(pr?.state, equals(PrState.open));
      expect(pr?.mergeableStatus, equals(PrMergeableStatus.mergeable));
      expect(pr?.reviewDecision, equals(PrReviewDecision.approved));
      expect(pr?.checkStatus, equals(PrCheckStatus.success));
    });

    test("preserves stored pull request metadata when plugin list replaces the session payload", () async {
      final realHandler = GetSessionsHandler(
        sessionRepository: SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
        ),
        prSyncService: prSyncService,
        sessionPersistenceService: sessionPersistenceService,
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/preserved-pr",
        baseBranch: null,
        baseCommit: null,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/preserved-pr",
          prNumber: 84,
          url: "https://github.com/org/repo/pull/84",
          title: "Stored PR survives replacement",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp/project",
          parentID: null,
          title: "replacement payload",
          time: PluginSessionTime(created: 100, updated: 200, archived: null),
          summary: null,
        ),
      ];

      final result = await realHandler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "p1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.title, equals("replacement payload"));
      expect(result.items.single.hasWorktree, isTrue);
      expect(result.items.single.pullRequest?.number, equals(84));
      expect(result.items.single.pullRequest?.title, equals("Stored PR survives replacement"));
    });

    test("keeps pullRequest null when session has no PR", () async {
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session without pr",
          time: null,
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.single.pullRequest, isNull);
    });

    test("merges PR data for mixed session batches", () async {
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "has pr",
          time: null,
          summary: null,
        ),
        PluginSession(
          id: "s2",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "no pr",
          time: null,
          summary: null,
        ),
      ];

      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          prNumber: 7,
          branchName: "feature/one",
          url: "https://github.com/org/repo/pull/7",
          title: "PR for one session",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items, hasLength(2));
      expect(result.items[0].pullRequest?.number, equals(7));
      expect(result.items[1].pullRequest, isNull);
    });

    test("triggers PR refresh with project path resolved from plugin.getProject", () async {
      plugin.currentProjectResult = const PluginProject(id: "/tmp/project");
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(prSyncService.calls, hasLength(1));
      expect(prSyncService.calls.single, equals((projectId: "project-1", projectPath: "/tmp/project")));
    });

    test("falls back to session directory when plugin.getProject fails", () async {
      plugin.throwOnGetProjectError = Exception("failed");
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "project-1",
          directory: "/tmp/fallback-project",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(prSyncService.calls, hasLength(1));
      expect(prSyncService.calls.single, equals((projectId: "project-1", projectPath: "/tmp/fallback-project")));
    });
  });
}
