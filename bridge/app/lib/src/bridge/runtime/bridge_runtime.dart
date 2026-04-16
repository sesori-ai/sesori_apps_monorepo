import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin, Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../auth/access_token_provider.dart";
import "../../auth/token_refresher.dart";
import "../../push/completion_notifier.dart";
import "../../push/push_notification_client.dart";
import "../../push/push_notification_content_service.dart";
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
import "../repositories/worktree_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/session_event_enrichment_service.dart";
import "../services/session_persistence_service.dart";
import "../services/worktree_service.dart";
import "bridge_shutdown_coordinator.dart";

class BridgeRuntime {
  final AppDatabase _database;
  final BridgePlugin _plugin;
  final FailureReporter _failureReporter;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;
  final OrchestratorSession session;

  BridgeRuntime({
    required AppDatabase database,
    required BridgePlugin plugin,
    required FailureReporter failureReporter,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
    required this.session,
  }) : _database = database,
       _plugin = plugin,
       _failureReporter = failureReporter,
       _sessionEventEnrichmentService = sessionEventEnrichmentService;

  static BridgeRuntime create({
    required BridgeConfig config,
    required BridgePlugin plugin,
    required http.Client httpClient,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required AppDatabase database,
    required ProcessRunner processRunner,
    required FailureReporter failureReporter,
  }) {
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
    );
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      failureReporter: failureReporter,
    );

    return BridgeRuntime(
      database: database,
      plugin: plugin,
      failureReporter: failureReporter,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      session: Orchestrator(
        config: config,
        client: RelayClient(relayURL: config.relayURL, accessTokenProvider: accessTokenProvider),
        plugin: plugin,
        metadataService: MetadataService(
          client: httpClient,
          baseUrl: config.authBackendURL,
          tokenRefresher: tokenRefresher,
        ),
        pushNotificationService: _createPushNotificationService(
          authBackendURL: config.authBackendURL,
          tokenRefresher: tokenRefresher,
        ),
        tokenRefresher: tokenRefresher,
        failureReporter: failureReporter,
        prSyncService: PrSyncService(
          prSource: PrSourceRepository(
            ghCli: GhCliApi(processRunner: processRunner),
            gitCli: GitCliApi(processRunner: processRunner, gitPathExists: _gitPathExists),
          ),
          pullRequestRepository: pullRequestRepository,
          sessionRepository: sessionRepository,
        ),
        sessionRepository: sessionRepository,
        projectRepository: ProjectRepository(plugin: plugin, projectsDao: database.projectsDao),
        permissionRepository: PermissionRepository(plugin: plugin),
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          db: database,
        ),
        worktreeService: WorktreeService(
          worktreeRepository: WorktreeRepository(
            projectsDao: database.projectsDao,
            sessionDao: database.sessionDao,
            gitApi: GitCliApi(processRunner: processRunner, gitPathExists: _gitPathExists),
          ),
        ),
        sessionEventEnrichmentService: sessionEventEnrichmentService,
      ).create(),
    );
  }

  BandwidthTracker createBandwidthTracker() {
    return BandwidthTracker(bytesSent: session.bytesSent);
  }

  DebugServer createDebugServer({required int port}) {
    return DebugServer(
      plugin: _plugin,
      router: session.router,
      port: port,
      failureReporter: _failureReporter,
      sessionEventEnrichmentService: _sessionEventEnrichmentService,
    );
  }

  Future<void> close() {
    return _database.close();
  }
}

Future<void> startDebugServerIfRequested({
  required int? debugPort,
  required BridgeRuntime runtime,
  required BridgeShutdownCoordinator shutdownCoordinator,
}) async {
  if (debugPort == null) {
    return;
  }

  final bandwidthTracker = runtime.createBandwidthTracker();
  shutdownCoordinator.add(disposable: bandwidthTracker.dispose);

  try {
    final debugServer = runtime.createDebugServer(port: debugPort);
    shutdownCoordinator.add(disposable: debugServer.stop);
    await debugServer.start();
  } catch (error) {
    Log.e("failed to start debug server: $error");
  }
}

void registerSignalHandlers({
  required OrchestratorSession session,
  required CompositeSubscription subscriptions,
}) {
  ProcessSignal.sigint.watch().listen((_) => unawaited(session.cancel())).addTo(subscriptions);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(session.cancel())).addTo(subscriptions);
  }
}

PushNotificationService _createPushNotificationService({
  required String authBackendURL,
  required TokenRefresher tokenRefresher,
}) {
  final tracker = PushSessionStateTracker();
  return PushNotificationService(
    client: PushNotificationClient(
      authBackendURL: authBackendURL,
      tokenRefreshManager: tokenRefresher,
    ),
    rateLimiter: PushRateLimiter(),
    tracker: tracker,
    completionNotifier: CompletionNotifier(
      tracker: tracker,
      debounceDuration: const Duration(milliseconds: 500),
    ),
    contentService: const PushNotificationContentService(),
  );
}

bool _gitPathExists({required String gitPath}) {
  return FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound;
}
