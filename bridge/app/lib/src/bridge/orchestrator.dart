import "dart:async";
import "dart:convert";
import "dart:io" show FileSystemEntity, FileSystemEntityType;
import "dart:math";
import "dart:typed_data";

import "package:clock/clock.dart";
import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/database.dart";
import "../auth/access_token_provider.dart";
import "../auth/bridge_registration_service.dart";
import "../auth/token_refresher.dart";
import "../control/control_status_notifier.dart";
import "../listeners/plugin_event_listener.dart";
import "../listeners/session_binding_commit_listener.dart";
import "../listeners/session_deletion_listener.dart";
import "../push/completion_notifier.dart";
import "../push/completion_push_listener.dart";
import "../push/maintenance_push_listener.dart";
import "../push/push_dispatcher.dart";
import "../push/push_maintenance_telemetry.dart" show PushMaintenanceTelemetryBuilder, readCurrentRssBytes;
import "../push/push_notification_client.dart";
import "../push/push_notification_content_builder.dart";
import "../push/push_rate_limiter.dart";
import "../push/push_session_state_tracker.dart";
import "../repositories/catalog_import_repository.dart";
import "../repositories/project_catalog_identity_calculator.dart";
import "../routing/cancel_catalog_import_handler.dart";
import "../routing/get_catalog_import_statuses_handler.dart";
import "../routing/get_plugin_setup_handler.dart";
import "../routing/get_plugins_handler.dart";
import "../routing/start_catalog_import_handler.dart";
import "../server/services/bridge_restart_service.dart";
import "../services/catalog_import_service.dart";
import "../services/plugin_lifecycle_service.dart";
import "../version.dart";
import "api/filesystem_api.dart";
import "api/gh_cli_api.dart";
import "api/git_cli_api.dart";
import "foundation/filesystem_permission_validator.dart";
import "foundation/process_runner.dart";
import "key_exchange.dart";
import "metadata_service.dart";
import "models/bridge_config.dart";
import "relay_client.dart";
import "repositories/agent_repository.dart";
import "repositories/filesystem_repository.dart";
import "repositories/health_repository.dart";
import "repositories/mappers/git_diff_output_mapper.dart";
import "repositories/mappers/session_event_mapper.dart";
import "repositories/permission_repository.dart";
import "repositories/pr_source_repository.dart";
import "repositories/project_repository.dart";
import "repositories/provider_repository.dart";
import "repositories/pull_request_repository.dart";
import "repositories/question_repository.dart";
import "repositories/session_diff_repository.dart";
import "repositories/session_repository.dart";
import "repositories/session_unseen_calculator.dart";
import "repositories/session_unseen_repository.dart";
import "repositories/trackers/session_event_tracker.dart";
import "repositories/worktree_repository.dart";
import "routing/abort_session_handler.dart";
import "routing/create_project_handler.dart";
import "routing/create_session_handler.dart";
import "routing/delete_session_handler.dart";
import "routing/filesystem_suggestions_handler.dart";
import "routing/get_agents_handler.dart";
import "routing/get_base_branch_handler.dart";
import "routing/get_child_sessions_handler.dart";
import "routing/get_commands_handler.dart";
import "routing/get_current_project_handler.dart";
import "routing/get_project_questions_handler.dart";
import "routing/get_projects_handler.dart";
import "routing/get_providers_handler.dart";
import "routing/get_session_diffs_handler.dart";
import "routing/get_session_handler.dart";
import "routing/get_session_messages_handler.dart";
import "routing/get_session_permissions_handler.dart";
import "routing/get_session_questions_handler.dart";
import "routing/get_session_statuses_handler.dart";
import "routing/get_sessions_handler.dart";
import "routing/handlers/mark_session_seen_handler.dart";
import "routing/health_check_handler.dart";
import "routing/hide_project_handler.dart";
import "routing/open_project_handler.dart";
import "routing/post_agents_handler.dart";
import "routing/reject_question_handler.dart";
import "routing/rename_project_handler.dart";
import "routing/rename_session_handler.dart";
import "routing/reply_to_permission_handler.dart";
import "routing/reply_to_question_handler.dart";
import "routing/request_router.dart";
import "routing/restart_bridge_handler.dart";
import "routing/send_prompt_handler.dart";
import "routing/set_base_branch_handler.dart";
import "routing/update_session_archive_status_handler.dart";
import "runtime/plugin_runtime.dart";
import "services/permission_auto_approval_service.dart";
import "services/pr_sync_service.dart";
import "services/project_activity_service.dart";
import "services/project_initialization_service.dart";
import "services/session_abort_service.dart";
import "services/session_creation_service.dart";
import "services/session_diff_service.dart";
import "services/session_event_dispatcher.dart";
import "services/session_event_service.dart";
import "services/session_lifecycle_service.dart";
import "services/session_mutation_dispatcher.dart";
import "services/session_prompt_service.dart";
import "services/session_unseen_service.dart";
import "services/session_view_tracker.dart";
import "services/worktree_service.dart";
import "sse/bridge_event_mapper.dart";
import "sse/sse_manager.dart";

typedef OrchestratorComposition = ({
  OrchestratorSession session,
  CatalogImportService catalogImportService,
  SessionRepository sessionRepository,
  SessionUnseenService sessionUnseenService,
  SessionViewTracker sessionViewTracker,
});

/// Factory that creates [OrchestratorSession] instances with all runtime
/// dependencies (room key, SSE manager) properly initialized.
class Orchestrator {
  final BridgeConfig config;
  final RelayClient _client;
  final String _legacyMissingPluginId;
  final PluginLifecycleService _pluginLifecycleService;
  final PluginRuntime _pluginRuntime;
  final AppDatabase _database;
  final http.Client _httpClient;
  final ProcessRunner _processRunner;
  final AccessTokenProvider _accessTokenProvider;
  final TokenRefresher _tokenRefresher;
  final BridgeRegistrationService _bridgeRegistrationService;
  final FailureReporter _failureReporter;
  final BridgeRestartService _restartService;
  final bool _filesystemAccessOk;
  final ControlStatusNotifier? _statusNotifier;

  Orchestrator({
    required this.config,
    required RelayClient client,
    required String legacyMissingPluginId,
    required PluginLifecycleService pluginLifecycleService,
    required PluginRuntime pluginRuntime,
    required AppDatabase database,
    required http.Client httpClient,
    required ProcessRunner processRunner,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
    required bool filesystemAccessOk,
    // Supervised mode only: owns the status-class pushes to the desktop GUI.
    // Standalone has no control channel, so this is null there.
    required ControlStatusNotifier? statusNotifier,
  }) : _client = client,
       _legacyMissingPluginId = legacyMissingPluginId,
       _pluginLifecycleService = pluginLifecycleService,
       _pluginRuntime = pluginRuntime,
       _database = database,
       _httpClient = httpClient,
       _processRunner = processRunner,
       _accessTokenProvider = accessTokenProvider,
       _tokenRefresher = tokenRefresher,
       _bridgeRegistrationService = bridgeRegistrationService,
       _failureReporter = failureReporter,
       _restartService = restartService,
       _filesystemAccessOk = filesystemAccessOk,
       _statusNotifier = statusNotifier;

