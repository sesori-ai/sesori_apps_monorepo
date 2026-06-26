import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../auth/access_token_provider.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/token_refresher.dart";
import "../../push/completion_notifier.dart";
import "../../push/completion_push_listener.dart";
import "../../push/maintenance_push_listener.dart";
import "../../push/push_dispatcher.dart";
import "../../push/push_maintenance_telemetry.dart" show PushMaintenanceTelemetryBuilder, readCurrentRssBytes;
import "../../push/push_notification_client.dart";
import "../../push/push_notification_content_builder.dart";
import "../../push/push_rate_limiter.dart";
import "../../push/push_session_state_tracker.dart";
import "../../server/services/bridge_restart_service.dart";
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
import "../repositories/question_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_unseen_calculator.dart";
import "../repositories/session_unseen_repository.dart";
import "../repositories/worktree_repository.dart";
import "../services/pr_sync_service.dart";
import "../services/session_event_enrichment_service.dart";
import "../services/session_persistence_service.dart";
import "../services/session_unseen_service.dart";
import "../services/session_view_tracker.dart";
import "../services/worktree_service.dart";
import "bridge_shutdown_coordinator.dart";

class BridgeRuntime {
  final AppDatabase _database;
  final BridgePluginApi _plugin;
  final FailureReporter _failureReporter;
  final SessionEventEnrichmentService _sessionEventEnrichmentService;
  final BridgeRestartService _restartService;
  // Owned here (composition root) because they are global/singleton and must
  // outlive any single OrchestratorSession (e.g. across a restart/reconnect).
  final SessionUnseenService _sessionUnseenService;
  final SessionViewTracker _sessionViewTracker;
  final OrchestratorSession session;

  BridgeRuntime({
    required AppDatabase database,
    required BridgePluginApi plugin,
    required FailureReporter failureReporter,
    required SessionEventEnrichmentService sessionEventEnrichmentService,
    required BridgeRestartService restartService,
    required SessionUnseenService sessionUnseenService,
    required SessionViewTracker sessionViewTracker,
    required this.session,
  }) : _database = database,
       _plugin = plugin,
       _failureReporter = failureReporter,
       _sessionEventEnrichmentService = sessionEventEnrichmentService,
       _restartService = restartService,
       _sessionUnseenService = sessionUnseenService,
       _sessionViewTracker = sessionViewTracker;

  static BridgeRuntime create({
    required BridgeConfig config,
    required BridgePluginApi plugin,
    required http.Client httpClient,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required AppDatabase database,
    required ProcessRunner processRunner,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
  }) {
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    const unseenCalculator = SessionUnseenCalculator();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
      unseenCalculator: unseenCalculator,
    );
    final projectRepository = ProjectRepository(
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: unseenCalculator,
    );
    final sessionUnseenRepository = SessionUnseenRepository(
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      db: database,
      calculator: unseenCalculator,
    );
    final sessionViewTracker = SessionViewTracker();
    final sessionUnseenService = SessionUnseenService(
      unseenRepository: sessionUnseenRepository,
      projectRepository: projectRepository,
      viewTracker: sessionViewTracker,
    );
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      failureReporter: failureReporter,
    );
    final pushTracker = PushSessionStateTracker(now: DateTime.now);
    final pushRateLimiter = PushRateLimiter(now: DateTime.now);
    final completionNotifier = CompletionNotifier(
      tracker: pushTracker,
      debounceDuration: const Duration(milliseconds: 500),
    );
    final pushDispatcher = PushDispatcher(
      client: PushNotificationClient(
        authBackendURL: config.authBackendURL,
        tokenRefreshManager: tokenRefresher,
        client: httpClient,
      ),
      rateLimiter: pushRateLimiter,
      tracker: pushTracker,
      contentBuilder: const PushNotificationContentBuilder(),
    );
    const pushContentBuilder = PushNotificationContentBuilder();
    final telemetryBuilder = PushMaintenanceTelemetryBuilder(
      completionNotifier: completionNotifier,
      rateLimiter: pushRateLimiter,
      rssBytesReader: readCurrentRssBytes,
    );

    return BridgeRuntime(
      database: database,
      plugin: plugin,
      failureReporter: failureReporter,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      restartService: restartService,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      session: Orchestrator(
        config: config,
        client: RelayClient(
          relayURL: config.relayURL,
          accessTokenProvider: accessTokenProvider,
          bridgeIdProvider: bridgeRegistrationService,
        ),
        plugin: plugin,
        metadataService: MetadataService(
          client: httpClient,
          baseUrl: config.authBackendURL,
          tokenRefresher: tokenRefresher,
        ),
        pushDispatcher: pushDispatcher,
        completionListener: CompletionPushListener(
          tracker: pushTracker,
          completionNotifier: completionNotifier,
          contentBuilder: pushContentBuilder,
          dispatcher: pushDispatcher,
        ),
        maintenanceListener: MaintenancePushListener(
          tracker: pushTracker,
          completionNotifier: completionNotifier,
          rateLimiter: pushRateLimiter,
          telemetryBuilder: telemetryBuilder,
        ),
        tokenRefresher: tokenRefresher,
        bridgeRegistrationService: bridgeRegistrationService,
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
        projectRepository: projectRepository,
        sessionUnseenService: sessionUnseenService,
        sessionViewTracker: sessionViewTracker,
        permissionRepository: PermissionRepository(plugin: plugin),
        questionRepository: QuestionRepository(plugin: plugin),
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          db: database,
        ),
        worktreeService: WorktreeService(
          worktreeRepository: WorktreeRepository(
            projectsDao: database.projectsDao,
            sessionDao: database.sessionDao,
            plugin: plugin,
            gitApi: GitCliApi(processRunner: processRunner, gitPathExists: _gitPathExists),
          ),
        ),
        sessionEventEnrichmentService: sessionEventEnrichmentService,
        restartService: restartService,
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
      restartService: _restartService,
      restartHandoff: session.handleRestartHandoff,
    );
  }

  Future<void> close() async {
    // Dispose the global unseen collaborators here (their owner), not in
    // OrchestratorSession (a consumer that may be recreated across restarts).
    // Each step is isolated so one failure cannot skip the remaining cleanup;
    // the first error is preserved and rethrown after everything has run.
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> step(Future<void> Function() dispose) async {
      try {
        await dispose();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await step(_sessionUnseenService.dispose);
    await step(_sessionViewTracker.dispose);
    await step(_database.close);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
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
  // SIGINT and SIGTERM are equivalent shutdown triggers: the first of either
  // requests a graceful cancel; a second shutdown signal of either kind is the
  // emergency escape hatch that forces an immediate exit. Counting both through
  // one counter keeps the two triggers symmetric (a prior SIGTERM must not let
  // the first SIGINT skip straight to force-exit, and vice versa).
  var shutdownSignalCount = 0;
  void handleShutdownSignal(String name) {
    shutdownSignalCount++;
    if (shutdownSignalCount >= 2) {
      Log.e("[shutdown] $name received (#$shutdownSignalCount) — forcing immediate exit");
      exit(1);
    }
    Log.i("[shutdown] $name received (#$shutdownSignalCount) — cancelling session");
    unawaited(session.cancel());
  }

  ProcessSignal.sigint.watch().listen((_) => handleShutdownSignal("SIGINT")).addTo(subscriptions);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => handleShutdownSignal("SIGTERM")).addTo(subscriptions);
  }
}

bool _gitPathExists({required String gitPath}) {
  return FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound;
}
