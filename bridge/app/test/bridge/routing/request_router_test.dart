import "dart:convert";

import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/provider_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:sesori_bridge/src/bridge/routing/request_router.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("RequestRouter", () {
    late FakeBridgePlugin plugin;
    late FakeMetadataService metadataService;
    late RequestRouter router;
    late AppDatabase db;

    setUp(() {
      plugin = FakeBridgePlugin();
      metadataService = FakeMetadataService();
      db = createTestDatabase();
      final sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(pullRequestDao: db.pullRequestDao, projectsDao: db.projectsDao),
      );
      final projectRepository = ProjectRepository(plugin: plugin, projectsDao: db.projectsDao);
      final providerRepository = ProviderRepository(plugin: plugin);
      final permissionRepository = PermissionRepository(plugin: plugin);
      final sessionPersistenceService = SessionPersistenceService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        db: db,
      );
      final branchRepository = BranchRepository(
        gitCliApi: GitCliApi(processRunner: FakeProcessRunner(), gitPathExists: ({required String gitPath}) => true),
      );
      final worktreeService = WorktreeService(
        branchRepository: branchRepository,
        worktreeRepository: WorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: GitCliApi(
            processRunner: FakeProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
        ),
      );
      final sessionDiffsHandler = GetSessionDiffsHandler(
        sessionRepository: sessionRepository,
        processRunner: FakeProcessRunner(),
      );
      router = RequestRouter(
        plugin: plugin,
        metadataService: metadataService,
        sessionRepository: sessionRepository,
        prSyncService: FakePrSyncService(),
        projectRepository: projectRepository,
        providerRepository: providerRepository,
        permissionRepository: permissionRepository,
        sessionPersistenceService: sessionPersistenceService,
        worktreeService: worktreeService,
        branchRepository: branchRepository,
        sessionDiffsHandler: sessionDiffsHandler,
        onSessionAborted: (_) {},
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("routes GET /global/health to HealthCheckHandler", () async {
      final response = await router.route(makeRequest("GET", "/global/health"));
      expect(response.status, equals(200));
    });

    test("routes GET /projects to GetProjectsHandler", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", name: "P"),
      ];
      final response = await router.route(makeRequest("GET", "/projects"));
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data.length, equals(1));
    });

    test("routes POST /sessions to GetSessionsHandler", () async {
      final response = await router.route(
        makeRequest(
          "POST",
          "/sessions",
          body: jsonEncode({"projectId": "/tmp", "start": null, "limit": null}),
        ),
      );
      expect(response.status, equals(200));
    });

    test("POST /sessions without body returns 400", () async {
      final response = await router.route(makeRequest("POST", "/sessions"));
      expect(response.status, equals(400));
    });

    test("routes POST /session/messages to GetSessionMessagesHandler", () async {
      await router.route(
        makeRequest(
          "POST",
          "/session/messages",
          body: jsonEncode({"sessionId": "abc"}),
        ),
      );
      expect(plugin.lastGetMessagesSessionId, equals("abc"));
    });

    test("session id is extracted from body correctly", () async {
      await router.route(
        makeRequest(
          "POST",
          "/session/messages",
          body: jsonEncode({"sessionId": "sess-99"}),
        ),
      );
      expect(plugin.lastGetMessagesSessionId, equals("sess-99"));
    });

    test("pagination params are forwarded to handler", () async {
      await router.route(
        makeRequest(
          "POST",
          "/sessions",
          body: jsonEncode({"projectId": "/tmp", "start": 3, "limit": 7}),
        ),
      );
      expect(plugin.lastGetSessionsStart, equals(3));
      expect(plugin.lastGetSessionsLimit, equals(7));
    });

    test("unknown route returns 404", () async {
      final response = await router.route(makeRequest("GET", "/unknown"));

      expect(response.status, equals(404));
      expect(response.body, equals("no handler found for GET /unknown"));
    });

    test("GET /session/{id}/shell remains unsupported in RequestRouter", () async {
      final response = await router.route(makeRequest("GET", "/session/abc/shell"));

      expect(response.status, equals(404));
      expect(response.body, equals("no handler found for GET /session/abc/shell"));
    });

    test("routes POST /session/create to CreateSessionHandler", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        summary: null,
      );

      final response = await router.route(
        makeRequest(
          "POST",
          "/session/create",
          body: jsonEncode(
            const CreateSessionRequest(
              projectId: "/tmp",
              worktreeMode: WorktreeMode.none,
              selectedBranch: null,
              parts: [PromptPart.text(text: "Start")],
              agent: "architect",
              model: PromptModel(providerID: "openai", modelID: "gpt-5"),
            ).toJson(),
          ),
        ),
      );

      expect(response.status, equals(200));
      expect(plugin.lastCreateSessionDirectory, equals("/tmp"));
      expect(plugin.lastCreateSessionParentId, isNull);
      expect(plugin.lastCreateSessionProjectId, equals("/tmp"));
      expect(plugin.lastCreateSessionParts, equals([const PluginPromptPart.text(text: "Start")]));
      expect(plugin.lastCreateSessionAgent, equals("architect"));
      expect(plugin.lastCreateSessionModel, equals((providerID: "openai", modelID: "gpt-5")));
    });

    test("routes DELETE /session/delete to DeleteSessionHandler", () async {
      final response = await router.route(
        makeRequest(
          "DELETE",
          "/session/delete",
          body: jsonEncode({
            "sessionId": "abc",
            "deleteWorktree": false,
            "deleteBranch": false,
            "force": false,
          }),
        ),
      );
      expect(response.status, equals(200));
      expect(plugin.lastDeleteSessionId, equals("abc"));
    });

    test("routes GET /agent to GetAgentsHandler", () async {
      final response = await router.route(makeRequest("GET", "/agent"));
      expect(response.status, equals(200));
    });

    test("routes POST /session/questions to GetSessionQuestionsHandler", () async {
      final response = await router.route(
        makeRequest(
          "POST",
          "/session/questions",
          body: jsonEncode({"sessionId": "s-1"}),
        ),
      );
      expect(response.status, equals(200));
    });

    test("routes POST /project/questions to GetProjectQuestionsHandler", () async {
      final response = await router.route(
        makeRequest(
          "POST",
          "/project/questions",
          body: jsonEncode({"projectId": "/tmp/project"}),
        ),
      );
      expect(response.status, equals(200));
    });

    test("returns 500 when handler throws", () async {
      plugin.throwOnGetProjects = true;
      final response = await router.route(makeRequest("GET", "/projects"));
      expect(response.status, equals(500));
      expect(response.body, contains("Internal Server Error"));
    });

    test("returns plugin status when handler throws PluginApiException", () async {
      plugin.throwOnGetProjectsError = PluginApiException("/projects", 404);

      final response = await router.route(makeRequest("GET", "/projects"));

      expect(response.status, equals(404));
      expect(response.body, contains("PluginApiException"));
    });

    test("500 body contains the original error message", () async {
      plugin.throwOnHealthCheck = true;
      final response = await router.route(makeRequest("GET", "/global/health"));
      expect(response.status, equals(500));
      expect(response.body, contains("healthCheck error"));
    });

    test("integrates PR merge and background refresh trigger for session list", () async {
      plugin.currentProjectResult = const PluginProject(id: "/tmp/project");
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/tmp/project",
          directory: "/tmp/project",
          parentID: null,
          title: "session",
          time: null,
          summary: null,
        ),
      ];

      final fakePullRequestRepository = FakePullRequestRepository();
      fakePullRequestRepository.setPr(
        sessionId: "s1",
        pullRequest: const PullRequestDto(
          projectId: "/tmp/project",
          prNumber: 101,
          branchName: "feature/test",
          url: "https://github.com/org/repo/pull/101",
          title: "Integration PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      final spyPrSyncService = FakePrSyncService();
      final sessionRepository = FakeSessionRepository(
        plugin: plugin,
        sessionDao: FakeSessionDao(),
        pullRequestRepository: fakePullRequestRepository,
      );

      final projectRepository = ProjectRepository(plugin: plugin, projectsDao: db.projectsDao);
      final providerRepository = ProviderRepository(plugin: plugin);
      final permissionRepository = PermissionRepository(plugin: plugin);
      final sessionPersistenceService = SessionPersistenceService(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        db: db,
      );
      final branchRepository2 = BranchRepository(
        gitCliApi: GitCliApi(processRunner: FakeProcessRunner(), gitPathExists: ({required String gitPath}) => true),
      );
      final worktreeService = WorktreeService(
        branchRepository: branchRepository2,
        worktreeRepository: WorktreeRepository(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          gitApi: GitCliApi(
            processRunner: FakeProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
        ),
      );
      final sessionDiffsHandler = GetSessionDiffsHandler(
        sessionRepository: SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
        ),
        processRunner: FakeProcessRunner(),
      );

      router = RequestRouter(
        plugin: plugin,
        sessionRepository: sessionRepository,
        prSyncService: spyPrSyncService,
        metadataService: metadataService,
        projectRepository: projectRepository,
        providerRepository: providerRepository,
        permissionRepository: permissionRepository,
        sessionPersistenceService: sessionPersistenceService,
        worktreeService: worktreeService,
        branchRepository: branchRepository2,
        sessionDiffsHandler: sessionDiffsHandler,
        onSessionAborted: (_) {},
      );

      final response = await router.route(
        makeRequest(
          "POST",
          "/sessions",
          body: jsonEncode({"projectId": "/tmp/project", "start": null, "limit": null}),
        ),
      );

      final responseModel = SessionListResponse.fromJson(
        jsonDecode(response.body!) as Map<String, dynamic>,
      );

      expect(responseModel.items.single.pullRequest?.number, equals(101));
      expect(responseModel.items.single.pullRequest?.title, equals("Integration PR"));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(spyPrSyncService.calls, hasLength(1));
      expect(spyPrSyncService.calls.single, equals((projectId: "/tmp/project", projectPath: "/tmp/project")));
    });
  });
}