  /// Creates a new session with a fresh room key and SSE manager.
  OrchestratorComposition create() {
    final pluginComposition = _pluginLifecycleService.compositionView;
    const aggregateSourceDeadline = Duration(seconds: 5);
    const unseenCalculator = SessionUnseenCalculator();
    const projectCatalogIdentityCalculator = ProjectCatalogIdentityCalculator();
    final gitCliApi = GitCliApi(processRunner: _processRunner, gitPathExists: _gitPathExists);
    final sessionRepository = SessionRepository(
      runtime: _pluginRuntime,
      bridgeDerivedProjectPluginIds: {
        for (final entry in pluginComposition.projectOwnershipById.entries)
          if (entry.value == PluginProjectOwnership.bridgeDerived) entry.key,
      },
      sessionDao: _database.sessionDao,
      projectsDao: _database.projectsDao,
      pullRequestDao: _database.pullRequestDao,
      unseenCalculator: unseenCalculator,
      projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
      aggregateSourceDeadline: aggregateSourceDeadline,
    );
    final projectRepository = ProjectRepository(
      operationalPlugins: pluginComposition.operationalPlugins,
      readDefaultEnabledPluginId: () => _pluginLifecycleService.compositionView.defaultEnabledPluginId,
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
      unseenCalculator: unseenCalculator,
      filesystemApi: const FilesystemApi(),
      gitCliApi: gitCliApi,
      projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
      aggregateSourceDeadline: aggregateSourceDeadline,
    );
    final sessionViewTracker = SessionViewTracker();
    final sessionUnseenService = SessionUnseenService(
      unseenRepository: SessionUnseenRepository(
        sessionDao: _database.sessionDao,
        calculator: unseenCalculator,
      ),
      projectRepository: projectRepository,
      viewTracker: sessionViewTracker,
    );
    final filesystemRepository = FilesystemRepository(
      filesystemApi: const FilesystemApi(),
      permissionValidator: const FilesystemPermissionValidator(),
    );
    final worktreeRepository = WorktreeRepository(
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
      gitApi: gitCliApi,
      runtime: _pluginRuntime,
    );
    final worktreeService = WorktreeService(worktreeRepository: worktreeRepository);
    final sessionMutationDispatcher = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final pushTracker = PushSessionStateTracker(now: clock.now);
    final pushRateLimiter = PushRateLimiter(now: clock.now);
    final completionNotifier = CompletionNotifier(
      tracker: pushTracker,
      debounceDuration: const Duration(milliseconds: 500),
    );
    final pushDispatcher = PushDispatcher(
      client: PushNotificationClient(
        authBackendURL: config.authBackendURL,
        tokenRefreshManager: _tokenRefresher,
        client: _httpClient,
      ),
      rateLimiter: pushRateLimiter,
      tracker: pushTracker,
      contentBuilder: const PushNotificationContentBuilder(),
    );
    const pushContentBuilder = PushNotificationContentBuilder();
    final completionListener = CompletionPushListener(
      tracker: pushTracker,
      completionNotifier: completionNotifier,
      contentBuilder: pushContentBuilder,
      dispatcher: pushDispatcher,
    );
    final maintenanceListener = MaintenancePushListener(
      tracker: pushTracker,
      completionNotifier: completionNotifier,
      rateLimiter: pushRateLimiter,
      telemetryBuilder: PushMaintenanceTelemetryBuilder(
        completionNotifier: completionNotifier,
        rateLimiter: pushRateLimiter,
        rssBytesReader: readCurrentRssBytes,
      ),
    );
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: _database.pullRequestDao,
      projectsDao: _database.projectsDao,
    );
    final prSyncService = PrSyncService(
      prSource: PrSourceRepository(
        ghCli: GhCliApi(processRunner: _processRunner),
        gitCli: gitCliApi,
      ),
      pullRequestRepository: pullRequestRepository,
      sessionRepository: sessionRepository,
      clock: const Clock(),
    );
    final projectActivityService = ProjectActivityService(
      projectRepository: projectRepository,
      now: () => DateTime.now().millisecondsSinceEpoch,
    );
    final permissionRepository = PermissionRepository(
      runtime: _pluginRuntime,
      sessionDao: _database.sessionDao,
    );
    final healthRepository = HealthRepository(
      bridgeVersion: appVersion,
      filesystemAccessOk: _filesystemAccessOk,
    );
    final providerRepository = ProviderRepository(
      runtime: _pluginRuntime,
      projectsDao: _database.projectsDao,
    );
    final agentRepository = AgentRepository(
      runtime: _pluginRuntime,
      projectsDao: _database.projectsDao,
      legacyPluginId: _legacyMissingPluginId,
    );
    final questionRepository = QuestionRepository(
      runtime: _pluginRuntime,
      sessionDao: _database.sessionDao,
      projectsDao: _database.projectsDao,
      legacyMissingPluginId: _legacyMissingPluginId,
      aggregateSourceDeadline: aggregateSourceDeadline,
    );
    final sessionCreationService = SessionCreationService(
      metadataService: MetadataService(
        client: _httpClient,
        baseUrl: config.authBackendURL,
        tokenRefresher: _tokenRefresher,
      ),
      worktreeService: worktreeService,
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionMutationDispatcher,
    );
    final projectInitializationService = ProjectInitializationService(
      worktreeRepository: worktreeRepository,
      filesystemRepository: filesystemRepository,
    );
    final roomKey = _generateRoomKey();
    final bytesSentController = StreamController<int>.broadcast();
    final localWireEventsController = StreamController<SesoriSseEvent>.broadcast();
    final sseManager = SSEManager(
      replayWindow: config.sseReplayWindow,
      onBytesSent: bytesSentController.add,
      failureReporter: _failureReporter,
    );
    sseManager.setRoomKey(roomKey);

    final catalogImportService = CatalogImportService(
      knownPluginIds: pluginComposition.knownPluginIds,
      enabledPluginIds: pluginComposition.eligiblePluginIds,
      emptyHydrationPolicies: {
        for (final entry in pluginComposition.projectOwnershipById.entries)
          if (pluginComposition.eligiblePluginIds.contains(entry.key))
            entry.key: switch (entry.value) {
              PluginProjectOwnership.native => CatalogEmptyHydrationPolicy.complete,
              PluginProjectOwnership.bridgeDerived => CatalogEmptyHydrationPolicy.retry,
            },
      },
      repository: CatalogImportRepository(
        runtime: _pluginRuntime,
        projectsDao: _database.projectsDao,
        sessionDao: _database.sessionDao,
        catalogHydrationsDao: _database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
      ),
    );
    final sessionPromptService = SessionPromptService(
      sessionRepository: sessionRepository,
    );
    final sessionLifecycleService = SessionLifecycleService(
      worktreeService: worktreeService,
      sessionRepository: sessionRepository,
      filesystemRepository: filesystemRepository,
    );
    final sessionAbortService = SessionAbortService(sessionRepository: sessionRepository);
    final sessionDiffService = SessionDiffService(
      sessionRepository: sessionRepository,
      sessionDiffRepository: SessionDiffRepository(
        gitCliApi: gitCliApi,
        outputMapper: const GitDiffOutputMapper(),
      ),
      filesystemRepository: filesystemRepository,
    );
    final sessionEventService = SessionEventService(
      sessionRepository: sessionRepository,
      pluginRuntime: _pluginRuntime,
      eventMapper: const SessionEventMapper(),
      eventTracker: SessionEventTracker(
        maxPendingEntriesPerPlugin: SessionEventTracker.defaultMaxPendingEntries,
      ),
      failureReporter: _failureReporter,
    );
    final sessionEventDispatcher = SessionEventDispatcher(
      sessionEventService: sessionEventService,
    );
    final permissionAutoApprovalService = PermissionAutoApprovalService(
      sessionRepository: sessionRepository,
      permissionRepository: permissionRepository,
    );
    final pluginEventListeners = [
      PluginEventListener(source: _pluginRuntime.backendEvents, dispatcher: sessionEventDispatcher),
    ];
    final sessionBindingCommitListener = SessionBindingCommitListener(
      source: sessionRepository.bindingCommits,
      dispatcher: sessionEventDispatcher,
    );
    final sessionDeletionListener = SessionDeletionListener(
      source: sessionMutationDispatcher.deletedSessions,
      dispatcher: sessionEventDispatcher,
    );
    final normalizedPluginEvents = sessionEventDispatcher.events.doOnListen(() {
      for (final listener in pluginEventListeners) {
        listener.start();
      }
      sessionBindingCommitListener.start();
      sessionDeletionListener.start();
    });
    final router = RequestRouter(
      handlers: [
        HealthCheckHandler(healthRepository: healthRepository),
        GetPluginSetupHandler(lifecycleService: _pluginLifecycleService),
        GetPluginsHandler(lifecycleService: _pluginLifecycleService),
        RestartBridgeHandler(restartService: _restartService),
        GetCurrentProjectHandler(projectRepository: projectRepository),
        GetProjectsHandler(projectActivityService: projectActivityService),
        GetCommandsHandler(sessionRepository: sessionRepository),
        GetSessionStatusesHandler(sessionRepository: sessionRepository),
        GetChildSessionsHandler(sessionRepository: sessionRepository),
        GetSessionHandler(sessionRepository),
        GetSessionMessagesHandler(sessionRepository: sessionRepository),
        GetSessionsHandler(
          sessionRepository: sessionRepository,
          prSyncService: prSyncService,
        ),
        CreateSessionHandler(sessionCreationService: sessionCreationService),
        RenameSessionHandler(sessionMutationDispatcher: sessionMutationDispatcher),
        MarkSessionSeenHandler(sessionUnseenService: sessionUnseenService),
        UpdateSessionArchiveStatusHandler(
          sessionLifecycleService: sessionLifecycleService,
          sessionUnseenService: sessionUnseenService,
        ),
        DeleteSessionHandler(
          sessionLifecycleService: sessionLifecycleService,
          sessionMutationDispatcher: sessionMutationDispatcher,
        ),
        SendPromptHandler(sessionPromptService: sessionPromptService),
        AbortSessionHandler(sessionAbortService: sessionAbortService),
        GetProvidersHandler(providerRepository),
        GetAgentsHandler(agentRepository),
        PostAgentsHandler(agentRepository),
        GetSessionQuestionsHandler(questionRepository: questionRepository),
        GetProjectQuestionsHandler(questionRepository: questionRepository),
        GetSessionPermissionsHandler(permissionRepository: permissionRepository),
        ReplyToQuestionHandler(questionRepository: questionRepository),
        RejectQuestionHandler(questionRepository: questionRepository),
        ReplyToPermissionHandler(permissionRepository: permissionRepository),
        RenameProjectHandler(projectRepository),
        CreateProjectHandler(
          projectInitializationService: projectInitializationService,
          projectActivityService: projectActivityService,
        ),
        OpenProjectHandler(
          filesystemRepository: filesystemRepository,
          projectInitializationService: projectInitializationService,
          projectActivityService: projectActivityService,
        ),
        HideProjectHandler(projectRepository: projectRepository),
        GetBaseBranchHandler(projectRepository: projectRepository),
        SetBaseBranchHandler(projectRepository: projectRepository),
        FilesystemSuggestionsHandler(filesystemRepository: filesystemRepository),
        StartCatalogImportHandler(service: catalogImportService),
        CancelCatalogImportHandler(service: catalogImportService),
        GetCatalogImportStatusesHandler(service: catalogImportService),
        GetSessionDiffsHandler(
          sessionDiffService: sessionDiffService,
        ),
      ],
    );

