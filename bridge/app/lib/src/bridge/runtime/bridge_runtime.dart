import "dart:async";
import "dart:io";
import "dart:math";

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/database.dart";
import "../../auth/access_token_provider.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/token_refresher.dart";
import "../../control/control_status_notifier.dart";
import "../../listeners/command_dispatch_outcome_listener.dart";
import "../../listeners/plugin_command_timeline_listener.dart";
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
import "../../version.dart";
import "../api/filesystem_api.dart";
import "../api/gh_cli_api.dart";
import "../api/git_cli_api.dart";
import "../bandwidth_tracker.dart";
import "../debug_server.dart";
import "../foundation/filesystem_permission_validator.dart";
import "../foundation/process_runner.dart";
import "../foundation/uuid_v4_builder.dart";
import "../metadata_service.dart";
import "../models/bridge_config.dart";
import "../orchestrator.dart";
import "../relay_client.dart";
import "../repositories/agent_repository.dart";
import "../repositories/command_invocation_repository.dart";
import "../repositories/command_invocation_tracker.dart";
import "../repositories/filesystem_repository.dart";
import "../repositories/health_repository.dart";
import "../repositories/permission_repository.dart";
import "../repositories/pr_source_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/provider_repository.dart";
import "../repositories/pull_request_repository.dart";
import "../repositories/question_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_unseen_calculator.dart";
import "../repositories/session_unseen_repository.dart";
import "../repositories/worktree_repository.dart";
import "../services/command_dispatcher.dart";
import "../services/command_timeline_service.dart";
import "../services/pr_sync_service.dart";
import "../services/project_activity_service.dart";
import "../services/project_initialization_service.dart";
import "../services/session_creation_service.dart";
import "../services/session_event_enrichment_service.dart";
import "../services/session_mutation_dispatcher.dart";
import "../services/session_prompt_service.dart";
import "../services/session_unseen_service.dart";
import "../services/session_view_tracker.dart";
import "../services/worktree_service.dart";
import "bridge_shutdown_coordinator.dart";

class BridgeRuntime {
  final AppDatabase _database;
  final FailureReporter _failureReporter;
  final BridgeRestartService _restartService;
  // Owned here (composition root) because they are global/singleton and must
  // outlive any single OrchestratorSession (e.g. across a restart/reconnect).
  final SessionUnseenService _sessionUnseenService;
  final SessionViewTracker _sessionViewTracker;
  // Shared with the DebugServer so it mirrors the orchestrator's
  // projects-summary pipeline on the same instance.
  final SessionRepository _sessionRepository;
  final CommandDispatcher _commandDispatcher;
  final PluginCommandTimelineListener _pluginCommandTimelineListener;
  final CommandDispatchOutcomeListener _commandDispatchOutcomeListener;
  final OrchestratorSession session;

  BridgeRuntime({
    required AppDatabase database,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
    required SessionUnseenService sessionUnseenService,
    required SessionViewTracker sessionViewTracker,
    required SessionRepository sessionRepository,
    required CommandDispatcher commandDispatcher,
    required PluginCommandTimelineListener pluginCommandTimelineListener,
    required CommandDispatchOutcomeListener commandDispatchOutcomeListener,
    required this.session,
  }) : _database = database,
       _failureReporter = failureReporter,
       _restartService = restartService,
       _sessionUnseenService = sessionUnseenService,
       _sessionViewTracker = sessionViewTracker,
       _sessionRepository = sessionRepository,
       _commandDispatcher = commandDispatcher,
       _pluginCommandTimelineListener = pluginCommandTimelineListener,
       _commandDispatchOutcomeListener = commandDispatchOutcomeListener;

