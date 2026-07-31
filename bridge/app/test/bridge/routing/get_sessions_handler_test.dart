import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

const _githubRepositoryIdentity = "org/repo";
const _githubLogin = "octocat";
final VerifiedGithubLogin _octocatLogin = VerifiedGithubLogin.tryParse(rawLogin: _githubLogin)!;

void main() {
  group("GetSessionsHandler", () {
    late FakeBridgePlugin plugin;
    late FakeSessionDao sessionDao;
    late FakePullRequestRepository pullRequestRepository;
    late FakePrSourceRepository prSource;
    late FakePrSyncService prSyncService;
    late FakeSessionRepository sessionRepository;
    late AppDatabase db;
    late GetSessionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      sessionDao = FakeSessionDao();
      pullRequestRepository = FakePullRequestRepository();
      prSource = FakePrSourceRepository();
      prSyncService = FakePrSyncService(prSource: prSource);
      db = createTestDatabase();
      sessionRepository = FakeSessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        pullRequestRepository: pullRequestRepository,
        persistenceDatabase: db,
      );
      handler = GetSessionsHandler(
        sessionRepository: sessionRepository,
        prSyncService: prSyncService,
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

    test("returns 404 for an unknown project without creating state or calling the plugin", () async {
      final realRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final realHandler = GetSessionsHandler(
        sessionRepository: realRepository,
        prSyncService: prSyncService,
      );

      final response = await realHandler.handleInternal(
        makeRequest(
          "POST",
          "/sessions",
          body: jsonEncode(const SessionListRequest(projectId: "/unknown", start: null, limit: null).toJson()),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(404));
      expect(await db.projectsDao.getProject(projectId: "/unknown"), isNull);
      expect(plugin.lastGetSessionsWorktree, isNull);
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

    test("persists the project and sessions after a successful repository fetch", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "one",
          time: PluginSessionTime(created: 1, updated: 1, archived: null),
        ),
        const PluginSession(
          id: "s2",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "two",
          time: PluginSessionTime(created: 2, updated: 2, archived: null),
        ),
        const PluginSession(
          id: "s3",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: "three",
          time: PluginSessionTime(created: 3, updated: 3, archived: null),
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
      expect(
        sessionRepository.lastGetSessionsArgs,
        equals((projectId: "project-1", start: 2, limit: 3, verifiedGithubLogin: null)),
      );
      expect(result.items.map((session) => session.id), equals(["s1", "s2", "s3"]));
    });

    test("does not swallow mandatory session publication failure", () async {
      final failure = StateError("session publication failed");
      sessionRepository.publicationError = failure;

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/sessions"),
          body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(same(failure)),
      );
      expect(plugin.lastGetSessionsWorktree, "project-1");
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
        ),
        const PluginSession(
          id: "s2",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 11, updated: 11, archived: null),
        ),
        const PluginSession(
          id: "s3",
          projectID: "project-1",
          directory: "/tmp/project-1",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 12, updated: 12, archived: null),
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

    test("time is null when absent", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
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
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s1",
          backendSessionId: "s1",
          projectId: "p1",
          parentSessionId: null,
          directory: "/tmp",
          worktreePath: null,
          branchName: null,
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
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
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s1",
          backendSessionId: "s1",
          projectId: "p1",
          parentSessionId: null,
          directory: "/tmp",
          worktreePath: null,
          branchName: null,
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
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
        ),
        const PluginSession(
          id: "s2",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 400),
        ),
        const PluginSession(
          id: "s3",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 500),
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s1",
          backendSessionId: "s1",
          projectId: "p1",
          parentSessionId: null,
          directory: "/tmp",
          worktreePath: null,
          branchName: null,
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
        ),
      );
      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s2",
          backendSessionId: "s2",
          projectId: "p1",
          parentSessionId: null,
          directory: "/tmp",
          worktreePath: null,
          branchName: null,
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
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
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s1",
          backendSessionId: "s1",
          projectId: "p1",
          parentSessionId: null,
          directory: "/repo/.worktrees/session-001",
          worktreePath: "/repo/.worktrees/session-001",
          branchName: "session-001",
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: true,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
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
        ),
      ];

      sessionDao.setSession(
        const SessionDto(
          pluginId: "opencode",
          sessionId: "s1",
          backendSessionId: "s1",
          projectId: "p1",
          parentSessionId: null,
          directory: "/tmp",
          worktreePath: null,
          branchName: null,
          currentBranchName: null,
          currentGithubRepositoryIdentity: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          createdAt: 100,
          updatedAt: 200,
          projectionUpdatedAt: 200,
          lastActivityAt: null,
          lastSeenAt: null,
          lastUserMessageAt: null,
          title: null,
          catalogTitle: null,
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
      prSource.authenticatedIdentityResult = _octocatLogin;
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session with pr",
          time: null,
        ),
      ];

      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
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
      expect(
        pullRequestRepository.getPrsBySessionIdsCalls.map((call) => call.verifiedGithubLogin),
        everyElement(same(_octocatLogin)),
      );
    });

    test("omits cached PR metadata when fresh identity is unavailable", () async {
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session with cached pr",
          time: null,
        ),
      ];
      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
          prNumber: 43,
          branchName: "feature/cached",
          url: "https://github.com/org/repo/pull/43",
          title: "Cached PR",
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
        body: const SessionListRequest(projectId: "p1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.single.pullRequest, isNull);
      expect(prSource.getAuthenticatedIdentityCallCount, 1);
      expect(pullRequestRepository.getPrsBySessionIdsCalls, isEmpty);
      expect(sessionRepository.lastGetSessionsArgs?.verifiedGithubLogin, isNull);
    });

    test("omits cached PR metadata when fresh identity verification fails", () async {
      prSource.authenticatedIdentityFailuresRemaining = 1;
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session with cached pr",
          time: null,
        ),
      ];
      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
          prNumber: 44,
          branchName: "feature/cached",
          url: "https://github.com/org/repo/pull/44",
          title: "Cached PR",
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
        body: const SessionListRequest(projectId: "p1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.single.pullRequest, isNull);
      expect(prSource.getAuthenticatedIdentityCallCount, 1);
      expect(pullRequestRepository.getPrsBySessionIdsCalls, isEmpty);
    });

    test("reverifies identity before mapping a completed PR refresh", () async {
      prSource.authenticatedIdentityResults = <VerifiedGithubLogin?>[
        null,
        _octocatLogin,
      ];
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session with refreshed pr",
          time: null,
        ),
      ];
      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
          prNumber: 45,
          branchName: "feature/refreshed",
          url: "https://github.com/org/repo/pull/45",
          title: "Refreshed PR",
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
        body: const SessionListRequest(
          projectId: "p1",
          start: null,
          limit: null,
          waitForPrData: true,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.single.pullRequest?.number, 45);
      expect(prSource.getAuthenticatedIdentityCallCount, 2);
      expect(
        sessionRepository.enrichSessionsVerifiedGithubLogins.map((login) => login?.login),
        equals(<String?>[null, _githubLogin]),
      );
      expect(
        pullRequestRepository.getPrsBySessionIdsCalls.single.verifiedGithubLogin.login,
        _githubLogin,
      );
    });

    test("reads catalog fields while preserving stored worktree and pull request metadata", () async {
      prSource.authenticatedIdentityResult = _octocatLogin;
      final realRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final realHandler = GetSessionsHandler(
        sessionRepository: realRepository,
        prSyncService: prSyncService,
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "fake",
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/preserved-pr",
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await db.projectsDao.setPrCacheGithubLogin(projectId: "p1", githubLogin: _githubLogin);
      await db.sessionDao.updatePullRequestScopes(
        updates: const [
          (
            sessionId: "s1",
            currentBranchName: "feature/preserved-pr",
            currentGithubRepositoryIdentity: _githubRepositoryIdentity,
          ),
        ],
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
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
        ),
      ];
      await db.sessionDao.updateObservedSessionProjection(
        sessionId: "s1",
        directory: "/tmp/project",
        catalogTitle: "replacement payload",
        updateCatalogTitle: true,
        updatedAt: 200,
        projectionUpdatedAt: 200,
      );

      final result = await realHandler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "p1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.title, equals("replacement payload"));
      expect(result.items.single.time?.created, 10);
      expect(result.items.single.time?.updated, 200);
      expect(result.items.single.hasWorktree, isTrue);
      expect(result.items.single.pullRequest?.number, equals(84));
      expect(result.items.single.pullRequest?.title, equals("Stored PR survives replacement"));
      final stored = await db.sessionDao.getSession(sessionId: "s1");
      expect(stored?.pluginId, "fake");
      expect(stored?.backendSessionId, "s1");
      expect(stored?.directory, "/tmp/project");
      expect(stored?.catalogTitle, "replacement payload");
      expect(stored?.createdAt, 10);
      expect(stored?.updatedAt, 200);
      expect(stored?.projectionUpdatedAt, 200);
      expect(stored?.worktreePath, "/tmp/worktree");
      expect(stored?.branchName, "feature/preserved-pr");
      expect(stored?.isDedicated, isTrue);
      expect(plugin.lastGetSessionsWorktree, isNull);
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
      prSource.authenticatedIdentityResult = _octocatLogin;
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "has pr",
          time: null,
        ),
        PluginSession(
          id: "s2",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "no pr",
          time: null,
        ),
      ];

      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
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

    test("triggers PR refresh in background when waitForPrData is false", () async {
      sessionRepository.projectPathResult = "/tmp/project";
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      // Allow the unawaited background refresh to run.
      await Future<void>.delayed(Duration.zero);

      expect(prSyncService.calls, hasLength(1));
      expect(prSyncService.calls.single, equals((projectId: "project-1", projectPath: "/tmp/project")));
    });

    test("triggers PR refresh with the stored catalog project path", () async {
      sessionRepository.projectPathResult = "/tmp/project";
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null, waitForPrData: true),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(prSyncService.calls, hasLength(1));
      expect(prSyncService.calls.single, equals((projectId: "project-1", projectPath: "/tmp/project")));
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("falls back to session directory when the catalog project path is missing", () async {
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "project-1",
          directory: "/tmp/fallback-project",
          parentID: null,
          title: null,
          time: null,
        ),
      ];

      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "project-1", start: null, limit: null, waitForPrData: true),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(prSyncService.calls, hasLength(1));
      expect(prSyncService.calls.single, equals((projectId: "project-1", projectPath: "/tmp/fallback-project")));
    });

    test("returns original sessions when PR refresh times out", () async {
      prSource.authenticatedIdentityResult = _octocatLogin;
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session one",
          time: null,
        ),
      ];
      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
          prNumber: 98,
          branchName: "feature/timeout",
          url: "https://github.com/org/repo/pull/98",
          title: "Timed-out PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );
      final slowPrSyncService = FakePrSyncService(
        delay: const Duration(seconds: 10),
        prSource: prSource,
      );
      final timeoutHandler = GetSessionsHandler(
        sessionRepository: sessionRepository,
        prSyncService: slowPrSyncService,
        prRefreshTimeout: const Duration(milliseconds: 50),
      );

      final result = await timeoutHandler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "p1", start: null, limit: null, waitForPrData: true),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.title, equals("session one"));
      expect(result.items.single.directory, equals("/tmp"));
      expect(result.items.single.pullRequest, isNull);
      expect(result.items.single.pullRequestHistory, isEmpty);
      expect(sessionRepository.getSessionsCallCount, equals(1));
      expect(
        pullRequestRepository.getPrsBySessionIdsCalls.map((call) => call.verifiedGithubLogin.login),
        everyElement(_githubLogin),
      );
    });

    test("enriches sessions when PR refresh succeeds within timeout", () async {
      prSource.authenticatedIdentityResult = _octocatLogin;
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "session one",
          time: null,
        ),
      ];
      pullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "p1",
          githubRepositoryIdentity: _githubRepositoryIdentity,
          githubLogin: _githubLogin,
          prNumber: 99,
          branchName: "feature/enriched",
          url: "https://github.com/org/repo/pull/99",
          title: "Enriched PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );
      final fastPrSyncService = FakePrSyncService(prSource: prSource);
      final enrichedHandler = GetSessionsHandler(
        sessionRepository: sessionRepository,
        prSyncService: fastPrSyncService,
      );

      final result = await enrichedHandler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "p1", start: null, limit: null, waitForPrData: true),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.title, equals("session one"));
      expect(result.items.single.pullRequest?.number, equals(99));
      expect(result.items.single.pullRequest?.mergeableStatus, equals(PrMergeableStatus.mergeable));
      expect(sessionRepository.getSessionsCallCount, equals(1));
    });
  });
}