    final session = OrchestratorSession._(
      config: config,
      client: _client,
      pluginEvents: normalizedPluginEvents,
      pluginEventListeners: pluginEventListeners,
      sessionBindingCommitListener: sessionBindingCommitListener,
      sessionDeletionListener: sessionDeletionListener,
      sessionEventDispatcher: sessionEventDispatcher,
      pluginRuntime: _pluginRuntime,
      pushDispatcher: pushDispatcher,
      completionListener: completionListener,
      maintenanceListener: maintenanceListener,
      accessTokenProvider: _accessTokenProvider,
      tokenRefresher: _tokenRefresher,
      bridgeRegistrationService: _bridgeRegistrationService,
      roomKey: roomKey,
      sseManager: sseManager,
      router: router,
      mapper: BridgeEventMapper(failureReporter: _failureReporter),
      sessionPromptService: sessionPromptService,
      catalogImportProgress: catalogImportService.progress,
      localWireEventsController: localWireEventsController,
      bytesSentController: bytesSentController,
      failureReporter: _failureReporter,
      sessionRepository: sessionRepository,
      prSyncService: prSyncService,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      projectActivityService: projectActivityService,
      permissionAutoApprovalService: permissionAutoApprovalService,
      sessionAbortService: sessionAbortService,
      sessionMutationDispatcher: sessionMutationDispatcher,
      restartService: _restartService,
      statusNotifier: _statusNotifier,
    );
    return (
      session: session,
      catalogImportService: catalogImportService,
      sessionRepository: sessionRepository,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
    );
  }

  static List<int> _generateRoomKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }
}

bool _gitPathExists({required String gitPath}) {
  return FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound;
}

/// A running bridge session with immutable runtime state.
///
/// Created by [Orchestrator.create]. Call [run] to start the relay loop
/// and [cancel] to shut down gracefully.
class OrchestratorSession {
  final BridgeConfig config;
  final RelayClient _client;
  final Stream<NormalizedSourcedBridgeEvent> _pluginEvents;
  final List<PluginEventListener> _pluginEventListeners;
  final SessionBindingCommitListener _sessionBindingCommitListener;
  final SessionDeletionListener _sessionDeletionListener;
  final SessionEventDispatcher _sessionEventDispatcher;
  final PluginRuntime _pluginRuntime;
  final List<int> _roomKey;
  final SSEManager _sseManager;
  final RequestRouter _router;
  final BridgeEventMapper _mapper;
  final PushDispatcher _pushDispatcher;
  final CompletionPushListener _completionListener;
  final MaintenancePushListener _maintenanceListener;
  final AccessTokenProvider _accessTokenProvider;
  final TokenRefresher _tokenRefresher;
  final BridgeRegistrationService _bridgeRegistrationService;
  final StreamController<int> _bytesSentController;
  final StreamController<SesoriSseEvent> _localWireEventsController;
  final FailureReporter _failureReporter;
  final PrSyncService _prSyncService;
  final SessionUnseenService _sessionUnseenService;
  final SessionViewTracker _sessionViewTracker;
  final SessionRepository _sessionRepository;
  final PermissionAutoApprovalService _permissionAutoApprovalService;
  final SessionMutationDispatcher _sessionMutationDispatcher;
  final SessionAbortService _sessionAbortService;
  final SessionPromptService _sessionPromptService;
  // ignore: cancel_subscriptions - cancelled by the failure-isolated session drain.
  final CompositeSubscription _promptDefaultsSubscriptions = CompositeSubscription();
  // ignore: cancel_subscriptions - cancelled by the failure-isolated session drain.
  final CompositeSubscription _catalogImportSubscriptions = CompositeSubscription();
  final ProjectActivityService _projectActivityService;
  final BridgeRestartService _restartService;
  final ControlStatusNotifier? _statusNotifier;
  // ignore: cancel_subscriptions - cancelled by the failure-isolated session drain.
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final Map<String, Future<void>> _pluginEventProcessingTails = <String, Future<void>>{};
  Future<void> _projectsSummaryTail = Future<void>.value();
  final Random _backoffJitter = Random();

  bool _cancelled = false;
  Object? _beginShutdownError;
  StackTrace? _beginShutdownStackTrace;

  /// Guards [handleRestartHandoff] so concurrent relay + debug restart triggers
  /// spawn at most one successor.
  bool _restartHandoffStarted = false;

  /// When the first [cancel] was requested. Used only for shutdown timing
  /// diagnostics (the logger emits no timestamps, so durations are explicit).
  DateTime? _cancelRequestedAt;

  /// Label ("METHOD path") of the relay request currently being routed, or
  /// `null` when the read loop is idle. Surfaces which in-flight request is
  /// blocking the read loop when a shutdown is requested mid-route.
  String? _inFlightRequestLabel;

  /// Completes when [cancel] is first called. Allows in-flight request routing
  /// to abandon a response instead of awaiting an OpenCode HTTP call that has
  /// outlived the relay session.
  final Completer<void> _shutdownCompleter = Completer<void>();