  static BridgeRuntime create({
    required BridgeConfig config,
    required BridgePluginApi plugin,
    // Constructed at the composition root (not here) so supervised mode can
    // wire its connectionState stream into the ControlStatusNotifier.
    required RelayClient relayClient,
    required http.Client httpClient,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required AppDatabase database,
    required ProcessRunner processRunner,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
    required bool filesystemAccessOk,
    // Supervised mode only; null in standalone (no control channel).
    required ControlStatusNotifier? statusNotifier,
  }) {
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    const unseenCalculator = SessionUnseenCalculator();
    final commandInvocationRepository = CommandInvocationRepository(
      dao: database.commandInvocationDao,
    );
    final commandInvocationTracker = CommandInvocationTracker();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      unseenCalculator: unseenCalculator,
    );
    final commandTimelineService = CommandTimelineService(
      sessionRepository: sessionRepository,
      invocationRepository: commandInvocationRepository,
      tracker: commandInvocationTracker,
    );
    final commandDispatcher = CommandDispatcher(
      sessionRepository: sessionRepository,
      invocationRepository: commandInvocationRepository,
      uuidBuilder: UuidV4Builder(random: Random.secure()),
      clock: const Clock(),
    );
    final sessionPromptService = SessionPromptService(
      sessionRepository: sessionRepository,
      commandDispatcher: commandDispatcher,
    );
    final gitCliApi = GitCliApi(
      processRunner: processRunner,
      gitPathExists: _gitPathExists,
    );
    final projectRepository = ProjectRepository(
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: unseenCalculator,
      filesystemApi: const FilesystemApi(),
      gitCliApi: gitCliApi,
    );
    final sessionUnseenRepository = SessionUnseenRepository(
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      db: database,
      calculator: unseenCalculator,
      plugin: plugin,
    );
    final sessionViewTracker = SessionViewTracker();
    final sessionUnseenService = SessionUnseenService(
      unseenRepository: sessionUnseenRepository,
      projectRepository: projectRepository,
      viewTracker: sessionViewTracker,
    );
    final sessionMutationDispatcher = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionMutationDispatcher,
      failureReporter: failureReporter,
    );
    final pluginCommandTimelineListener = PluginCommandTimelineListener(
      sessionRepository: sessionRepository,
      enrichmentService: sessionEventEnrichmentService,
      timelineService: commandTimelineService,
    );
    final commandDispatchOutcomeListener = CommandDispatchOutcomeListener(
      dispatcher: commandDispatcher,
      timelineService: commandTimelineService,
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

    final filesystemRepository = FilesystemRepository(
      filesystemApi: const FilesystemApi(),
      permissionValidator: const FilesystemPermissionValidator(),
    );
    final projectInitializationService = ProjectInitializationService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        plugin: plugin,
        gitApi: gitCliApi,
      ),
      filesystemRepository: filesystemRepository,
    );
    final projectActivityService = ProjectActivityService(
      projectRepository: projectRepository,
      now: () => DateTime.now().millisecondsSinceEpoch,
    );
    final healthRepository = HealthRepository(
      plugin: plugin,
      bridgeVersion: appVersion,
      filesystemAccessOk: filesystemAccessOk,
    );
    final providerRepository = ProviderRepository(plugin: plugin, projectsDao: database.projectsDao);
    final agentRepository = AgentRepository(plugin: plugin, projectsDao: database.projectsDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        plugin: plugin,
        gitApi: gitCliApi,
      ),
    );
    final sessionCreationService = SessionCreationService(
      metadataService: MetadataService(
        client: httpClient,
        baseUrl: config.authBackendURL,
        tokenRefresher: tokenRefresher,
      ),
      worktreeService: worktreeService,
      sessionRepository: sessionRepository,
      commandDispatcher: commandDispatcher,
      sessionMutationDispatcher: sessionMutationDispatcher,
    );

    return BridgeRuntime(
      database: database,
      failureReporter: failureReporter,
      restartService: restartService,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      sessionRepository: sessionRepository,
      commandDispatcher: commandDispatcher,
      pluginCommandTimelineListener: pluginCommandTimelineListener,
      commandDispatchOutcomeListener: commandDispatchOutcomeListener,
      session: Orchestrator(
        config: config,
        client: relayClient,
        plugin: plugin,
        sessionCreationService: sessionCreationService,
        sessionPromptService: sessionPromptService,
        commandTimelineService: commandTimelineService,
        pluginCommandTimelineListener: pluginCommandTimelineListener,
        commandDispatchOutcomeListener: commandDispatchOutcomeListener,
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
        accessTokenProvider: accessTokenProvider,
        tokenRefresher: tokenRefresher,
        bridgeRegistrationService: bridgeRegistrationService,
        failureReporter: failureReporter,
        prSyncService: PrSyncService(
          prSource: PrSourceRepository(
            ghCli: GhCliApi(processRunner: processRunner),
            gitCli: gitCliApi,
          ),
          pullRequestRepository: pullRequestRepository,
          sessionRepository: sessionRepository,
          clock: const Clock(),
        ),
        sessionRepository: sessionRepository,
        projectRepository: projectRepository,
        sessionUnseenService: sessionUnseenService,
        sessionViewTracker: sessionViewTracker,
        filesystemRepository: filesystemRepository,
        gitCliApi: gitCliApi,
        projectInitializationService: projectInitializationService,
        projectActivityService: projectActivityService,
        healthRepository: healthRepository,
        providerRepository: providerRepository,
        agentRepository: agentRepository,
        permissionRepository: PermissionRepository(plugin: plugin, sessionDao: database.sessionDao),
        questionRepository: QuestionRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
        ),
        worktreeService: worktreeService,
        sessionMutationDispatcher: sessionMutationDispatcher,
        restartService: restartService,
        statusNotifier: statusNotifier,
      ).create(),
    );
  }

  BandwidthTracker createBandwidthTracker() {
    return BandwidthTracker(bytesSent: session.bytesSent);
  }

  DebugServer createDebugServer({required int port}) {
    return DebugServer(
      router: session.router,
      port: port,
      failureReporter: _failureReporter,
      sessionRepository: _sessionRepository,
      pluginCommandTimelineListener: _pluginCommandTimelineListener,
      commandDispatchOutcomeListener: _commandDispatchOutcomeListener,
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
    await step(_pluginCommandTimelineListener.dispose);
    await step(_commandDispatchOutcomeListener.dispose);
    await step(_commandDispatcher.dispose);
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
