import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../auth/access_token_provider.dart";
import "../../auth/token_refresher.dart";
import "../../push/completion_notifier.dart";
import "../../push/push_notification_client.dart";
import "../../push/push_notification_service.dart";
import "../../push/push_rate_limiter.dart";
import "../../push/push_session_state_tracker.dart";
import "../api/gh_cli_api.dart";
import "../api/git_cli_api.dart";
import "../bandwidth_tracker.dart";
import "../debug_server.dart";
import "../foundation/process_runner.dart";
import "../metadata_service.dart";
import "../models/bridge_config.dart";
import "../orchestrator.dart";
import "../persistence/database.dart";
import "../relay_client.dart";
import "../repositories/permission_repository.dart";
import "../repositories/pr_source_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/pull_request_repository.dart";
import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/session_persistence_service.dart";
import "../worktree_service.dart";

class BridgeRuntimeBuilder {
  final BridgeConfig config;
  final BridgePlugin plugin;
  final http.Client httpClient;
  final AccessTokenProvider accessTokenProvider;
  final TokenRefresher tokenRefresher;
  final AppDatabase database;
  final ProcessRunner processRunner;
  final FailureReporter failureReporter;

  const BridgeRuntimeBuilder({
    required this.config,
    required this.plugin,
    required this.httpClient,
    required this.accessTokenProvider,
    required this.tokenRefresher,
    required this.database,
    required this.processRunner,
    required this.failureReporter,
  });

  BridgeRuntime create() {
    final relayClient = RelayClient(
      relayURL: config.relayURL,
      accessTokenProvider: accessTokenProvider,
    );
    final metadataService = MetadataService(
      client: httpClient,
      baseUrl: config.authBackendURL,
      tokenRefresher: tokenRefresher,
    );
    final pushSessionStateTracker = PushSessionStateTracker();
    final pushNotificationService = PushNotificationService(
      client: PushNotificationClient(
        authBackendURL: config.authBackendURL,
        tokenRefreshManager: tokenRefresher,
      ),
      rateLimiter: PushRateLimiter(),
      tracker: pushSessionStateTracker,
      completionNotifier: CompletionNotifier(
        tracker: pushSessionStateTracker,
        debounceDuration: const Duration(milliseconds: 500),
      ),
    );

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
      prSource: PrSourceRepository(
        ghCli: GhCliApi(processRunner: processRunner),
        gitCli: GitCliApi(processRunner: processRunner),
      ),
      pullRequestRepository: pullRequestRepository,
      sessionRepository: sessionRepository,
    );
    final projectRepository = ProjectRepository(
      plugin: plugin,
      projectsDao: database.projectsDao,
    );
    final permissionRepository = PermissionRepository(plugin: plugin);
    final sessionPersistenceService = SessionPersistenceService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      db: database,
    );
    final worktreeService = WorktreeService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      processRunner: processRunner,
      gitPathExists: ({required String gitPath}) => FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound,
    );
    final session = Orchestrator(
      config: config,
      client: relayClient,
      plugin: plugin,
      metadataService: metadataService,
      pushNotificationService: pushNotificationService,
      tokenRefresher: tokenRefresher,
      projectsDao: database.projectsDao,
      failureReporter: failureReporter,
      prSyncService: prSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      permissionRepository: permissionRepository,
      sessionPersistenceService: sessionPersistenceService,
      worktreeService: worktreeService,
    ).create();

    return BridgeRuntime._(
      database: database,
      plugin: plugin,
      failureReporter: failureReporter,
      session: session,
    );
  }
}

class BridgeRuntime {
  final AppDatabase _database;
  final BridgePlugin _plugin;
  final FailureReporter _failureReporter;
  final OrchestratorSession session;

  BridgeRuntime._({
    required AppDatabase database,
    required BridgePlugin plugin,
    required FailureReporter failureReporter,
    required this.session,
  }) : _database = database,
       _plugin = plugin,
       _failureReporter = failureReporter;

  BandwidthTracker createBandwidthTracker() {
    return BandwidthTracker(bytesSent: session.bytesSent);
  }

  DebugServer createDebugServer({required int port}) {
    return DebugServer(
      plugin: _plugin,
      router: session.router,
      port: port,
      failureReporter: _failureReporter,
    );
  }

  Future<void> close() {
    return _database.close();
  }
}