  OrchestratorSession._({
    required this.config,
    required RelayClient client,
    required Stream<NormalizedSourcedBridgeEvent> pluginEvents,
    required List<PluginEventListener> pluginEventListeners,
    required SessionBindingCommitListener sessionBindingCommitListener,
    required SessionDeletionListener sessionDeletionListener,
    required SessionEventDispatcher sessionEventDispatcher,
    required PluginRuntime pluginRuntime,
    required PushDispatcher pushDispatcher,
    required CompletionPushListener completionListener,
    required MaintenancePushListener maintenanceListener,
    required AccessTokenProvider accessTokenProvider,
    required TokenRefresher tokenRefresher,
    required BridgeRegistrationService bridgeRegistrationService,
    required List<int> roomKey,
    required SSEManager sseManager,
    required RequestRouter router,
    required BridgeEventMapper mapper,
    required SessionPromptService sessionPromptService,
    required Stream<CatalogImportProgress> catalogImportProgress,
    required StreamController<int> bytesSentController,
    required StreamController<SesoriSseEvent> localWireEventsController,
    required FailureReporter failureReporter,
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    required SessionUnseenService sessionUnseenService,
    required SessionViewTracker sessionViewTracker,
    required ProjectActivityService projectActivityService,
    required PermissionAutoApprovalService permissionAutoApprovalService,
    required SessionAbortService sessionAbortService,
    required SessionMutationDispatcher sessionMutationDispatcher,
    required BridgeRestartService restartService,
    required ControlStatusNotifier? statusNotifier,
  }) : _client = client,
       _pluginEvents = pluginEvents,
       _pluginEventListeners = pluginEventListeners,
       _sessionBindingCommitListener = sessionBindingCommitListener,
       _sessionDeletionListener = sessionDeletionListener,
       _sessionEventDispatcher = sessionEventDispatcher,
       _pluginRuntime = pluginRuntime,
       _pushDispatcher = pushDispatcher,
       _completionListener = completionListener,
       _maintenanceListener = maintenanceListener,
       _accessTokenProvider = accessTokenProvider,
       _tokenRefresher = tokenRefresher,
       _bridgeRegistrationService = bridgeRegistrationService,
       _roomKey = roomKey,
       _sseManager = sseManager,
       _router = router,
       _mapper = mapper,
       _sessionPromptService = sessionPromptService,
       _bytesSentController = bytesSentController,
       _localWireEventsController = localWireEventsController,
       _failureReporter = failureReporter,
       _prSyncService = prSyncService,
       _sessionUnseenService = sessionUnseenService,
       _sessionViewTracker = sessionViewTracker,
       _sessionRepository = sessionRepository,
       _permissionAutoApprovalService = permissionAutoApprovalService,
       _sessionMutationDispatcher = sessionMutationDispatcher,
       _sessionAbortService = sessionAbortService,
       _projectActivityService = projectActivityService,
       _restartService = restartService,
       _statusNotifier = statusNotifier {
    catalogImportProgress
        .listen((progress) {
          _enqueueWireEvent(SesoriSseEvent.catalogImportProgress(progress: progress));
        })
        .addTo(_catalogImportSubscriptions);
    _sessionPromptService.promptDefaultsChanges
        .listen((change) {
          _enqueueWireEvent(
            SesoriSseEvent.sessionPromptDefaultsChanged(
              sessionID: change.sessionId,
              promptDefaults: change.promptDefaults,
            ),
          );
        })
        .addTo(_promptDefaultsSubscriptions);
  }

  /// Broadcast stream of byte counts emitted each time data is sent to a phone.
  ///
  /// Includes both API responses and SSE events. Subscribe to this stream to
  /// track bandwidth (e.g. with [BandwidthTracker]).
  Stream<int> get bytesSent => _bytesSentController.stream;
  Stream<SesoriSseEvent> get localWireEvents => _localWireEventsController.stream;
  RequestRouter get router => _router;
  Future<void> drainRoutedMutations() => _sessionMutationDispatcher.drain();

