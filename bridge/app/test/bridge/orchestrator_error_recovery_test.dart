import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_service.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "api/git_remote_api_test.dart";
import "routing/routing_test_helpers.dart";

void main() {
  group("OrchestratorSession SSE error recovery", () {
    test("stream continues after mapper throws", () async {
      final harness = await _TestHarness.start(
        plugin: _ThrowingSummaryPlugin(),
      );
      addTearDown(harness.close);

      await harness.waitForSubscription();

      harness.plugin.add(const BridgeSseProjectUpdated());
      harness.plugin.add(const BridgeSseProjectUpdated());

      await harness.waitForFailureCount(expected: 3);

      expect(
        harness.failureReporter.recordedIdentifiers,
        equals([
          "sse_projects_summary",
          "sse_projects_summary",
          "sse_projects_summary",
        ]),
      );
    });

    test("records failure with event-specific unique identifier", () async {
      final harness = await _TestHarness.start(
        plugin: _ThrowingSummaryPlugin(),
      );
      addTearDown(harness.close);

      await harness.waitForSubscription();

      harness.plugin.add(const BridgeSseProjectUpdated());

      await harness.waitForFailureCount(expected: 1);

      expect(
        harness.failureReporter.recordedIdentifiers.single,
        equals("sse_projects_summary"),
      );
    });
  });
}

class _TestHarness {
  final _ThrowingSummaryPlugin plugin;
  final CapturingFailureReporter failureReporter;
  final OrchestratorSession session;
  final Future<void> runFuture;
  final TestRelayServer relayServer;
  final AppDatabase database;

  _TestHarness._({
    required this.plugin,
    required this.failureReporter,
    required this.session,
    required this.runFuture,
    required this.relayServer,
    required this.database,
  });

  static Future<_TestHarness> start({
    required _ThrowingSummaryPlugin plugin,
  }) async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final failureReporter = CapturingFailureReporter();
    final pushService = _createPushNotificationService();
    final tokenRefresher = _FakeTokenRefresher();
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
    );

    final metadataService = FakeMetadataService();
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
    );
    final prSyncService = PrSyncService(
      prSource: _NoopPrSource(),
      pullRequestRepository: pullRequestRepository,
      sessionRepository: sessionRepository,
    );

    final projectRepository = ProjectRepository(plugin: plugin, projectsDao: database.projectsDao);
    final permissionRepository = PermissionRepository(plugin: plugin);
    final sessionPersistenceService = SessionPersistenceService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      db: database,
    );
    final failingProcessRunner = FakeProcessRunner((
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Duration timeout = const Duration(seconds: 15),
    }) async {
      return ProcessResult(0, 127, "", "command not found");
    });

    final worktreeService = WorktreeService(
      branchRepository: BranchRepository(gitCliApi: GitCliApi(processRunner: failingProcessRunner)),
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      processRunner: failingProcessRunner,
      gitPathExists: ({required String gitPath}) => true,
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
      ),
      client: relayClient,
      plugin: plugin,
      metadataService: metadataService,
      pushNotificationService: pushService,
      tokenRefresher: tokenRefresher,
      projectsDao: database.projectsDao,
      failureReporter: failureReporter,
      prSyncService: prSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      permissionRepository: permissionRepository,
      sessionPersistenceService: sessionPersistenceService,
      worktreeService: worktreeService,
    );

    final session = orchestrator.create();
    final runFuture = session.run();

    await relayServer.nextClient();

    return _TestHarness._(
      plugin: plugin,
      failureReporter: failureReporter,
      session: session,
      runFuture: runFuture,
      relayServer: relayServer,
      database: database,
    );
  }

  Future<void> waitForSubscription() async {
    final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (plugin.subscribeCount == 0) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for plugin event subscription");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> waitForFailureCount({required int expected}) async {
    final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (failureReporter.recordedIdentifiers.length < expected) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for failure reports");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> close() async {
    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  }
}

PushNotificationService _createPushNotificationService() {
  final tracker = PushSessionStateTracker();
  final completionNotifier = CompletionNotifier(tracker: tracker);
  return PushNotificationService(
    client: _NoopPushNotificationClient(),
    rateLimiter: PushRateLimiter(),
    tracker: tracker,
    completionNotifier: completionNotifier,
  );
}

class _ThrowingSummaryPlugin implements BridgePlugin {
  final _controller = StreamController<BridgeSseEvent>.broadcast();

  int subscribeCount = 0;

  @override
  String get id => "throwing-summary";

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      subscribeCount++;
      final sub = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void add(BridgeSseEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async => const PluginProject(id: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => [];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents() async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "");

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    throw StateError("summary mapping failed");
  }

  @override
  Future<PluginProvidersResult> getProviders({
    required bool connectedOnly,
  }) async => const PluginProvidersResult(providers: []);

  @override
  Future<void> dispose() async {}
}

class _NoopPushNotificationClient extends PushNotificationClient {
  _NoopPushNotificationClient()
    : super(
        authBackendURL: "http://127.0.0.1:8080",
        tokenRefreshManager: _FakeTokenRefresher(),
      );

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {}
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}

class _NoopPrSource implements PrSourceRepository {
  @override
  Future<bool> isGithubCliAvailable() async => false;

  @override
  Future<bool> isGithubCliAuthenticated() async => false;

  @override
  Future<bool> hasGitHubRemote({required String projectPath}) async => false;

  @override
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async => const <GhPullRequest>[];

  @override
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) async {
    throw StateError("getPrByNumber should not be called");
  }
}