  Future<void> run() async {
    final kxManager = KeyExchangeManager(_roomKey);
    final activePhones = <int, bool>{};

    Log.d("registering bridge with auth server...");
    await _bridgeRegistrationService.ensureRegistered();
    Log.d("bridge registered");

    try {
      Log.d("connecting to relay...");
      await _client.connect();
      Log.d("relay connected");

      _sessionAbortService.abortStartedSessions
          .listen(_completionListener.markSessionAbortPending)
          .addTo(_subscriptions);
      _sessionAbortService.abortedSessions.listen(_completionListener.markSessionAborted).addTo(_subscriptions);
      _sessionAbortService.abortFailedSessions.listen(_completionListener.clearPendingAbort).addTo(_subscriptions);
      _completionListener.start();
      _maintenanceListener.start();
      _projectActivityService.changes
          .listen((change) {
            final event = SesoriSseEvent.projectUpdated(
              projectID: change.projectId,
              updatedAt: change.updatedAt,
            );
            _enqueueWireEvent(event);
            _completionListener.handleSseEvent(event);
          })
          .addTo(_subscriptions);

      // Reconcile in one batch before publishing the startup baseline. Failure
      // is isolated so project activity cannot prevent the relay session from
      // starting.
      await _projectActivityService.reconcile(pluginId: null).catchError((Object e, StackTrace st) {
        Log.w("ProjectActivityService: startup reconciliation failed", e, st);
      });
      if (config.yolo) await _permissionAutoApprovalService.approvePending();
      final startupSummary = await _buildProjectsSummary();
      if (startupSummary != null) {
        _completionListener.handleSseEvent(startupSummary);
        if (startupSummary is SesoriProjectsSummary) {
          _statusNotifier?.handleProjectsSummary(summary: startupSummary);
        }
      }
      Log.d("subscribing to plugin event stream...");
      _pluginEvents
          .listen(
            (source) {
              unawaited(_processPluginEventInOrder(source));
            },
            onError: (Object e, StackTrace st) {
              Log.w("plugin event stream error: $e");
              unawaited(
                _failureReporter.recordFailure(
                  error: e,
                  stackTrace: st,
                  uniqueIdentifier: "bridge.plugin.events",
                  fatal: false,
                  reason: "plugin event stream failure",
                  information: const [],
                ),
              );
            },
            onDone: () {
              Log.w("plugin event stream closed");
            },
          )
          .addTo(_subscriptions);
      Log.d("plugin event stream subscribed");
      _prSyncService.prChanges
          .listen((String projectId) {
            _enqueueWireEvent(SesoriSseEvent.sessionsUpdated(projectID: projectId));
          })
          .addTo(_subscriptions);
      _sessionUnseenService.unseenChanges
          .listen((change) {
            _enqueueWireEvent(
              SesoriSseEvent.sessionUnseenChanged(
                projectID: change.projectId,
                sessionId: change.sessionId,
                unseen: change.unseen,
                projectHasUnseenChanges: change.projectHasUnseenChanges,
              ),
            );
          })
          .addTo(_subscriptions);
      // Live re-auth: when the token provider emits a token whose auth IDENTITY
      // differs from the one the relay socket is actually authenticated with
      // (supervised mode: the GUI pushed a token_update after an account switch;
      // standalone: a re-login as another user picked up by the next refresh),
      // drop the relay so the reconnect loop below re-authenticates on the fresh
      // token — the same path a relay-side disconnect drives, so both triggers
      // stay symmetric.
      //
      // Identity-gated on purpose: the relay validates the JWT once at connect
      // and never re-checks it for the lifetime of the socket, so a routine
      // same-user token rotation (TokenManager refreshing near expiry during
      // metadata generation or push sends, or the GUI pushing a routine refresh)
      // keeps the open socket fully valid. Dropping it would disconnect every
      // phone mid-flight for nothing — see [_requiresRelayReauth].
      _accessTokenProvider.tokenStream
          .where(_requiresRelayReauth)
          .listen((token) => unawaited(_reauthenticateRelay()))
          .addTo(_subscriptions);
    } catch (e) {
      throw Exception("failed to connect to relay: $e");
    }

    Console.message("Relay:  ${config.relayURL}");
    Console.message("Waiting for relay events...");

    try {
      while (!_cancelled) {
        try {
          await _runRelayLoop(_roomKey, kxManager, activePhones);
        } catch (e) {
          if (_cancelled) break;
          Log.w("relay loop ended: $e");
        }

        if (_cancelled) {
          break;
        }

        Log.w("Relay connection lost. Reconnecting...");
        _sseManager.orphanAll();
        activePhones.clear();
        // Every phone connection died with the relay link; drop their view
        // declarations so no session stays "watched" by a ghost connection.
        // Phones re-assert their current view on reconnect.
        _sessionViewTracker.clearAll();

        if (_client.closeCode == RelayCloseCodes.bridgeRevoked) {
          Log.w("Relay reports this bridge as revoked — re-registering with a fresh bridge id");
          await _bridgeRegistrationService.handleBridgeRevoked();
        }

        // Another bridge on this account took the single relay slot. Reconnect
        // only on a long backoff so two always-on bridges don't tight-loop
        // kicking each other (ADR A22); headless/VM failover is preserved
        // because we still retry, just slowly. The GUI is told separately via
        // ControlStatusNotifier (it observes the same replaced-close on the
        // connection-state stream); this loop owns only the backoff policy.
        final takenOver = RelayCloseCodes.isBridgeReplaced(
          closeCode: _client.closeCode,
          closeReason: _client.closeReason,
        );
        if (takenOver) {
          Console.warning(
            "Another bridge for this account has taken over the relay connection. "
            "Retrying on a long backoff — stop the other bridge to reclaim this slot.",
          );
        }

        var backoff = _initialBackoff(takenOver: takenOver);
        while (!_cancelled) {
          await _backoffDelay(backoff);
          if (_cancelled) {
            return;
          }

          // Don't reconnect without a usable token: in supervised mode a
          // signed-out / mid-login GUI yields no token, and reconnecting would
          // re-authenticate the relay from a stale cached token. Back off and
          // retry — a later refresh (or a token_update push) recovers.
          if (!await _refreshAccessToken()) {
            Log.w("No access token available — deferring reconnect (retrying in $backoff)");
            backoff = _nextBackoff(backoff, takenOver: takenOver);
            continue;
          }

          try {
            await _bridgeRegistrationService.ensureRegistered();
            await _client.reconnect();
          } catch (e) {
            Log.w("Reconnect failed: $e (retrying in $backoff)");
            backoff = _nextBackoff(backoff, takenOver: takenOver);
            continue;
          }

          backoff = _initialBackoff(takenOver: takenOver);
          Log.i("Reconnected to relay");
          break;
        }
      }
    } finally {
      final teardownSw = Stopwatch()..start();
      Object? firstTeardownError = _beginShutdownError;
      StackTrace? firstTeardownStackTrace = _beginShutdownStackTrace;

      Future<void> attempt(FutureOr<void> Function() action) async {
        try {
          await action();
        } on Object catch (error, stackTrace) {
          firstTeardownError ??= error;
          firstTeardownStackTrace ??= stackTrace;
        }
      }

      final sinceCancelMs = _cancelRequestedAt == null
          ? null
          : DateTime.now().difference(_cancelRequestedAt!).inMilliseconds;
      Log.i("Disconnecting...");
      Log.d(
        "[shutdown] session teardown begin "
        "(${sinceCancelMs == null ? "no cancel timestamp" : "${sinceCancelMs}ms since cancel()"}"
        "${_inFlightRequestLabel == null ? "" : ", in-flight request: $_inFlightRequestLabel"})",
      );
      await Future.wait([
        attempt(_subscriptions.cancel),
        attempt(_promptDefaultsSubscriptions.cancel),
        attempt(_catalogImportSubscriptions.cancel),
      ]);
      Log.v("[shutdown] subscriptions cancelled (+${teardownSw.elapsedMilliseconds}ms)");
      await attempt(() async {
        await Future.wait(_pluginEventProcessingTails.values);
      });
      Log.v("[shutdown] plugin event processing drained (+${teardownSw.elapsedMilliseconds}ms)");
      await attempt(_sessionPromptService.dispose);
      await Future.wait([
        for (final listener in _pluginEventListeners) attempt(listener.dispose),
        attempt(_sessionBindingCommitListener.dispose),
        attempt(_sessionDeletionListener.dispose),
      ]);
      await attempt(_sessionEventDispatcher.dispose);
      await attempt(_permissionAutoApprovalService.dispose);
      await attempt(_sessionMutationDispatcher.dispose);
      await attempt(_projectActivityService.dispose);
      Log.v("[shutdown] project activity service disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await attempt(_sessionAbortService.dispose);
      Log.v("[shutdown] session abort service disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await attempt(_completionListener.dispose);
      Log.v("[shutdown] completion listener disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await attempt(_maintenanceListener.dispose);
      await attempt(_prSyncService.dispose);
      Log.v("[shutdown] maintenance + pr-sync listeners disposed (+${teardownSw.elapsedMilliseconds}ms)");
      // Plugin teardown is owned by BridgePlugin.shutdown(), run as the
      // shutdown coordinator's ordered step — the deprecated direct
      // api.dispose() call is gone since the descriptor flip.
      Log.v("stopping sse manager...");
      await attempt(_sseManager.stop);
      Log.v("sse manager stopped (+${teardownSw.elapsedMilliseconds}ms)");
      Log.v("disposing push notification service...");
      await attempt(_pushDispatcher.dispose);
      Log.v("push notification service disposed (+${teardownSw.elapsedMilliseconds}ms)");
      await Future.wait([
        attempt(_localWireEventsController.close),
        attempt(_bytesSentController.close),
      ]);
      await attempt(() async {
        Log.v("closing relay client...");
        await _client.close();
        Log.v("relay client closed (+${teardownSw.elapsedMilliseconds}ms)");
      });
      Log.d("[shutdown] session teardown complete (${teardownSw.elapsedMilliseconds}ms total)");
      if (firstTeardownError != null) {
        Error.throwWithStackTrace(firstTeardownError!, firstTeardownStackTrace!);
      }
    }
  }

  void beginShutdown() {
    if (_cancelRequestedAt == null) {
      _cancelRequestedAt = DateTime.now();
      Log.d(
        "[shutdown] cancel() requested"
        "${_inFlightRequestLabel == null ? "" : " — in-flight request: $_inFlightRequestLabel"}",
      );
    } else {
      Log.v("[shutdown] cancel() again (already shutting down)");
    }
    _cancelled = true;
    if (!_shutdownCompleter.isCompleted) {
      _shutdownCompleter.complete();
    }
    unawaited(_client.close());
    try {
      _permissionAutoApprovalService.dispose();
    } on Object catch (error, stackTrace) {
      _beginShutdownError ??= error;
      _beginShutdownStackTrace ??= stackTrace;
    }
  }

  Future<void> cancel() async {
    beginShutdown();
    final sw = Stopwatch()..start();
    await _client.close();
    Log.d("[shutdown] cancel(): relay client closed in ${sw.elapsedMilliseconds}ms");
  }

  /// Performs the restart handoff after the `{restarting:true}` reply has been
  /// enqueued: delegates the run-mode strategy to [BridgeRestartService]
  /// (standalone spawns a successor; supervised records the GUI-respawn intent),
  /// then drives the normal graceful shutdown ([cancel]) — which flushes the
  /// queued reply by closing the relay and lets this process exit. A standalone
  /// successor waits for this pid to exit before it enforces single-live-bridge,
  /// so the handoff is clean; the supervised exit code is applied by the
  /// composition root once the session ends.
  ///
  /// Public because both restart triggers drive the same handoff: the relay
  /// request loop (below) and the local [DebugServer], which reuses this
  /// session's [RequestRouter] and so reaches the same `RestartBridgeHandler`.
  Future<void> handleRestartHandoff() async {
    // Single-flight: the relay and debug-server triggers share the same restart
    // flag but run independently, so without this guard two near-simultaneous
    // `POST /global/restart` requests could each spawn a successor. The flag is
    // set synchronously (no await before it), so the check-and-set is atomic on
    // the event loop. It is reset only when the spawn fails and we keep running,
    // so a later restart can retry.
    if (_restartHandoffStarted) {
      Log.v("[restart] handoff already in progress; ignoring duplicate trigger");
      return;
    }
    _restartHandoffStarted = true;
    Log.i("[restart] restart requested");
    // The restart service owns the run-mode strategy: standalone spawns a
    // successor process; supervised records the intent so the composition root
    // exits with the GUI-respawn sentinel (no successor spawn). A `false` return
    // means the standalone successor could not be started, so we keep running.
    final bool proceed = await _restartService.performRestartHandoff();
    if (!proceed) {
      _restartHandoffStarted = false;
      Console.error(
        "Restart requested but a new bridge could not be started; continuing to run. "
        "Re-run the install script if this persists: https://sesori.com/",
      );
      return;
    }
    Log.i("[restart] handing off; shutting down");
    await cancel();
  }

  Future<void> _processPluginEventInOrder(NormalizedSourcedBridgeEvent source) {
    final previous = _pluginEventProcessingTails[source.pluginId] ?? Future<void>.value();
    final release = Completer<void>();
    _pluginEventProcessingTails[source.pluginId] = release.future;
    return () async {
      await previous;
      try {
        final generation = source.generation;
        if (generation != null &&
            !_pluginRuntime.isCurrentGeneration(
              pluginId: source.pluginId,
              generation: generation,
            )) {
          return;
        }
        await _processPluginEvent(source);
      } finally {
        release.complete();
      }
    }();
  }

  Future<void> _processPluginEvent(NormalizedSourcedBridgeEvent source) async {
    final pluginId = source.pluginId;
    final generation = source.generation;
    final event = source.event;
    try {
      if (generation != null && !_pluginRuntime.isCurrentGeneration(pluginId: pluginId, generation: generation)) {
        return;
      }
      Log.v("[sse] plugin event arrived: ${event.runtimeType}");

      if (event is BridgeSsePermissionReplied) {
        final wasAutoApproved = _permissionAutoApprovalService.consumeReply(
          requestId: event.requestID,
          sessionId: event.sessionID,
        );
        if (wasAutoApproved) return;
      }

      if (config.yolo && event is BridgeSsePermissionAsked) {
        if (_cancelled) return;
        await _permissionAutoApprovalService.approve(
          requestId: event.requestID,
          sessionId: event.sessionID,
        );
        return;
      }

      // A server (re)connect means the plugin may have just loaded a new set of
      // sessions. Reconcile persisted project activity so we don't miss
      // offline activity that arrived while disconnected.
      if (event is BridgeSseServerConnected) {
        await _projectActivityService.reconcile(pluginId: pluginId).catchError((Object e, StackTrace st) {
          Log.w("ProjectActivityService: server-connected reconciliation failed", e, st);
        });
        if (config.yolo) await _permissionAutoApprovalService.approvePending();
      }

      if (config.yolo && event is BridgeSseProjectUpdated) {
        await _permissionAutoApprovalService.approvePending();
      }

      final refreshProjectsSummary = event is BridgeSseProjectUpdated || event is BridgeSseSessionDeleted;
      final sesoriEvent = event is BridgeSseProjectUpdated ? null : _mapper.map(event);
      if (generation != null && !_pluginRuntime.isCurrentGeneration(pluginId: pluginId, generation: generation)) {
        return;
      }
      if (sesoriEvent != null) {
        await _deliverSseEvent(
          event: sesoriEvent,
          pluginId: pluginId,
          generation: generation,
        );
      } else if (!refreshProjectsSummary) {
        Log.v("[sse] mapping returned null — event dropped");
      }

      // Both trigger types mean activity changed. Rebuild from repository data
      // after delivering session.deleted so clients observe deletion first.
      if (refreshProjectsSummary) {
        if (generation != null && !_pluginRuntime.isCurrentGeneration(pluginId: pluginId, generation: generation)) {
          return;
        }
        await _buildAndDeliverProjectsSummaryInOrder(
          pluginId: pluginId,
          generation: generation,
        );
      }
    } catch (e, st) {
      Log.e("[sse] error processing event ${event.runtimeType}: $e\n$st");
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_event_processing:${event.runtimeType}",
              fatal: false,
              reason: "Failed to process SSE event",
              information: [event.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  Future<void> _deliverSseEvent({
    required SesoriSseEvent event,
    required String? pluginId,
    required int? generation,
  }) async {
    if (!_isCurrentSource(pluginId: pluginId, generation: generation)) return;
    Log.v(
      "[sse] mapped to: ${event.runtimeType} — enqueuing (subscribers: ${_sseManager.subscriberCount})",
    );
    _completionListener.handleSseEvent(event);
    if (event is SesoriProjectsSummary) {
      _statusNotifier?.handleProjectsSummary(summary: event);
    }
    // A newly announced root must be queryable as soon as a phone receives
    // the event; unlike other activity, its binding is mandatory first.
    if (event is SesoriSessionCreated) {
      await _routeUnseenActivity(event);
    }
    if (!_isCurrentSource(pluginId: pluginId, generation: generation)) return;
    _enqueueWireEvent(event);
    if (event is! SesoriSessionCreated) {
      try {
        await _routeUnseenActivity(event);
      } catch (e, st) {
        Log.w("failed to route unseen activity for ${event.runtimeType}", e, st);
      }
    }
    try {
      await _projectActivityService.handleEvent(event);
    } catch (e, st) {
      Log.w("failed to route project activity for ${event.runtimeType}", e, st);
    }
  }

  Future<void> _buildAndDeliverProjectsSummaryInOrder({
    required String? pluginId,
    required int? generation,
  }) {
    final previous = _projectsSummaryTail;
    final release = Completer<void>();
    _projectsSummaryTail = release.future;
    return () async {
      await previous;
      try {
        if (!_isCurrentSource(pluginId: pluginId, generation: generation)) return;
        final summary = await _buildProjectsSummary();
        if (summary != null) {
          await _deliverSseEvent(
            event: summary,
            pluginId: pluginId,
            generation: generation,
          );
        }
      } finally {
        release.complete();
      }
    }();
  }

  bool _isCurrentSource({required String? pluginId, required int? generation}) {
    if (generation == null) return true;
    return pluginId != null &&
        _pluginRuntime.isCurrentGeneration(
          pluginId: pluginId,
          generation: generation,
        );
  }

  void _enqueueWireEvent(SesoriSseEvent event) {
    _sseManager.enqueueEvent(event);
    if (!_localWireEventsController.isClosed) _localWireEventsController.add(event);
  }

  /// Builds the projects-summary SSE event: fetches the activity summary with
  /// the bridge's session→project attribution applied (so a derived plugin's
  /// worktree session badges land on the stored parent project) and wraps it
  /// via the pure mapper. Failures are recorded and yield null so the SSE
  /// pipeline keeps flowing — the summary refreshes on the next trigger.
  Future<SesoriSseEvent?> _buildProjectsSummary() async {
    try {
      return _mapper.buildProjectsSummaryEvent(
        projects: await _sessionRepository.getProjectActivitySummaries(),
      );
    } catch (e, st) {
      Log.e("[sse] error building projects summary: $e\n$st");
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "sse_projects_summary",
              fatal: false,
              reason: "Failed to build projects summary event",
              information: const [],
            )
            .catchError((Object reportError, StackTrace reportStackTrace) {
              Log.w(
                "[sse] projects-summary failure report failed",
                reportError,
                reportStackTrace,
              );
            }),
      );
      return null;
    }
  }

  /// Feeds an already-mapped [SesoriSseEvent] into the unseen-changes tracking.
  /// Only message activity, pending input requests, and session lifecycle
  /// events matter; everything else is ignored. A user-authored message (or a
  /// question/permission reply) advances the "last user message" timestamp in
  /// addition to general activity.
  ///
  /// Streamed part/delta events are deliberately NOT activity: `message.updated`
  /// fires when a message is created and when it completes, which is sufficient
  /// granularity for a bold indicator and keeps per-token deltas out of the
  /// write path.
  Future<void> _routeUnseenActivity(SesoriSseEvent event) async {
    switch (event) {
      case SesoriSessionCreated(:final info):
        await _sessionUnseenService.recordSessionCreated(
          sessionId: info.id,
          parentId: info.parentID,
          occurredAt: info.time?.created,
        );
      case SesoriSessionDeleted(:final info):
        await _sessionUnseenService.recordSessionDeleted(sessionId: info.id, projectId: info.projectID);
      case SesoriMessageUpdated(:final info):
        await _sessionUnseenService.recordActivity(
          sessionId: info.sessionID,
          isUserMessage: info is MessageUser,
          occurredAt: info.time?.created,
        );
      // For child/subagent requests, `displaySessionId` is the root session the
      // UI surfaces the request under and the owner of its unseen state.
      case SesoriQuestionAsked(:final sessionID, :final displaySessionId):
        await _sessionUnseenService.recordActivity(
          sessionId: displaySessionId ?? sessionID,
          isUserMessage: false,
        );
      case SesoriPermissionAsked(:final sessionID, :final displaySessionId):
        await _sessionUnseenService.recordActivity(
          sessionId: displaySessionId ?? sessionID,
          isUserMessage: false,
        );
      // Question replied/rejected and permission replied are all user responses
      // to a pending prompt, so they advance the user-interaction timestamp and
      // clear the unseen state.
      case SesoriQuestionReplied(:final sessionID, :final displaySessionId):
        await _sessionUnseenService.recordActivity(
          sessionId: displaySessionId ?? sessionID,
          isUserMessage: true,
        );
      case SesoriQuestionRejected(:final sessionID, :final displaySessionId):
        await _sessionUnseenService.recordActivity(
          sessionId: displaySessionId ?? sessionID,
          isUserMessage: true,
        );
      case SesoriPermissionReplied(:final sessionID, :final displaySessionId):
        await _sessionUnseenService.recordActivity(
          sessionId: displaySessionId ?? sessionID,
          isUserMessage: true,
        );
      default:
        // Not an unseen-relevant event.
        break;
    }
  }

  /// Force-refreshes the access token before a relay reconnect. Returns whether
  /// the reconnect may proceed.
  ///
  /// Returns `false` when the token is genuinely unavailable: either a
  /// [ControlTokenUnavailableException] (supervised mode — the GUI reported
  /// signed-out / mid-login and the service invalidated its cache), or any other
  /// refresh failure with NO usable cached token to fall back on (e.g. standalone
  /// [TokenManager] whose token store was deleted on logout). In both cases the
  /// caller MUST NOT reconnect — there is no safe token to authenticate with.
  ///
  /// Returns `true` when a refresh succeeds, or when a refresh fails for a reason
  /// other than unavailability AND a usable cached token still exists (e.g.
  /// standalone [TokenManager] hitting a transiently-down auth-refresh endpoint
  /// while its cached JWT is still valid) — so the reconnect proceeds with that
  /// cached token, preserving the pre-existing standalone resilience.
  Future<bool> _refreshAccessToken() async {
    try {
      await _tokenRefresher.getAccessToken(forceRefresh: true);
      Log.i("Access token refreshed successfully");
      return true;
    } on ControlTokenUnavailableException catch (e) {
      Log.w("No access token available for reconnect: $e");
      return false;
    } catch (e) {
      // The refresh failed for some other reason. Only reconnect if a usable
      // cached token actually exists — reading it throws when the cache is empty
      // or sign-out-invalidated, in which case there is nothing safe to reconnect
      // with and we must defer like the unavailable case above.
      final String cachedToken;
      try {
        cachedToken = _accessTokenProvider.accessToken;
      } on Object {
        Log.w("Token refresh failed and no cached token is available; deferring reconnect: $e");
        return false;
      }
      if (cachedToken.isEmpty) {
        Log.w("Token refresh failed and the cached token is empty; deferring reconnect: $e");
        return false;
      }
      Log.w("Token refresh failed; reconnecting with the cached token: $e");
      return true;
    }
  }

  /// Whether a freshly emitted [token] warrants dropping the live relay socket
  /// to re-authenticate.
  ///
  /// The relay checks the JWT once at connect and never again, keyed on the
  /// `userId` claim — so an open socket authenticated as the same user stays
  /// fully valid no matter how many times the token rotates. Re-auth is needed
  /// only when the socket's authenticated identity no longer matches the token
  /// the provider now holds:
  ///
  /// - the last connect sent no auth at all ([RelayClient.lastAuthedToken] is
  ///   null — also covers a push landing in the gap between connect() and this
  ///   subscription on a never-authed socket);
  /// - the `userId` claim differs (supervised account switch, standalone
  ///   re-login as another user);
  /// - either token's identity can't be parsed — we can't prove the rotation
  ///   kept the same identity, so re-auth conservatively.
  ///
  /// An identical token (routine unchanged pull, or the reconnect path's own
  /// force-pull re-emitting the token it just authenticated with) never
  /// re-auths.
  bool _requiresRelayReauth(String token) {
    final String? lastAuthed = _client.lastAuthedToken;
    if (lastAuthed == null) return true;
    if (token == lastAuthed) return false;
    final String? newUserId = parseJwtUserId(token);
    final String? authedUserId = parseJwtUserId(lastAuthed);
    if (newUserId == null || authedUserId == null) return true;
    return newUserId != authedUserId;
  }

  /// Live re-auth trigger: the token provider emitted a token for a different
  /// auth identity while the relay was connected, so the open socket is still
  /// authenticated as the old identity. Closing the relay ends the active read
  /// loop, after which [run]'s reconnect block force-pulls the new token and
  /// reconnects — the same path a relay-side drop drives. No-op once cancelled
  /// so a token emit during shutdown can't fight teardown.
  Future<void> _reauthenticateRelay() async {
    if (_cancelled) return;
    // If the socket has already closed (closeCode is set), the read loop is
    // about to end on its own and the reconnect block will inspect the close
    // code. Don't call close() here: it nulls the channel and discards that code,
    // which would mask a bridgeRevoked close and skip re-registration. Let the
    // natural drop path handle it; the fresh token is picked up on reconnect.
    if (_client.closeCode != null) {
      Log.d("Token updated while the relay was already closing — letting the drop path reconnect");
      return;
    }
    Log.i("Access token updated while connected — re-authenticating relay");
    try {
      await _client.close();
    } on Object catch (error, stackTrace) {
      // Best-effort: if the close fails the read loop still ends on the broken
      // socket and the reconnect block recovers, so log and continue.
      Log.w("Failed to close relay for token re-auth", error, stackTrace);
    }
  }

  Future<void> _runRelayLoop(
    List<int> roomKey,
    KeyExchangeManager kxManager,
    Map<int, bool> activePhones,
  ) async {
    await for (final msg in _client.read()) {
      if (_cancelled) {
        return;
      }

      Log.v("relay msg: isText=${msg.isText} len=${msg.data.length}");

      if (msg.isText) {
        Map<String, dynamic> control;
        try {
          control = jsonDecodeMap(utf8.decode(msg.data));
        } catch (e) {
          Log.e("failed to parse control message: $e");
          continue;
        }

        final type = control["type"] as String?;
        final connID = control["connId"] as int?;
        Log.v("control: type=$type connID=$connID");
        if (type == null || connID == null) {
          Log.v("dropping control: null type or connID");
          continue;
        }

        switch (type) {
          case "phone_connected":
            Log.v("phone_connected connID=$connID");
            try {
              kxManager.startExchange(connID);
            } catch (e) {
              Log.e("failed to start exchange for connId $connID: $e");
            }
          case "phone_disconnected":
            Log.v("phone_disconnected connID=$connID");
            kxManager.removeExchange(connID);
            activePhones.remove(connID);
            _sseManager.removeSubscriber(connID);
            _sessionViewTracker.releaseConnection(connID: connID);
        }
        continue;
      }

      if (msg.data.length < 2) {
        Log.v("binary too short: ${msg.data.length}");
        continue;
      }

      final connID = ByteData.sublistView(msg.data).getUint16(0, Endian.big);
      final payload = msg.data.sublist(2);
      if (payload.isEmpty) {
        Log.v("empty payload for connID=$connID");
        continue;
      }

      Log.v("binary: connID=$connID payloadLen=${payload.length} firstByte=0x${payload[0].toRadixString(16)}");

      if (payload[0] == RelayProtocol.jsonStartByte) {
        Log.v("JSON message (key exchange?)");
        RelayMessage relayMessage;
        try {
          relayMessage = RelayMessage.fromJson(
            jsonDecodeMap(utf8.decode(payload)),
          );
        } catch (e) {
          Log.v("failed to parse relay JSON: $e");
          continue;
        }

        Log.v("parsed: ${relayMessage.runtimeType}");

        if (relayMessage is! RelayKeyExchange) {
          Log.v("not a key exchange, skipping");
          continue;
        }

        List<int> encrypted;
        try {
          encrypted = await kxManager.handleKeyExchange(connID, relayMessage);
          Log.d("key exchange OK, sending ready to connID=$connID");
        } catch (e) {
          Log.e("failed key exchange for connId $connID: $e");
          continue;
        }

        try {
          _client.send(connID, encrypted);
          Log.d("ready sent to connID=$connID");
        } catch (e) {
          if (_cancelled) {
            throw StateError("cancelled");
          }
          throw Exception("send ready for connId $connID: $e");
        }

        activePhones[connID] = true;
        Log.d("phone $connID is now active");
        continue;
      }

      Log.v(
        "checking protocolVersion: payload[0]=0x${payload[0].toRadixString(16)} expected=0x${protocolVersion.toRadixString(16)}",
      );
      if (payload[0] == protocolVersion) {
        final encryptor = RelayCryptoService().createSessionEncryptor(
          SecretKey(List<int>.from(roomKey)),
        );

        List<int>? decrypted;
        Object? decryptError;
        try {
          decrypted = await unframe(payload, encryptor: encryptor);
        } catch (e) {
          decryptError = e;
        }

        if (activePhones[connID] == true) {
          if (decryptError != null || decrypted == null) {
            Log.v(
              "failed to decrypt from connId $connID: $decryptError",
            );
            continue;
          }
          Log.v("decrypted OK from connID=$connID, handling...");
          await _handleDecryptedMessage(connID, decrypted);
          Log.v("handled message from connID=$connID");
          continue;
        }

        if (decryptError != null || decrypted == null) {
          Log.v("not active, decrypt failed for connID=$connID: $decryptError — sending rekeyRequired");
          final rekeyRequired = jsonEncode(
            const RelayMessage.rekeyRequired().toJson(),
          );
          try {
            _client.send(connID, utf8.encode(rekeyRequired));
          } catch (_) {
            if (_cancelled) {
              throw StateError("cancelled");
            }
          }
          continue;
        }

        RelayMessage parsedMessage;
        try {
          parsedMessage = RelayMessage.fromJson(
            jsonDecodeMap(utf8.decode(decrypted)),
          );
        } catch (_) {
          continue;
        }

        if (parsedMessage is! RelayResume) {
          continue;
        }

        final ackJSON = utf8.encode(
          jsonEncode(const RelayMessage.resumeAck().toJson()),
        );
        List<int> encryptedAck;
        try {
          encryptedAck = await frame(ackJSON, encryptor: encryptor);
        } catch (_) {
          continue;
        }

        try {
          _client.send(connID, encryptedAck);
        } catch (e) {
          if (_cancelled) {
            throw StateError("cancelled");
          }
          throw Exception("send resume ack for connId $connID: $e");
        }

        activePhones[connID] = true;
      }
    }
  }

  Future<void> _handleDecryptedMessage(int connID, List<int> decrypted) async {
    RelayMessage msg;
    try {
      msg = RelayMessage.fromJson(
        jsonDecodeMap(utf8.decode(decrypted)),
      );
    } catch (e) {
      Log.v("failed to parse decrypted msg from connID=$connID: $e");
      return;
    }

    Log.v("decrypted msg type: ${msg.runtimeType}");

    switch (msg) {
      case final RelayRequest req:
        Log.v("RelayRequest: ${req.method} ${req.path}");
        _inFlightRequestLabel = "${req.method} ${req.path}";
        final routeSw = Stopwatch()..start();
        // Defensively discard any restart flag left armed before routing this
        // relay request. The local DebugServer reuses this RequestRouter but
        // consumes and acts on its own restart flag synchronously right after it
        // routes, so it should never leak one here; this clear still guarantees
        // that only a restart requested during THIS relay request can trigger a
        // handoff from the relay path.
        _restartService.consumeRestartRequest();
        // If shutdown wins the race below, this future keeps running in the
        // background. ignore() marks any later failure as handled so it can
        // never surface as an unhandled async exception after abandonment.
        final routeFuture = _router.route(req)..ignore();
        try {
          final response = await Future.any<RelayResponse>([
            routeFuture,
            _shutdownCompleter.future.then((_) => throw const _ShutdownInProgressException()),
          ]);
          // Consume the restart flag now — it was set (if at all) by THIS
          // request during routing. Tying consumption to this request means a
          // failed/abandoned response can never leave the flag armed to trigger
          // a delayed, unintended restart on a later request.
          final bool restartRequested = _restartService.consumeRestartRequest();
          if (_cancelled) {
            Log.v(
              "[shutdown] route ${req.method} ${req.path} completed after cancel — "
              "dropping response (status=${response.status})",
            );
            return;
          }
          if (routeSw.elapsedMilliseconds > 1000) {
            Log.d(
              "[shutdown] slow route ${req.method} ${req.path} for connId $connID "
              "took ${routeSw.elapsedMilliseconds}ms (cancelled=$_cancelled)",
            );
          }
          Log.v("response: status=${response.status}");
          await _encryptAndSend(connID: connID, message: response);
          Log.v("response sent to connID=$connID");
          if (restartRequested) {
            await handleRestartHandoff();
          }
        } on _ShutdownInProgressException {
          Log.v(
            "[shutdown] route ${req.method} ${req.path} abandoned without sending a response",
          );
          unawaited(
            routeFuture.then<void>(
              (_) {
                _restartService.consumeRestartRequest();
              },
              onError: (Object error, StackTrace stackTrace) {
                Log.w("[shutdown] abandoned route ${req.method} ${req.path} later failed", error, stackTrace);
                _restartService.consumeRestartRequest();
              },
            ),
          );
        } catch (e) {
          if (_cancelled) {
            Log.v("[shutdown] route ${req.method} ${req.path} failed during shutdown: $e");
          } else {
            Log.e("request routing failed for connId $connID: $e");
          }
        } finally {
          _inFlightRequestLabel = null;
        }
      case final RelaySseSubscribe subscribe:
        Log.v("SseSubscribe: path=${subscribe.path}");
        try {
          _sseManager.subscribePath(connID, subscribe.path, _client);
          final projSummary = await _buildProjectsSummary();
          if (projSummary != null) {
            _enqueueWireEvent(projSummary);
            _completionListener.handleSseEvent(projSummary);
          }
          Log.v("initial projectsSummary enqueued");
        } catch (e) {
          Log.e("sse subscribe failed for connId $connID: $e");
        }
      case RelaySseUnsubscribe():
        Log.v("SseUnsubscribe connID=$connID");
        _sseManager.unsubscribe(connID);
      case RelaySessionView(:final sessionId):
        Log.v("SessionView connID=$connID sessionId=$sessionId");
        _sessionViewTracker.setViewing(connID: connID, sessionId: sessionId);
      default:
        Log.v("unhandled msg type: ${msg.runtimeType}");
    }
  }

  // Ordinary drop (network blip, relay restart) reconnects promptly; a
  // takeover drop reconnects on a minutes-order backoff so two always-on
  // bridges don't tight-loop kicking each other (ADR A22).
  static const _ordinaryInitialBackoff = Duration(seconds: 1);
  static const _ordinaryMaxBackoff = Duration(seconds: 30);
  static const _takeoverInitialBackoff = Duration(minutes: 2);
  static const _takeoverMaxBackoff = Duration(minutes: 5);

  /// Waits out a reconnect backoff, but wakes immediately on shutdown so a
  /// pending long wait (a minutes-order takeover backoff, ADR A22) never blocks
  /// teardown/exit on SIGTERM — [cancel] completes [_shutdownCompleter], which
  /// races the timer. A single completed-completer wait is safe to reuse across
  /// iterations because it only ever resolves once (on shutdown).
  Future<void> _backoffDelay(Duration backoff) {
    return Future.any<void>([
      Future<void>.delayed(backoff),
      _shutdownCompleter.future,
    ]);
  }

  Duration _initialBackoff({required bool takenOver}) {
    if (!takenOver) return _ordinaryInitialBackoff;
    // Jitter the takeover backoff so two mutually-displacing bridges don't
    // resynchronize onto the same retry cadence.
    return _jitter(_takeoverInitialBackoff);
  }

  Duration _nextBackoff(Duration backoff, {required bool takenOver}) {
    final max = takenOver ? _takeoverMaxBackoff : _ordinaryMaxBackoff;
    final next = Duration(microseconds: backoff.inMicroseconds * 2);
    // Re-jitter every takeover step (not just the cap) so two mutually
    // displacing bridges don't resynchronize onto the same retry cadence as
    // they climb the backoff curve. Ordinary reconnects keep the deterministic
    // fast backoff.
    if (next > max) {
      return takenOver ? _jitter(max) : max;
    }
    return takenOver ? _jitter(next) : next;
  }

  Duration _jitter(Duration base) {
    // Add up to +25% random jitter to spread out retries.
    final extra = (base.inMilliseconds * 0.25 * _backoffJitter.nextDouble()).round();
    return base + Duration(milliseconds: extra);
  }

  Future<void> _encryptAndSend({
    required int connID,
    required RelayMessage message,
  }) async {
    final respJson = jsonEncode(message.toJson());
    final jsonBytes = utf8.encode(respJson);
    Log.v("[response] sending ${jsonBytes.length} bytes to connID=$connID");
    _bytesSentController.add(jsonBytes.length);
    final cryptoService = RelayCryptoService();
    final encryptionKey = SecretKey(List<int>.from(_roomKey));
    final encryptor = cryptoService.createSessionEncryptor(encryptionKey);
    final framed = await frame(jsonBytes, encryptor: encryptor);
    _client.send(connID, framed);
  }
}

/// Thrown when a request is racing against shutdown and shutdown wins.
class _ShutdownInProgressException implements Exception {
  const _ShutdownInProgressException();
}
