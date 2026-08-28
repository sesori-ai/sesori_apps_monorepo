import "dart:async";
import "dart:convert";
import "dart:io" show FileSystemEntity, FileSystemEntityType;
import "dart:math";
import "dart:typed_data";

import "package:clock/clock.dart";
import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "api/archived_session_storage.dart";
import "api/attachment_spill_storage.dart";
import "api/database/daos/new_session_defaults_dao.dart";
import "api/database/daos/session_options_cache_dao.dart";
import "api/database/database.dart";
import "api/database/history/chat_history_database.dart";
import "api/filesystem_api.dart";
import "api/gh_cli_api.dart";
import "api/git_cli_api.dart";
import "api/sesori_server_api.dart";
import "auth/access_token_provider.dart";
import "auth/bridge_registration_service.dart";
import "auth/token_refresher.dart";
import "control/control_status_notifier.dart";
import "foundation/filesystem_permission_validator.dart";
import "foundation/key_exchange.dart";
import "foundation/process_runner.dart";
import "foundation/relay_client.dart";
import "foundation/streaming_process_runner.dart";
import "listeners/chat_history_activity_listener.dart";
import "listeners/chat_history_listener.dart";
import "listeners/current_project_glossary_listener.dart";
import "listeners/plugin_catalog_hydration_listener.dart";
import "listeners/plugin_event_listener.dart";
import "listeners/session_binding_commit_listener.dart";
import "listeners/session_mutation_listener.dart";
import "listeners/session_options_changed_refresh_listener.dart";
import "listeners/session_options_creation_refresh_listener.dart";
import "listeners/viewed_project_glossary_listener.dart";
import "listeners/viewed_project_pr_refresh_listener.dart";
import "models/bridge_config.dart";
import "push/completion_notifier.dart";
import "push/completion_push_listener.dart";
import "push/maintenance_push_listener.dart";
import "push/push_dispatcher.dart";
import "push/push_maintenance_telemetry.dart" show PushMaintenanceTelemetryBuilder, readCurrentRssBytes;
import "push/push_notification_client.dart";
import "push/push_notification_content_builder.dart";
import "push/push_rate_limiter.dart";
import "push/push_session_state_tracker.dart";
import "repositories/agent_repository.dart";
import "repositories/attachment_thumbnail_builder.dart";
import "repositories/bridge_settings_repository.dart";
import "repositories/catalog_import_repository.dart";
import "repositories/chat_history_repository.dart";
import "repositories/filesystem_repository.dart";
import "repositories/health_repository.dart";
import "repositories/mappers/git_diff_output_mapper.dart";
import "repositories/mappers/session_event_mapper.dart";
import "repositories/new_session_defaults_repository.dart";
import "repositories/pending_interaction_support.dart";
import "repositories/permission_repository.dart";
import "repositories/pr_source_repository.dart";
import "repositories/project_activity_repository.dart";
import "repositories/project_catalog_identity_calculator.dart";
import "repositories/project_glossary_publication_repository.dart";
import "repositories/project_glossary_repository.dart";
import "repositories/project_glossary_scope_repository.dart";
import "repositories/project_repository.dart";
import "repositories/provider_repository.dart";
import "repositories/pull_request_repository.dart";
import "repositories/question_repository.dart";
import "repositories/session_diff_repository.dart";
import "repositories/session_metadata_repository.dart";
import "repositories/session_options_repository.dart";
import "repositories/session_repository.dart";
import "repositories/session_unseen_calculator.dart";
import "repositories/session_unseen_repository.dart";
import "repositories/trackers/session_event_tracker.dart";
import "repositories/worktree_repository.dart";
import "routing/abort_session_handler.dart";
import "routing/bridge_restart_dispatcher.dart";
import "routing/cancel_catalog_import_handler.dart";
import "routing/cancel_queued_prompt_handler.dart";
import "routing/create_directory_handler.dart";
import "routing/create_project_handler.dart";
import "routing/create_session_handler.dart";
import "routing/delete_session_handler.dart";
import "routing/filesystem_suggestions_handler.dart";
import "routing/get_base_branch_handler.dart";
import "routing/get_bridge_settings_handler.dart";
import "routing/get_catalog_import_statuses_handler.dart";
import "routing/get_child_sessions_handler.dart";
import "routing/get_commands_handler.dart";
import "routing/get_current_project_handler.dart";
import "routing/get_plugin_management_handler.dart";
import "routing/get_plugin_setup_handler.dart";
import "routing/get_plugins_handler.dart";
import "routing/get_project_questions_handler.dart";
import "routing/get_projects_handler.dart";
import "routing/get_providers_handler.dart";
import "routing/get_pull_request_refresh_settings_handler.dart";
import "routing/get_queued_prompts_handler.dart";
import "routing/get_session_attachment_handler.dart";
import "routing/get_session_diffs_handler.dart";
import "routing/get_session_handler.dart";
import "routing/get_session_messages_handler.dart";
import "routing/get_session_permissions_handler.dart";
import "routing/get_session_questions_handler.dart";
import "routing/get_session_statuses_handler.dart";
import "routing/get_sessions_handler.dart";
import "routing/health_check_handler.dart";
import "routing/hide_project_handler.dart";
import "routing/mark_session_seen_handler.dart";
import "routing/open_project_handler.dart";
import "routing/patch_bridge_settings_handler.dart";
import "routing/patch_plugin_idle_timeout_handler.dart";
import "routing/plugin_authentication_handlers.dart";
import "routing/post_agents_handler.dart";
import "routing/post_plugin_lifecycle_command_handler.dart";
import "routing/post_session_options_handler.dart";
import "routing/reject_question_handler.dart";
import "routing/rename_project_handler.dart";
import "routing/rename_session_handler.dart";
import "routing/reply_to_permission_handler.dart";
import "routing/reply_to_question_handler.dart";
import "routing/request_router.dart";
import "routing/restart_bridge_handler.dart";
import "routing/routed_request.dart";
import "routing/routed_request_dispatcher.dart";
import "routing/send_prompt_handler.dart";
import "routing/set_base_branch_handler.dart";
import "routing/start_catalog_import_handler.dart";
import "routing/update_session_archive_status_handler.dart";
import "runtime/plugin_runtime.dart";
import "server/services/bridge_restart_service.dart";
import "services/archived_session_validator.dart";
import "services/catalog_import_service.dart";
import "services/chat_history_reconcile_service.dart";
import "services/chat_history_service.dart";
import "services/current_project_service.dart";
import "services/deleted_session_storage_cleanup_service.dart";
import "services/pending_interaction_service.dart";
import "services/permission_auto_approval_service.dart";
import "services/plugin_lifecycle_service.dart";
import "services/pr_sync_service.dart";
import "services/project_activity_service.dart";
import "services/project_glossary_population_service.dart";
import "services/project_glossary_scope_service.dart";
import "services/project_glossary_term_calculator.dart";
import "services/project_initialization_service.dart";
import "services/project_mutation_service.dart";
import "services/project_view_tracker.dart";
import "services/pull_request_refresh_settings_service.dart";
import "services/session_abort_service.dart";
import "services/session_creation_service.dart";
import "services/session_deletion_service.dart";
import "services/session_diff_service.dart";
import "services/session_event_dispatcher.dart";
import "services/session_event_service.dart";
import "services/session_lifecycle_service.dart";
import "services/session_mutation_dispatcher.dart";
import "services/session_operation_dispatcher.dart";
import "services/session_options_service.dart";
import "services/session_prompt_service.dart";
import "services/session_unseen_service.dart";
import "services/session_view_tracker.dart";
import "services/worktree_service.dart";
import "services/yolo_settings_service.dart";
import "sse/bridge_event_mapper.dart";
import "sse/sse_event_delivery.dart";
import "sse/sse_manager.dart";
import "version.dart";

typedef OrchestratorComposition = ({
  OrchestratorSession session,
  CatalogImportService catalogImportService,
  PluginCatalogHydrationListener catalogHydrationListener,
  DeletedSessionStorageCleanupService deletedSessionStorageCleanupService,
  ChatHistoryReconcileService chatHistoryReconcileService,
  BridgeRestartDispatcher restartDispatcher,
  RoutedRequestDispatcher routedRequestDispatcher,
  SessionRepository sessionRepository,
  SessionUnseenService sessionUnseenService,
  SessionViewTracker sessionViewTracker,
  ProjectViewTracker projectViewTracker,
});

/// Factory that creates [OrchestratorSession] instances with all runtime
/// dependencies (room key, SSE manager) properly initialized.
class Orchestrator({
    required final BridgeConfig config,
    required final RelayClient _client,
    required final PluginLifecycleService _pluginLifecycleService,
    required final PluginRuntime _pluginRuntime,
    required final BridgeSettingsRepository _bridgeSettingsRepository,
    required final ServerClock _clock,
    required final AppDatabase _database,
    required final ChatHistoryDatabase _chatHistoryDatabase,
    required final AttachmentSpillStorage _attachmentSpillStorage,
    required final ArchivedSessionStorage _archivedSessionStorage,
    required final http.Client _httpClient,
    required final ProcessRunner _processRunner,
    required final AccessTokenProvider _accessTokenProvider,
    required final TokenRefresher _tokenRefresher,
    required final BridgeRegistrationService _bridgeRegistrationService,
    required final FailureReporter _failureReporter,
    required final BridgeRestartService _restartService,
    required final bool _filesystemAccessOk,
    // Supervised mode only: owns the status-class pushes to the desktop GUI.
    // Standalone has no control channel, so this is null there.
    required final ControlStatusNotifier? _statusNotifier,
    required final ReconnectBackoffPolicy _reconnectBackoff,
  }) {

  /// Creates a new session with a fresh room key and SSE manager.
  OrchestratorComposition create() {
    final pluginComposition = _pluginLifecycleService.compositionView;
    const aggregateSourceDeadline = Duration(seconds: 5);
    const unseenCalculator = SessionUnseenCalculator();
    const projectCatalogIdentityCalculator = ProjectCatalogIdentityCalculator();
    final gitCliApi = GitCliApi(
      processRunner: _processRunner,
      streamingProcessRunner: const StreamingProcessRunner(),
      gitPathExists: _gitPathExists,
    );
    final sessionRepository = SessionRepository(
      runtime: _pluginRuntime,
      sessionDao: _database.sessionDao,
      projectsDao: _database.projectsDao,
      pullRequestDao: _database.pullRequestDao,
      unseenCalculator: unseenCalculator,
      projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
      aggregateSourceDeadline: aggregateSourceDeadline,
    );
    final newSessionDefaultsRepository = NewSessionDefaultsRepository(
      dao: NewSessionDefaultsDao(database: _database),
    );
    final sessionOptionsRepository = SessionOptionsRepository(
      runtime: _pluginRuntime,
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
      cacheDao: SessionOptionsCacheDao(database: _database),
    );
    final sessionOptionsService = SessionOptionsService(
      repository: sessionOptionsRepository,
      newSessionDefaultsRepository: newSessionDefaultsRepository,
      pluginScopes: pluginComposition.sessionOptionsScopeById,
      clock: _clock,
      retention: const Duration(days: 30),
    );
    final deletedSessionStorageCleanupService = DeletedSessionStorageCleanupService(
      sessionRepository: sessionRepository,
    );
    final projectRepository = ProjectRepository(
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
      unseenCalculator: unseenCalculator,
      filesystemApi: const FilesystemApi(),
      gitCliApi: gitCliApi,
      projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
    );
    final sessionViewTracker = SessionViewTracker();
    final projectViewTracker = ProjectViewTracker();
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
      filesystemApi: const FilesystemApi(),
      gitApi: gitCliApi,
      runtime: _pluginRuntime,
    );
    final worktreeService = WorktreeService(worktreeRepository: worktreeRepository);
    final sessionOperationDispatcher = SessionOperationDispatcher(
      sessionRepository: sessionRepository,
    );
    final archivedSessionValidator = ArchivedSessionValidator(sessionRepository: sessionRepository);
    final sessionMutationDispatcher = SessionMutationDispatcher(
      sessionRepository: sessionRepository,
      sessionOperationDispatcher: sessionOperationDispatcher,
      worktreeService: worktreeService,
    );
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
      database: _database,
      pullRequestDao: _database.pullRequestDao,
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
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
    final pullRequestRefreshSettingsService = PullRequestRefreshSettingsService(
      bridgeSettingsRepository: _bridgeSettingsRepository,
    );
    final viewedProjectPrRefreshListener = ViewedProjectPrRefreshListener(
      tracker: projectViewTracker,
      prSyncService: prSyncService,
      settingsService: pullRequestRefreshSettingsService,
    );
    final currentProjectService = CurrentProjectService(projectRepository: projectRepository);
    final sesoriServerApi = SesoriServerApi(
      authBackendUrl: config.authBackendURL,
      client: _httpClient,
      requestDeadline: SesoriServerApi.defaultRequestDeadline,
      tokenRefresher: _tokenRefresher,
    );
    final projectGlossaryPopulationService = ProjectGlossaryPopulationService(
      projectRepository: projectRepository,
      scopeService: ProjectGlossaryScopeService(
        repository: ProjectGlossaryScopeRepository(gitCliApi: gitCliApi),
        bridgeIdProvider: _bridgeRegistrationService,
      ),
      glossaryRepository: ProjectGlossaryRepository(
        gitCliApi: gitCliApi,
        filesystemApi: const FilesystemApi(),
      ),
      termCalculator: const ProjectGlossaryTermCalculator(),
      publicationRepository: ProjectGlossaryPublicationRepository(api: sesoriServerApi),
    );
    final currentProjectGlossaryListener = CurrentProjectGlossaryListener(
      source: currentProjectService.loadedProjectIds,
      service: projectGlossaryPopulationService,
    );
    final viewedProjectGlossaryListener = ViewedProjectGlossaryListener(
      tracker: projectViewTracker,
      service: projectGlossaryPopulationService,
    );
    final projectActivityService = ProjectActivityService(
      projectRepository: projectRepository,
      projectActivityRepository: ProjectActivityRepository(
        runtime: _pluginRuntime,
        projectsDao: _database.projectsDao,
        sessionDao: _database.sessionDao,
        projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
        aggregateSourceDeadline: aggregateSourceDeadline,
      ),
      now: () => DateTime.now().millisecondsSinceEpoch,
    );
    final pendingInteractionSupport = PendingInteractionSupport(sessionDao: _database.sessionDao);
    final permissionRepository = PermissionRepository(
      runtime: _pluginRuntime,
      pendingSupport: pendingInteractionSupport,
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
    );
    final questionRepository = QuestionRepository(
      runtime: _pluginRuntime,
      pendingSupport: pendingInteractionSupport,
      sessionDao: _database.sessionDao,
      projectsDao: _database.projectsDao,
      aggregateSourceDeadline: aggregateSourceDeadline,
    );
    final pendingInteractionService = PendingInteractionService(
      permissionRepository: permissionRepository,
      questionRepository: questionRepository,
      dispatcher: sessionOperationDispatcher,
      archivedSessionValidator: archivedSessionValidator,
    );
    final sessionCreationService = SessionCreationService(
      sessionMetadataRepository: SessionMetadataRepository(api: sesoriServerApi),
      worktreeService: worktreeService,
      sessionRepository: sessionRepository,
      newSessionDefaultsRepository: newSessionDefaultsRepository,
      sessionMutationDispatcher: sessionMutationDispatcher,
      sessionOptionsService: sessionOptionsService,
    );
    final projectInitializationService = ProjectInitializationService(
      worktreeRepository: worktreeRepository,
      filesystemRepository: filesystemRepository,
    );
    final projectMutationService = ProjectMutationService(
      filesystemRepository: filesystemRepository,
      projectInitializationService: projectInitializationService,
      projectActivityService: projectActivityService,
      projectRepository: projectRepository,
    );
    final roomKey = _generateRoomKey();
    final cryptoService = RelayCryptoService();
    final sessionEncryptor = cryptoService.createSessionEncryptor(SecretKey(roomKey));
    final keyExchangeManager = KeyExchangeManager(roomKey, cryptoService: cryptoService);
    final bytesSentController = StreamController<int>.broadcast();
    final localWireEventsController = StreamController<SesoriSseEvent>.broadcast();
    final sseManager = SSEManager(
      replayWindow: config.sseReplayWindow,
      onBytesSent: bytesSentController.add,
      failureReporter: _failureReporter,
      encryptor: sessionEncryptor,
    );

    final catalogImportRepository = CatalogImportRepository(
      runtime: _pluginRuntime,
      projectsDao: _database.projectsDao,
      sessionDao: _database.sessionDao,
      catalogHydrationsDao: _database.catalogHydrationsDao,
      projectCatalogIdentityCalculator: projectCatalogIdentityCalculator,
    );
    final catalogImportService = CatalogImportService(
      orderedPluginIds: pluginComposition.orderedPluginIds,
      emptyHydrationPolicies: {
        for (final entry in pluginComposition.projectOwnershipById.entries)
          entry.key: switch (entry.value) {
            PluginProjectOwnership.native => CatalogEmptyHydrationPolicy.complete,
            PluginProjectOwnership.bridgeDerived => CatalogEmptyHydrationPolicy.retry,
          },
      },
      repository: catalogImportRepository,
    );
    final catalogHydrationListener = PluginCatalogHydrationListener(
      readyPluginIds: _pluginLifecycleService.readyPluginIds,
      catalogImportService: catalogImportService,
    );
    final sessionPromptService = SessionPromptService(
      sessionRepository: sessionRepository,
      dispatcher: sessionOperationDispatcher,
      archivedSessionValidator: archivedSessionValidator,
      sessionOptionsService: sessionOptionsService,
    );
    final chatHistoryService = ChatHistoryService(
      chatHistoryRepository: ChatHistoryRepository(
        chatHistoryDao: _chatHistoryDatabase.chatHistoryDao,
        attachmentSpillStorage: _attachmentSpillStorage,
        archivedSessionStorage: _archivedSessionStorage,
      ),
      sessionRepository: sessionRepository,
      attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
      bridgeIdProvider: _bridgeRegistrationService,
    );
    final sessionLifecycleService = SessionLifecycleService(
      worktreeService: worktreeService,
      sessionRepository: sessionRepository,
      filesystemRepository: filesystemRepository,
      sessionOperationDispatcher: sessionOperationDispatcher,
      archivedSessionValidator: archivedSessionValidator,
      chatHistoryService: chatHistoryService,
    );
    final sessionDeletionService = SessionDeletionService(
      sessionLifecycleService: sessionLifecycleService,
      sessionMutationDispatcher: sessionMutationDispatcher,
      chatHistoryService: chatHistoryService,
    );
    final sessionAbortService = SessionAbortService(
      sessionRepository: sessionRepository,
      dispatcher: sessionOperationDispatcher,
    );
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
    final sessionMutationListener = SessionMutationListener(
      source: sessionMutationDispatcher.mutations.map(_mapLocalMutation),
      dispatcher: sessionEventDispatcher,
    );
    final permissionAutoApprovalService = PermissionAutoApprovalService(
      sessionRepository: sessionRepository,
      permissionRepository: permissionRepository,
      pendingInteractionService: pendingInteractionService,
      bridgeSettingsRepository: _bridgeSettingsRepository,
    );
    final yoloSettingsService = YoloSettingsService(
      bridgeSettingsRepository: _bridgeSettingsRepository,
      permissionAutoApprovalService: permissionAutoApprovalService,
    );
    final pluginEventListener = PluginEventListener(
      source: _pluginRuntime.backendEvents,
      dispatcher: sessionEventDispatcher,
    );
    final sessionBindingCommitListener = SessionBindingCommitListener(
      source: sessionRepository.bindingCommits,
      dispatcher: sessionEventDispatcher,
    );
    final sessionOptionsCreationRefreshListener = SessionOptionsCreationRefreshListener(
      source: sessionRepository.bindingCommits,
      service: sessionOptionsService,
    );
    final sessionOptionsChangedRefreshListener = SessionOptionsChangedRefreshListener(
      runtime: _pluginRuntime,
      service: sessionOptionsService,
    );
    final chatHistoryListener = ChatHistoryListener(
      source: sessionEventDispatcher.events,
      chatHistoryService: chatHistoryService,
    );
    final chatHistoryActivityListener = ChatHistoryActivityListener(
      source: catalogImportRepository.backendActivity,
      chatHistoryService: chatHistoryService,
    );
    final normalizedPluginEvents = sessionEventDispatcher.events;
    final restartDispatcher = BridgeRestartDispatcher(restartService: _restartService);
    final router = RequestRouter(
      handlers: [
        HealthCheckHandler(healthRepository: healthRepository),
        GetPluginManagementHandler(lifecycleService: _pluginLifecycleService),
        PostPluginAuthenticationHandler(lifecycleService: _pluginLifecycleService),
        DeletePluginAuthenticationHandler(lifecycleService: _pluginLifecycleService),
        PatchPluginIdleTimeoutHandler(lifecycleService: _pluginLifecycleService),
        GetBridgeSettingsHandler(settingsRepository: _bridgeSettingsRepository),
        GetPullRequestRefreshSettingsHandler(settingsService: pullRequestRefreshSettingsService),
        PatchBridgeSettingsHandler(
          pullRequestRefreshSettingsService: pullRequestRefreshSettingsService,
          yoloSettingsService: yoloSettingsService,
        ),
        PostPluginLifecycleCommandHandler(lifecycleService: _pluginLifecycleService),
        GetPluginSetupHandler(lifecycleService: _pluginLifecycleService),
        GetPluginsHandler(lifecycleService: _pluginLifecycleService, bridgeIdProvider: _bridgeRegistrationService),
        PostSessionOptionsHandler(
          service: sessionOptionsService,
          pluginIds: pluginComposition.sessionOptionsScopeById.keys.toSet(),
        ),
        RestartBridgeHandler(restartService: _restartService),
        GetCurrentProjectHandler(currentProjectService: currentProjectService),
        GetProjectsHandler(projectActivityService: projectActivityService),
        GetCommandsHandler(sessionRepository: sessionRepository),
        GetSessionStatusesHandler(sessionRepository: sessionRepository),
        GetChildSessionsHandler(sessionRepository: sessionRepository),
        GetSessionHandler(
          sessionRepository: sessionRepository,
          prSyncService: prSyncService,
        ),
        GetSessionAttachmentHandler(chatHistoryService: chatHistoryService),
        GetSessionMessagesHandler(chatHistoryService: chatHistoryService),
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
        DeleteSessionHandler(sessionDeletionService: sessionDeletionService),
        SendPromptHandler(sessionPromptService: sessionPromptService),
        GetQueuedPromptsHandler(sessionRepository: sessionRepository),
        CancelQueuedPromptHandler(sessionPromptService: sessionPromptService),
        AbortSessionHandler(sessionAbortService: sessionAbortService),
        GetProvidersHandler(providerRepository),
        PostAgentsHandler(agentRepository),
        GetSessionQuestionsHandler(questionRepository: questionRepository),
        GetProjectQuestionsHandler(questionRepository: questionRepository),
        GetSessionPermissionsHandler(
          permissionRepository: permissionRepository,
          permissionAutoApprovalService: permissionAutoApprovalService,
        ),
        ReplyToQuestionHandler(pendingInteractionService: pendingInteractionService),
        RejectQuestionHandler(pendingInteractionService: pendingInteractionService),
        ReplyToPermissionHandler(pendingInteractionService: pendingInteractionService),
        RenameProjectHandler(projectRepository),
        CreateProjectHandler(projectMutationService: projectMutationService),
        OpenProjectHandler(projectMutationService: projectMutationService),
        HideProjectHandler(projectMutationService: projectMutationService),
        GetBaseBranchHandler(projectRepository: projectRepository),
        SetBaseBranchHandler(projectRepository: projectRepository),
        FilesystemSuggestionsHandler(filesystemRepository: filesystemRepository),
        CreateDirectoryHandler(filesystemRepository: filesystemRepository),
        StartCatalogImportHandler(service: catalogImportService),
        CancelCatalogImportHandler(service: catalogImportService),
        GetCatalogImportStatusesHandler(service: catalogImportService),
        GetSessionDiffsHandler(
          sessionDiffService: sessionDiffService,
        ),
      ],
    );
    final routedRequestDispatcher = RoutedRequestDispatcher(router: router);

    final session = OrchestratorSession._(
      config: config,
      client: _client,
      pluginEvents: normalizedPluginEvents,
      pluginEventListener: pluginEventListener,
      sessionBindingCommitListener: sessionBindingCommitListener,
      sessionMutationListener: sessionMutationListener,
      chatHistoryListener: chatHistoryListener,
      chatHistoryActivityListener: chatHistoryActivityListener,
      chatHistoryService: chatHistoryService,
      sessionOptionsCreationRefreshListener: sessionOptionsCreationRefreshListener,
      sessionOptionsChangedRefreshListener: sessionOptionsChangedRefreshListener,
      sessionEventDispatcher: sessionEventDispatcher,
      pluginRuntime: _pluginRuntime,
      completionListener: completionListener,
      maintenanceListener: maintenanceListener,
      accessTokenProvider: _accessTokenProvider,
      tokenRefresher: _tokenRefresher,
      bridgeRegistrationService: _bridgeRegistrationService,
      sessionEncryptor: sessionEncryptor,
      keyExchangeManager: keyExchangeManager,
      sseManager: sseManager,
      routedRequestDispatcher: routedRequestDispatcher,
      mapper: BridgeEventMapper(failureReporter: _failureReporter),
      sessionPromptService: sessionPromptService,
      catalogImportProgress: catalogImportService.progress,
      pluginManagementSnapshotTokens: _pluginLifecycleService.managementSnapshotTokens,
      pluginInstallProgress: _pluginLifecycleService.installProgress,
      pluginAuthenticationProgress: _pluginLifecycleService.authenticationProgress,
      localWireEventsController: localWireEventsController,
      bytesSentController: bytesSentController,
      failureReporter: _failureReporter,
      sessionRepository: sessionRepository,
      prSyncService: prSyncService,
      viewedProjectPrRefreshListener: viewedProjectPrRefreshListener,
      currentProjectGlossaryListener: currentProjectGlossaryListener,
      viewedProjectGlossaryListener: viewedProjectGlossaryListener,
      projectGlossaryPopulationService: projectGlossaryPopulationService,
      currentProjectService: currentProjectService,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      projectViewTracker: projectViewTracker,
      projectActivityService: projectActivityService,
      permissionAutoApprovalService: permissionAutoApprovalService,
      yoloSettingsService: yoloSettingsService,
      pendingInteractionService: pendingInteractionService,
      sessionAbortService: sessionAbortService,
      sessionOperationDispatcher: sessionOperationDispatcher,
      sessionMutationDispatcher: sessionMutationDispatcher,
      sessionCreationService: sessionCreationService,
      restartDispatcher: restartDispatcher,
      statusNotifier: _statusNotifier,
      reconnectBackoff: _reconnectBackoff,
    );
    return (
      session: session,
      catalogImportService: catalogImportService,
      catalogHydrationListener: catalogHydrationListener,
      deletedSessionStorageCleanupService: deletedSessionStorageCleanupService,
      chatHistoryReconcileService: ChatHistoryReconcileService(
        sessionRepository: sessionRepository,
        chatHistoryService: chatHistoryService,
      ),
      restartDispatcher: restartDispatcher,
      routedRequestDispatcher: routedRequestDispatcher,
      sessionRepository: sessionRepository,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      projectViewTracker: projectViewTracker,
    );
  }

  static List<int> _generateRoomKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  LocalSessionEvent _mapLocalMutation(LocalSessionMutation mutation) {
    final session = mutation.session;
    return (
      pluginId: session.pluginId,
      event: switch (mutation) {
        SessionTitleUpdated() => BridgeSseSessionUpdated(info: session.toJson(), titleChanged: true),
        SessionBranchUpdated() => BridgeSseSessionUpdated(info: session.toJson(), titleChanged: false),
        SessionDeleted() => BridgeSseSessionDeleted(info: session.toJson()),
      },
    );
  }
}

bool _gitPathExists({required String gitPath}) {
  return FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound;
}

enum OrchestratorSessionStartResult() { ready, cancelled }

/// A running bridge session with immutable runtime state.
///
/// Created by [Orchestrator.create]. Call [start] once, capture
/// [waitUntilStopped] immediately, and use [cancel] to shut down gracefully.
class OrchestratorSession._({
    required final BridgeConfig config,
    required final RelayClient _client,
    required final Stream<NormalizedSourcedBridgeEvent> _pluginEvents,
    required final PluginEventListener _pluginEventListener,
    required final SessionBindingCommitListener _sessionBindingCommitListener,
    required final SessionMutationListener _sessionMutationListener,
    required final ChatHistoryListener _chatHistoryListener,
    required final ChatHistoryActivityListener _chatHistoryActivityListener,
    required final ChatHistoryService _chatHistoryService,
    required final SessionOptionsCreationRefreshListener _sessionOptionsCreationRefreshListener,
    required final SessionOptionsChangedRefreshListener _sessionOptionsChangedRefreshListener,
    required final SessionEventDispatcher _sessionEventDispatcher,
    required final PluginRuntime _pluginRuntime,
    required final CompletionPushListener _completionListener,
    required final MaintenancePushListener _maintenanceListener,
    required final AccessTokenProvider _accessTokenProvider,
    required final TokenRefresher _tokenRefresher,
    required final BridgeRegistrationService _bridgeRegistrationService,
    required final SessionEncryptor _sessionEncryptor,
    required final KeyExchangeManager _keyExchangeManager,
    required final SSEManager _sseManager,
    required final RoutedRequestDispatcher _routedRequestDispatcher,
    required final BridgeEventMapper _mapper,
    required final SessionPromptService _sessionPromptService,
    required Stream<CatalogImportProgress> catalogImportProgress,
    required Stream<String> pluginManagementSnapshotTokens,
    required Stream<PluginInstallProgressUpdate> pluginInstallProgress,
    required Stream<PluginAuthenticationProgressUpdate> pluginAuthenticationProgress,
    required final StreamController<int> _bytesSentController,
    required final StreamController<SesoriSseEvent> _localWireEventsController,
    required final FailureReporter _failureReporter,
    required final SessionRepository _sessionRepository,
    required final PrSyncService _prSyncService,
    required final ViewedProjectPrRefreshListener _viewedProjectPrRefreshListener,
    required final CurrentProjectGlossaryListener _currentProjectGlossaryListener,
    required final ViewedProjectGlossaryListener _viewedProjectGlossaryListener,
    required final ProjectGlossaryPopulationService _projectGlossaryPopulationService,
    required final CurrentProjectService _currentProjectService,
    required final SessionUnseenService _sessionUnseenService,
    required final SessionViewTracker _sessionViewTracker,
    required final ProjectViewTracker _projectViewTracker,
    required final ProjectActivityService _projectActivityService,
    required final PermissionAutoApprovalService _permissionAutoApprovalService,
    required final YoloSettingsService _yoloSettingsService,
    required final PendingInteractionService _pendingInteractionService,
    required final SessionAbortService _sessionAbortService,
    required final SessionOperationDispatcher _sessionOperationDispatcher,
    required final SessionMutationDispatcher _sessionMutationDispatcher,
    required final SessionCreationService _sessionCreationService,
    required final BridgeRestartDispatcher _restartDispatcher,
    required final ControlStatusNotifier? _statusNotifier,
    required final ReconnectBackoffPolicy _reconnectBackoff,
  }) {
  // ignore: cancel_subscriptions - cancelled by the failure-isolated session drain.
  final CompositeSubscription _subscriptions = CompositeSubscription();
  StreamSubscription<NormalizedSourcedBridgeEvent>? _normalizedEventSubscription;
  final Map<String, Future<void>> _pluginEventProcessingTails = <String, Future<void>>{};
  final PendingOperations _inFlightRelayCompletions = PendingOperations();

  /// Part captures dispatched without awaiting, kept observable so shutdown
  /// does not close the history database out from under a finalized write.
  final PendingOperations _pendingPartCaptures = PendingOperations();
  final Map<String, int> _inFlightRouteCounts = <String, int>{};
  Future<void> _projectsSummaryTail = Future<void>.value();
  final Random _backoffJitter = Random();
  Future<void>? _lifecycleFuture;
  RelayConnection? _relayConnection;
  Future<void>? _shutdownRelayCloseFuture;

  bool _cancelled = false;

  /// When the first [cancel] was requested. Used only for shutdown timing
  /// diagnostics (the logger emits no timestamps, so durations are explicit).
  DateTime? _cancelRequestedAt;

  /// Completes when [cancel] is first called so reconnect waits wake promptly.
  final Completer<void> _shutdownCompleter = Completer<void>();
  final Completer<void> _firstPhoneConnectedCompleter = Completer<void>();

  this {
    _restartDispatcher.shutdownRequests
        .listen((request) {
          switch (request) {
            case BridgeShutdownRequest.restart:
              unawaited(
                cancel().catchError((Object error, StackTrace stackTrace) {
                  Log.w("[restart] failed to cancel the session", error, stackTrace);
                }),
              );
          }
        })
        .addTo(_subscriptions);
    catalogImportProgress
        .listen((progress) {
          _enqueueWireEvent(SesoriSseEvent.catalogImportProgress(progress: progress));
        })
        .addTo(_subscriptions);
    pluginManagementSnapshotTokens
        .listen((snapshotToken) {
          _enqueueWireEvent(SesoriSseEvent.pluginManagementChanged(snapshotToken: snapshotToken));
        })
        .addTo(_subscriptions);
    pluginInstallProgress
        .listen((update) {
          _enqueueWireEvent(
            SesoriSseEvent.pluginInstallProgress(
              pluginId: update.pluginId,
              phase: update.phase,
              percent: update.percent,
              message: update.message,
            ),
          );
        })
        .addTo(_subscriptions);
    pluginAuthenticationProgress
        .listen((update) {
          _enqueueWireEvent(
            SesoriSseEvent.pluginAuthenticationProgress(
              pluginId: update.pluginId,
              progress: update.progress,
            ),
          );
        })
        .addTo(_subscriptions);
    _sessionPromptService.promptDefaultsChanges
        .listen((change) {
          _enqueueWireEvent(
            SesoriSseEvent.sessionPromptDefaultsChanged(
              sessionID: change.sessionId,
              promptDefaults: change.promptDefaults,
            ),
          );
        })
        .addTo(_subscriptions);
  }

  /// Broadcast stream of byte counts emitted each time data is sent to a phone.
  ///
  /// Includes both API responses and SSE events. Subscribe to this stream to
  /// track bandwidth (e.g. with [BandwidthTracker]).
  Stream<int> get bytesSent => _bytesSentController.stream;
  Stream<SesoriSseEvent> get localWireEvents => _localWireEventsController.stream;

  /// Completes after the first phone finishes key exchange or resume and can
  /// send encrypted bridge traffic.
  Future<void> get firstPhoneConnected => _firstPhoneConnectedCompleter.future;
  RoutedRequestDispatcher get routedRequestDispatcher => _routedRequestDispatcher;

  /// Completes when [beginShutdown] starts the graceful shutdown, so the
  /// composition root can start the ordered shutdown coordinator (agent-work
  /// interrupt, backstop deadline) the moment the session begins tearing down.
  Future<void> get shutdownRequested => _shutdownCompleter.future;

  Future<OrchestratorSessionStartResult> start() {
    if (_lifecycleFuture != null) {
      return Future.error(StateError("OrchestratorSession has already started"), StackTrace.current);
    }

    _sessionAbortService.abortStartedSessions.listen(_completionListener.markSessionAbortPending).addTo(_subscriptions);
    _sessionAbortService.abortedSessions.listen(_completionListener.markSessionAborted).addTo(_subscriptions);
    _sessionAbortService.abortFailedSessions.listen(_completionListener.clearPendingAbort).addTo(_subscriptions);
    _completionListener.start();
    _normalizedEventSubscription = _pluginEvents.listen(
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
    );
    _sessionMutationListener.start();
    _chatHistoryListener.start();
    _sessionBindingCommitListener.start();
    _pluginEventListener.start();
    _sessionOptionsCreationRefreshListener.start();
    _sessionOptionsChangedRefreshListener.start();
    _viewedProjectPrRefreshListener.start();
    _currentProjectGlossaryListener.start();
    _viewedProjectGlossaryListener.start();
    _chatHistoryActivityListener.start();
    final readiness = Completer<OrchestratorSessionStartResult>();
    final lifecycleFuture = Future<void>.microtask(
      () => _runLifecycle(readiness: readiness),
    );
    _lifecycleFuture = lifecycleFuture;
    lifecycleFuture.ignore();
    return readiness.future;
  }

  Future<void> waitUntilStopped() {
    final lifecycleFuture = _lifecycleFuture;
    if (lifecycleFuture == null) {
      return Future.error(StateError("OrchestratorSession has not started"), StackTrace.current);
    }
    return lifecycleFuture;
  }

  Future<void> _runLifecycle({
    required Completer<OrchestratorSessionStartResult> readiness,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    try {
      await _startAndServe(readiness: readiness);
    } on Object catch (error, stackTrace) {
      if (!_cancelled) {
        firstError = error;
        firstStackTrace = stackTrace;
      }
    }

    try {
      await _teardown();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (!readiness.isCompleted) {
      if (_cancelled) {
        readiness.complete(OrchestratorSessionStartResult.cancelled);
      } else {
        final error = firstError ?? StateError("OrchestratorSession stopped before becoming ready");
        final stackTrace = firstStackTrace ?? StackTrace.current;
        firstError = error;
        firstStackTrace = stackTrace;
        readiness.completeError(error, stackTrace);
      }
    }

    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStackTrace ?? StackTrace.current);
    }
  }

  Future<void> _startAndServe({
    required Completer<OrchestratorSessionStartResult> readiness,
  }) async {
    final activePhoneIncarnations = <int, Object>{};

    Log.d("registering bridge with auth server...");
    await _bridgeRegistrationService.ensureRegistered();
    Log.d("bridge registered");
    if (_cancelled) return;

    Log.d("connecting to relay...");
    final relayConnection = await _client.connect();
    _relayConnection = relayConnection;
    Log.d("relay connected");
    if (_cancelled) {
      final closeFuture = _client.closeIfCurrent(connection: relayConnection);
      if (identical(_relayConnection, relayConnection)) {
        _relayConnection = null;
      }
      await closeFuture;
      return;
    }

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

    if (_yoloSettingsService.currentSettings.enabled) await _permissionAutoApprovalService.approvePending();
    final startupSummary = await _buildProjectsSummary();
    if (startupSummary != null) {
      _completionListener.handleSseEvent(startupSummary);
      if (startupSummary is SesoriProjectsSummary) {
        _statusNotifier?.handleProjectsSummary(summary: startupSummary);
      }
    }
    _prSyncService.renderedChanges
        .listen((change) {
          _enqueueWireEvent(SesoriSseEvent.sessionsUpdated(projectID: change.projectId));
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
              lastUserActivityAt: change.lastUserActivityAt,
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
    // same-user token rotation (TokenService refreshing near expiry during
    // metadata generation or push sends, or the GUI pushing a routine refresh)
    // keeps the open socket fully valid. Dropping it would disconnect every
    // phone mid-flight for nothing — see [_requiresRelayReauth].
    _accessTokenProvider.tokenStream
        .where(_requiresRelayReauth)
        .listen((token) => unawaited(_reauthenticateRelay()))
        .addTo(_subscriptions);

    Console.message("Relay:  ${config.relayURL}");
    Console.message("Waiting for relay events...");

    await _serveRelayConnections(
      readiness: readiness,
      initialConnection: relayConnection,
      activePhoneIncarnations: activePhoneIncarnations,
    );
  }

  Future<void> _teardown() async {
    _routedRequestDispatcher.beginShutdown();
    _sessionCreationService.beginShutdown();
    _prSyncService.beginShutdown();
    _projectGlossaryPopulationService.beginShutdown();
    final teardownSw = Stopwatch()..start();
    Object? firstTeardownError;
    StackTrace? firstTeardownStackTrace;

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
      "${_inFlightRelayWorkDiagnostic(separator: ", ")})",
    );
    await Future.wait([
      attempt(_subscriptions.cancel),
      attempt(_pluginEventListener.dispose),
      attempt(_sessionBindingCommitListener.dispose),
      attempt(_chatHistoryListener.dispose),
      attempt(_chatHistoryActivityListener.dispose),
      attempt(_currentProjectGlossaryListener.dispose),
      attempt(_viewedProjectGlossaryListener.dispose),
    ]);
    Log.v("[shutdown] event producers cancelled (+${teardownSw.elapsedMilliseconds}ms)");
    await Future.wait([attempt(_routedRequestDispatcher.drain), attempt(_drainRelayCompletions)]);
    await Future.wait([
      attempt(_currentProjectService.dispose),
      attempt(_projectGlossaryPopulationService.dispose),
    ]);
    Log.v(
      "[shutdown] routed requests and relay completions drained "
      "(+${teardownSw.elapsedMilliseconds}ms)",
    );
    await attempt(_sessionCreationService.drain);
    Log.v("[shutdown] late session titles drained (+${teardownSw.elapsedMilliseconds}ms)");
    _sessionOperationDispatcher.beginShutdown();
    await attempt(_sessionOperationDispatcher.dispose);
    Log.v("[shutdown] session operations drained (+${teardownSw.elapsedMilliseconds}ms)");
    await attempt(_sessionMutationDispatcher.dispose);
    await attempt(_sessionMutationListener.dispose);
    await attempt(_sessionEventDispatcher.dispose);
    await attempt(() async {
      await Future.wait(_pluginEventProcessingTails.values);
      // After the tails, because a processed event may have just dispatched
      // its capture.
      await _pendingPartCaptures.drain();
    });
    await attempt(() => _normalizedEventSubscription?.cancel());
    await Future.wait([
      attempt(_permissionAutoApprovalService.dispose),
      attempt(_sessionPromptService.dispose),
      attempt(_sessionAbortService.dispose),
    ]);
    await attempt(_pendingInteractionService.dispose);
    await Future.wait([
      attempt(_sessionOptionsCreationRefreshListener.dispose),
      attempt(_sessionOptionsChangedRefreshListener.dispose),
    ]);
    await attempt(_projectActivityService.dispose);
    Log.v("[shutdown] project activity service disposed (+${teardownSw.elapsedMilliseconds}ms)");
    await attempt(_completionListener.dispose);
    Log.v("[shutdown] completion listener disposed (+${teardownSw.elapsedMilliseconds}ms)");
    await attempt(_maintenanceListener.dispose);
    await attempt(_viewedProjectPrRefreshListener.dispose);
    await attempt(_prSyncService.drain);
    Log.v("[shutdown] maintenance + pr-sync listeners disposed (+${teardownSw.elapsedMilliseconds}ms)");
    // Plugin teardown is owned by BridgePlugin.shutdown(), run as the
    // shutdown coordinator's ordered step — the deprecated direct
    // api.dispose() call is gone since the descriptor flip.
    Log.v("stopping sse manager...");
    await attempt(_sseManager.stop);
    Log.v("sse manager stopped (+${teardownSw.elapsedMilliseconds}ms)");
    await Future.wait([
      attempt(_localWireEventsController.close),
      attempt(_bytesSentController.close),
    ]);
    await attempt(() async {
      Log.v("closing relay client...");
      _shutdownRelayCloseFuture ??= _closeRelayConnection();
      await _shutdownRelayCloseFuture!;
      Log.v("relay client closed (+${teardownSw.elapsedMilliseconds}ms)");
    });
    Log.d("[shutdown] session teardown complete (${teardownSw.elapsedMilliseconds}ms total)");
    if (firstTeardownError != null) {
      Error.throwWithStackTrace(firstTeardownError!, firstTeardownStackTrace!);
    }
  }

  Future<void> _serveRelayConnections({
    required Completer<OrchestratorSessionStartResult> readiness,
    required RelayConnection initialConnection,
    required Map<int, Object> activePhoneIncarnations,
  }) async {
    var connection = initialConnection;
    while (!_cancelled) {
      final iterator = StreamIterator<RelayClientMessage>(
        _client.read(connection: connection),
      );
      final firstRead = iterator.moveNext();
      if (!readiness.isCompleted) {
        readiness.complete(OrchestratorSessionStartResult.ready);
      }

      try {
        try {
          await _runRelayLoop(
            iterator: iterator,
            firstRead: firstRead,
            connection: connection,
            activePhoneIncarnations: activePhoneIncarnations,
          );
        } on Object catch (error, stackTrace) {
          if (_cancelled) break;
          Log.w("relay loop ended", error, stackTrace);
        }
      } finally {
        try {
          await iterator.cancel();
        } on Object catch (error, stackTrace) {
          Log.w("Failed to cancel relay read iterator", error, stackTrace);
        }
      }

      if (_cancelled) {
        break;
      }

      Log.w("Relay connection lost. Reconnecting...");
      _sseManager.orphanAll();
      activePhoneIncarnations.clear();
      // Every phone connection died with the relay link; drop their view
      // declarations so no session stays "watched" by a ghost connection.
      // Phones re-assert their current view on reconnect.
      _sessionViewTracker.clearAll();
      _projectViewTracker.clearAll();

      if (_client.closeCode(connection: connection) == RelayCloseCodes.bridgeRevoked) {
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
        closeCode: _client.closeCode(connection: connection),
        closeReason: _client.closeReason(connection: connection),
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
          if (_cancelled) {
            return;
          }
          final closeFuture = _client.closeIfCurrent(connection: connection);
          if (identical(_relayConnection, connection)) {
            _relayConnection = null;
          }
          await closeFuture;
          if (_cancelled) {
            return;
          }
          final reconnectFuture = _client.connect();
          final reconnected = await reconnectFuture;
          if (_cancelled) {
            await _client.closeIfCurrent(connection: reconnected);
            return;
          }
          connection = reconnected;
          _relayConnection = reconnected;
        } on Object catch (error, stackTrace) {
          Log.w("Reconnect failed (retrying in $backoff)", error, stackTrace);
          backoff = _nextBackoff(backoff, takenOver: takenOver);
          continue;
        }

        backoff = _initialBackoff(takenOver: takenOver);
        Log.i("Reconnected to relay");
        break;
      }
    }
  }

  void beginShutdown() {
    _routedRequestDispatcher.beginShutdown();
    _sessionCreationService.beginShutdown();
    _prSyncService.beginShutdown();
    _projectGlossaryPopulationService.beginShutdown();
    if (_cancelRequestedAt == null) {
      _cancelRequestedAt = DateTime.now();
      Log.d(
        "[shutdown] cancel() requested"
        "${_inFlightRelayWorkDiagnostic(separator: " — ")}",
      );
    } else {
      Log.v("[shutdown] cancel() again (already shutting down)");
    }
    _cancelled = true;
    if (!_shutdownCompleter.isCompleted) {
      _shutdownCompleter.complete();
    }
    _shutdownRelayCloseFuture ??= _closeRelayConnection();
    unawaited(_shutdownRelayCloseFuture);
  }

  Future<void> cancel() async {
    beginShutdown();
    final sw = Stopwatch()..start();
    final shutdownRelayCloseFuture = _shutdownRelayCloseFuture;
    if (shutdownRelayCloseFuture == null) {
      throw StateError("Relay shutdown was not started");
    }
    await shutdownRelayCloseFuture;
    Log.d("[shutdown] cancel(): relay client closed in ${sw.elapsedMilliseconds}ms");
  }

  Future<void> _closeRelayConnection() async {
    final connection = _relayConnection;
    if (connection == null) {
      await _client.cancelPendingConnection();
      return;
    }
    final closeFuture = _client.closeIfCurrent(connection: connection);
    if (identical(_relayConnection, connection)) {
      _relayConnection = null;
    }
    await closeFuture;
  }

  void _trackRelayCompletion({
    required Future<void> completion,
    required RouteIdentity? routeIdentity,
  }) {
    final routeLabel = routeIdentity?.diagnosticLabel;
    if (routeLabel != null) {
      _inFlightRouteCounts.update(routeLabel, (count) => count + 1, ifAbsent: () => 1);
    }

    _inFlightRelayCompletions
        .track(
          operation: () async {
            try {
              await completion;
            } finally {
              if (routeLabel != null) {
                final remaining = _inFlightRouteCounts[routeLabel]! - 1;
                if (remaining == 0) {
                  _inFlightRouteCounts.remove(routeLabel);
                } else {
                  _inFlightRouteCounts[routeLabel] = remaining;
                }
              }
            }
          }(),
        )
        .ignore();
  }

  Future<void> _drainRelayCompletions() async {
    await _inFlightRelayCompletions.drain();
  }

  String _inFlightRelayWorkDiagnostic({required String separator}) {
    if (_inFlightRelayCompletions.isEmpty) return "";
    final routes = [
      for (final MapEntry(key: label, value: count) in _inFlightRouteCounts.entries)
        count == 1 ? label : "$label x$count",
    ];
    return "$separator${_inFlightRelayCompletions.length} in-flight relay completion(s)"
        "${routes.isEmpty ? "" : ": ${routes.join(", ")}"}";
  }

  Future<void> _processPluginEventInOrder(NormalizedSourcedBridgeEvent source) {
    final previous = _pluginEventProcessingTails[source.pluginId] ?? Future<void>.value();
    final release = Completer<void>();
    _pluginEventProcessingTails[source.pluginId] = release.future;
    return () async {
      await previous;
      try {
        if (!_isCurrentSource(
          pluginId: source.pluginId,
          generation: source.generation,
          allowDuringStop: source.allowDuringStop,
        )) {
          return;
        }
        await _processPluginEvent(source);
      } finally {
        final consumed = source.terminalHandoffConsumed;
        if (consumed != null && !consumed.isCompleted) consumed.complete();
        release.complete();
      }
    }();
  }

  Future<void> _processPluginEvent(NormalizedSourcedBridgeEvent source) async {
    final pluginId = source.pluginId;
    final generation = source.generation;
    final sourcedEvent = source.event;
    final allowDuringStop = source.allowDuringStop;
    final terminalHandoff = sourcedEvent is BridgeSseTerminalHandoff;
    final event = switch (sourcedEvent) {
      BridgeSseTerminalHandoff(:final event) => event,
      _ => sourcedEvent,
    };
    try {
      Log.v("[sse] plugin event arrived: ${event.runtimeType}");

      if (event is BridgeSsePermissionReplied) {
        final wasAutoApproved = _permissionAutoApprovalService.consumeReply(
          requestId: event.requestID,
          sessionId: event.sessionID,
        );
        if (wasAutoApproved) return;
      }

      if (_yoloSettingsService.currentSettings.enabled && event is BridgeSsePermissionAsked) {
        if (_cancelled) return;
        await _permissionAutoApprovalService.approve(
          requestId: event.requestID,
          sessionId: event.sessionID,
        );
        return;
      }

      if (event is BridgeSseServerConnected) {
        await _projectActivityService.reconcile(pluginId: pluginId).catchError((Object e, StackTrace st) {
          Log.w("ProjectActivityService: server-connected reconciliation failed", e, st);
        });
        if (_yoloSettingsService.currentSettings.enabled) await _permissionAutoApprovalService.approvePending();
      }

      if (_yoloSettingsService.currentSettings.enabled && event is BridgeSseProjectUpdated && !terminalHandoff) {
        await _permissionAutoApprovalService.approvePending();
      }

      // An ended turn can strand tool parts in a non-terminal state — a
      // permission never answered, an abort, a backend process death. The
      // backend will never complete them, so finalize the stored snapshots and
      // tell subscribers before the idle event lands.
      if (event case BridgeSseSessionIdle(:final sessionID)) {
        await _finalizeOpenToolParts(
          sessionId: sessionID,
          pluginId: pluginId,
          generation: generation,
          allowDuringStop: allowDuringStop,
        );
      }

      final refreshProjectsSummary = event is BridgeSseProjectUpdated || event is BridgeSseSessionDeleted;
      final SseEventDelivery? delivery;
      if (event is BridgeSseMessagePartUpdated) {
        delivery = await _captureAndShapePart(
          part: event.part,
          shouldCapture: () => _isCurrentSource(
            pluginId: pluginId,
            generation: generation,
            allowDuringStop: allowDuringStop,
          ),
        );
      } else {
        bool shouldCapture() => _isCurrentSource(
          pluginId: pluginId,
          generation: generation,
          allowDuringStop: allowDuringStop,
        );
        if (event case BridgeSseMessageRemoved(:final sessionID, :final messageID)) {
          await _chatHistoryService.captureMessageRemoved(
            sessionId: sessionID,
            messageId: messageID,
            shouldCapture: shouldCapture,
          );
        }
        if (event case BridgeSseMessagePartRemoved(:final sessionID, :final messageID, :final partID)) {
          await _chatHistoryService.capturePartRemoved(
            sessionId: sessionID,
            messageId: messageID,
            partId: partID,
            shouldCapture: shouldCapture,
          );
        }
        final sesoriEvent = event is BridgeSseProjectUpdated ? null : _mapper.map(event: event, pluginId: pluginId);
        delivery = sesoriEvent == null ? null : SseEventDelivery.uniform(event: sesoriEvent);
      }
      if (!_isCurrentSource(
        pluginId: pluginId,
        generation: generation,
        allowDuringStop: allowDuringStop,
      )) {
        return;
      }
      if (delivery != null) {
        await _deliverSseEvent(
          delivery: delivery,
          pluginId: pluginId,
          generation: generation,
          allowDuringStop: allowDuringStop,
        );
      } else if (!refreshProjectsSummary) {
        Log.v("[sse] mapping returned null — event dropped");
      }

      // Both trigger types mean activity changed. Rebuild from repository data
      // after delivering session.deleted so clients observe deletion first.
      if (refreshProjectsSummary) {
        if (!_isCurrentSource(
          pluginId: pluginId,
          generation: generation,
          allowDuringStop: allowDuringStop,
        )) {
          return;
        }
        await _buildAndDeliverProjectsSummaryInOrder(
          pluginId: pluginId,
          generation: generation,
          allowDuringStop: allowDuringStop,
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

  /// Finalizes tool parts stranded by the ended turn and delivers each
  /// rewritten part to subscribers as an ordinary part update.
  Future<void> _finalizeOpenToolParts({
    required String sessionId,
    required String pluginId,
    required int? generation,
    required bool allowDuringStop,
  }) async {
    final List<CapturedPartShapes> finalized;
    try {
      finalized = await _chatHistoryService.finalizeOpenToolParts(sessionId: sessionId);
    } catch (e, st) {
      Log.w("failed to finalize open tool parts for session $sessionId", e, st);
      return;
    }
    for (final shapes in finalized) {
      await _deliverSseEvent(
        delivery: SseEventDelivery.attachmentShaped(
          inlineEvent: _mapper.buildMessagePartEvent(part: shapes.inlinePart),
          storedReferenceEvent: _mapper.buildMessagePartEvent(part: shapes.storedReferencePart),
        ),
        pluginId: pluginId,
        generation: generation,
        allowDuringStop: allowDuringStop,
      );
    }
  }

  /// Stores one finalized part and returns the event shapes its subscribers
  /// may receive, or null when the part is not visible on the wire.
  ///
  /// Capture is the Orchestrator's job for every part, not only image-bearing
  /// ones: the parts of one message must enter the session queue in the order
  /// the plugin emitted them, and only this path observes that order once an
  /// image part has to be awaited.
  Future<SseEventDelivery?> _captureAndShapePart({
    required PluginMessagePart part,
    required bool Function() shouldCapture,
  }) async {
    if (part.type == PluginMessagePartType.unknown) return null;
    final sharedPart = _mapper.mapMessagePart(part: part);
    final visible = _mapper.isMessagePartVisible(part: part);
    if (!_chatHistoryService.requiresAwaitedAttachmentCapture(part: sharedPart)) {
      // Deliberately not awaited: an ordinary part's wire shape does not depend
      // on its write, and the queue it just joined preserves the order.
      final capture = _chatHistoryService.capturePart(sessionId: sharedPart.sessionID, part: sharedPart);
      unawaited(_pendingPartCaptures.track(operation: capture));
      return visible ? SseEventDelivery.uniform(event: _mapper.buildMessagePartEvent(part: sharedPart)) : null;
    }

    final captured = await _chatHistoryService.capturePartForDelivery(
      sessionId: sharedPart.sessionID,
      part: sharedPart,
      shouldCapture: shouldCapture,
    );
    if (!visible) return null;
    return switch (captured) {
      CapturedPartShapes(:final inlinePart, :final storedReferencePart) => SseEventDelivery.attachmentShaped(
        inlineEvent: _mapper.buildMessagePartEvent(part: inlinePart),
        storedReferenceEvent: _mapper.buildMessagePartEvent(part: storedReferencePart),
      ),
      // The write did not land, so no identifier is addressable. Metadata keeps
      // every subscriber within the released aggregate wire budget without
      // relying on unavailable stored sibling state.
      CapturedPartUnavailable(:final inlineFallbackPart) => SseEventDelivery.uniform(
        event: _mapper.buildMessagePartEvent(part: inlineFallbackPart),
      ),
    };
  }

  Future<void> _deliverSseEvent({
    required SseEventDelivery delivery,
    required String pluginId,
    required int? generation,
    required bool allowDuringStop,
  }) async {
    if (!_isCurrentSource(pluginId: pluginId, generation: generation, allowDuringStop: allowDuringStop)) return;
    // Bridge-local consumers observe the released inline shape; only the wire
    // is shaped per subscriber.
    final event = delivery.inlineEvent;
    final upsertSessionId = switch (event) {
      SesoriSessionCreated(:final info) || SesoriSessionUpdated(:final info) => info.id,
      _ => null,
    };
    if (upsertSessionId != null &&
        _sessionMutationDispatcher.shouldSuppressEventsForSession(sessionId: upsertSessionId)) {
      Log.v("[sse] dropping ${event.runtimeType} for a deleting or deleted session");
      return;
    }
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
    if (!_isCurrentSource(pluginId: pluginId, generation: generation, allowDuringStop: allowDuringStop)) return;
    if (upsertSessionId != null &&
        _sessionMutationDispatcher.shouldSuppressEventsForSession(sessionId: upsertSessionId)) {
      return;
    }
    _enqueueDelivery(delivery);
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
    required String pluginId,
    required int? generation,
    required bool allowDuringStop,
  }) {
    return _enqueueProjectsSummaryInOrder(
      operation: () async {
        if (!_isCurrentSource(pluginId: pluginId, generation: generation, allowDuringStop: allowDuringStop)) return;
        final summary = await _buildProjectsSummary();
        if (summary != null) {
          await _deliverSseEvent(
            delivery: SseEventDelivery.uniform(event: summary),
            pluginId: pluginId,
            generation: generation,
            allowDuringStop: allowDuringStop,
          );
        }
      },
    );
  }

  Future<void> _enqueueProjectsSummaryInOrder({required Future<void> Function() operation}) {
    final previous = _projectsSummaryTail;
    final release = Completer<void>();
    _projectsSummaryTail = release.future;
    return () async {
      await previous;
      try {
        await operation();
      } finally {
        release.complete();
      }
    }();
  }

  bool _isCurrentSource({
    required String pluginId,
    required int? generation,
    required bool allowDuringStop,
  }) {
    if (generation == null) return true;
    return _pluginRuntime.isCurrentEvent(
      pluginId: pluginId,
      generation: generation,
      allowDuringStop: allowDuringStop,
    );
  }

  void _enqueueWireEvent(SesoriSseEvent event) => _enqueueDelivery(SseEventDelivery.uniform(event: event));

  void _enqueueDelivery(SseEventDelivery delivery) {
    _sseManager.enqueueEvent(delivery);
    // The local debug stream has no capability surface of its own, so it keeps
    // the released inline shape.
    if (!_localWireEventsController.isClosed) _localWireEventsController.add(delivery.inlineEvent);
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
  /// [TokenService] whose token store was deleted on logout). In both cases the
  /// caller MUST NOT reconnect — there is no safe token to authenticate with.
  ///
  /// Returns `true` when a refresh succeeds, or when a refresh fails for a reason
  /// other than unavailability AND a usable cached token still exists (e.g.
  /// standalone [TokenService] hitting a transiently-down auth-refresh endpoint
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
  /// - the last connect sent no auth at all (its connection-scoped
  ///   [RelayClient.lastAuthedToken] is
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
    final connection = _relayConnection;
    if (connection == null) return false;
    final String? lastAuthed = _client.lastAuthedToken(connection: connection);
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
  /// loop, after which the serving loop's reconnect block force-pulls the new token and
  /// reconnects — the same path a relay-side drop drives. No-op once cancelled
  /// so a token emit during shutdown can't fight teardown.
  Future<void> _reauthenticateRelay() async {
    if (_cancelled) return;
    final connection = _relayConnection;
    if (connection == null) return;
    // If the socket has already closed (closeCode is set), the read loop is
    // about to end on its own and the reconnect block will inspect the close
    // code. Don't deliberately detach it here, which would mask a bridgeRevoked
    // close and skip re-registration. Let the natural drop path handle it; the
    // fresh token is picked up on reconnect.
    if (_client.closeCode(connection: connection) != null) {
      Log.d("Token updated while the relay was already closing — letting the drop path reconnect");
      return;
    }
    Log.i("Access token updated while connected — re-authenticating relay");
    try {
      await _closeRelayConnection();
    } on Object catch (error, stackTrace) {
      // Best-effort: if the close fails the read loop still ends on the broken
      // socket and the reconnect block recovers, so log and continue.
      Log.w("Failed to close relay for token re-auth", error, stackTrace);
    }
  }

  Future<void> _runRelayLoop({
    required StreamIterator<RelayClientMessage> iterator,
    required Future<bool> firstRead,
    required RelayConnection connection,
    required Map<int, Object> activePhoneIncarnations,
  }) async {
    var hasMessage = await firstRead;
    while (hasMessage) {
      processMessage:
      {
        final msg = iterator.current;
        if (_cancelled) {
          return;
        }

        Log.v("relay msg: isText=${msg.isText} len=${msg.data.length}");

        if (msg.isText) {
          Map<String, dynamic> control;
          try {
            control = jsonDecodeMap(utf8.decode(msg.data));
          } on Object catch (error, stackTrace) {
            Log.w("failed to parse relay control message", error, stackTrace);
            break processMessage;
          }

          final type = control["type"] as String?;
          final connID = control["connId"] as int?;
          Log.v("control: type=$type connID=$connID");
          if (type == null || connID == null) {
            Log.v("dropping relay control message with missing fields");
            break processMessage;
          }

          switch (type) {
            case "phone_connected":
              Log.v("phone_connected connID=$connID");
            case "phone_disconnected":
              Log.v("phone_disconnected connID=$connID");
              activePhoneIncarnations.remove(connID);
              _sseManager.unsubscribe(connID);
              _sessionViewTracker.releaseConnection(connID: connID);
              _projectViewTracker.releaseConnection(connID: connID);
          }
          break processMessage;
        }

        if (msg.data.length < 2) {
          Log.v("binary too short: ${msg.data.length}");
          break processMessage;
        }

        final connID = ByteData.sublistView(msg.data).getUint16(0, Endian.big);
        final payload = Uint8List.sublistView(msg.data, 2);
        if (payload.isEmpty) {
          Log.v("empty payload for connID=$connID");
          break processMessage;
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
            break processMessage;
          }

          Log.v("parsed: ${relayMessage.runtimeType}");

          if (relayMessage is! RelayKeyExchange) {
            Log.v("not a key exchange, skipping");
            break processMessage;
          }

          Uint8List encrypted;
          try {
            encrypted = await _keyExchangeManager.handleKeyExchange(message: relayMessage);
            Log.d("key exchange OK, sending ready to connID=$connID");
          } catch (e) {
            Log.e("failed key exchange for connId $connID: $e");
            break processMessage;
          }

          try {
            final outcome = _sendIfCurrent(
              connection: connection,
              connID: connID,
              payload: encrypted,
            );
            if (outcome == RelaySendOutcome.stale) {
              throw StateError("relay connection changed before key exchange completed");
            }
            Log.d("ready sent to connID=$connID");
          } catch (e) {
            if (_cancelled) {
              throw StateError("cancelled");
            }
            throw Exception("send ready for connId $connID: $e");
          }

          _markPhoneConnected(connID: connID, activePhoneIncarnations: activePhoneIncarnations);
          break processMessage;
        }

        Log.v(
          "checking protocolVersion: payload[0]=0x${payload[0].toRadixString(16)} expected=0x${protocolVersion.toRadixString(16)}",
        );
        if (payload[0] == protocolVersion) {
          List<int>? decrypted;
          Object? decryptError;
          try {
            decrypted = await unframe(payload, encryptor: _sessionEncryptor);
          } catch (e) {
            decryptError = e;
          }

          final phoneIncarnation = activePhoneIncarnations[connID];
          if (phoneIncarnation != null) {
            if (decryptError != null || decrypted == null) {
              Log.v(
                "failed to decrypt from connId $connID: $decryptError",
              );
              break processMessage;
            }
            Log.v("decrypted OK from connID=$connID, handling...");
            _handleDecryptedMessage(
              connection: connection,
              connID: connID,
              decrypted: decrypted,
              phoneIncarnation: phoneIncarnation,
              activePhoneIncarnations: activePhoneIncarnations,
            );
            Log.v("handled message from connID=$connID");
            break processMessage;
          }

          if (decryptError != null || decrypted == null) {
            Log.v("not active, decrypt failed for connID=$connID: $decryptError — sending rekeyRequired");
            final rekeyRequired = jsonEncode(
              const RelayMessage.rekeyRequired().toJson(),
            );
            try {
              _sendIfCurrent(
                connection: connection,
                connID: connID,
                payload: Uint8List.fromList(utf8.encode(rekeyRequired)),
              );
            } catch (_) {
              if (_cancelled) {
                throw StateError("cancelled");
              }
            }
            break processMessage;
          }

          RelayMessage parsedMessage;
          try {
            parsedMessage = RelayMessage.fromJson(
              jsonDecodeMap(utf8.decode(decrypted)),
            );
          } catch (_) {
            break processMessage;
          }

          if (parsedMessage is! RelayResume) {
            break processMessage;
          }

          final ackJSON = utf8.encode(
            jsonEncode(const RelayMessage.resumeAck().toJson()),
          );
          Uint8List encryptedAck;
          try {
            encryptedAck = await frame(ackJSON, encryptor: _sessionEncryptor);
          } catch (_) {
            break processMessage;
          }

          try {
            final outcome = _sendIfCurrent(
              connection: connection,
              connID: connID,
              payload: encryptedAck,
            );
            if (outcome == RelaySendOutcome.stale) {
              throw StateError("relay connection changed before resume completed");
            }
          } catch (e) {
            if (_cancelled) {
              throw StateError("cancelled");
            }
            throw Exception("send resume ack for connId $connID: $e");
          }

          _markPhoneConnected(connID: connID, activePhoneIncarnations: activePhoneIncarnations);
        }
      }
      hasMessage = await iterator.moveNext();
    }
  }

  void _markPhoneConnected({
    required int connID,
    required Map<int, Object> activePhoneIncarnations,
  }) {
    activePhoneIncarnations[connID] = Object();
    if (!_firstPhoneConnectedCompleter.isCompleted) {
      _firstPhoneConnectedCompleter.complete();
    }
    Log.d("phone $connID is now active");
  }

  void _handleDecryptedMessage({
    required RelayConnection connection,
    required int connID,
    required List<int> decrypted,
    required Object phoneIncarnation,
    required Map<int, Object> activePhoneIncarnations,
  }) {
    RelayMessage msg;
    try {
      msg = RelayMessage.fromJson(
        jsonDecodeMap(utf8.decode(decrypted)),
      );
    } on Object catch (error, stackTrace) {
      Log.w("failed to parse encrypted relay message from connID=$connID", error, stackTrace);
      return;
    }

    Log.v("decrypted msg type: ${msg.runtimeType}");

    switch (msg) {
      case final RelayRequest req:
        Log.v("RelayRequest: ${req.method} ${req.path}");
        final dispatch = _routedRequestDispatcher.dispatch(request: req);
        switch (dispatch) {
          case final RoutedRequestShutdownRejected rejected:
            _trackRelayCompletion(
              completion: _completeShutdownRejection(
                connection: connection,
                connID: connID,
                response: rejected.response,
                phoneIncarnation: phoneIncarnation,
                activePhoneIncarnations: activePhoneIncarnations,
              ),
              routeIdentity: null,
            );
          case final RoutedRequestAccepted accepted:
            final pendingRoute = accepted.pendingRequest;
            _trackRelayCompletion(
              completion: _completeRoutedRequest(
                connection: connection,
                connID: connID,
                pendingRoute: pendingRoute,
                phoneIncarnation: phoneIncarnation,
                activePhoneIncarnations: activePhoneIncarnations,
              ),
              routeIdentity: pendingRoute.routeIdentity,
            );
        }
      case final RelaySseSubscribe subscribe:
        Log.v("SseSubscribe: path=${subscribe.path} attachments=${subscribe.attachmentDelivery.name}");
        try {
          _sseManager.subscribePath(
            connID: connID,
            path: subscribe.path,
            client: _client,
            connection: connection,
            attachmentDelivery: subscribe.attachmentDelivery,
          );
          _trackRelayCompletion(
            completion: _completeInitialProjectsSummary(connID: connID),
            routeIdentity: null,
          );
        } on Object catch (error, stackTrace) {
          Log.e("sse subscribe failed for connId $connID", error, stackTrace);
        }
      case RelaySseUnsubscribe():
        Log.v("SseUnsubscribe connID=$connID");
        _sseManager.unsubscribe(connID);
      case RelaySessionView(:final sessionId):
        Log.v("SessionView connID=$connID sessionId=$sessionId");
        _sessionViewTracker.setViewing(connID: connID, sessionId: sessionId);
      case RelayProjectView(:final projectId):
        _projectViewTracker.setViewing(connID: connID, projectId: projectId);
      default:
        Log.v("unhandled msg type: ${msg.runtimeType}");
    }
  }

  Future<void> _completeRoutedRequest({
    required RelayConnection connection,
    required int connID,
    required PendingRoutedRequest pendingRoute,
    required Object phoneIncarnation,
    required Map<int, Object> activePhoneIncarnations,
  }) async {
    final routeIdentity = pendingRoute.routeIdentity;
    final routeSw = Stopwatch()..start();
    final RoutedRequestOutcome outcome;
    try {
      outcome = await pendingRoute.completion;
    } on Object catch (error, stackTrace) {
      if (_cancelled) {
        Log.w("[shutdown] route ${routeIdentity.diagnosticLabel} failed while draining", error, stackTrace);
      } else {
        Log.e("route ${routeIdentity.diagnosticLabel} failed for connId $connID", error, stackTrace);
      }
      return;
    }

    final response = outcome.response;
    if (routeSw.elapsedMilliseconds > 1000) {
      Log.d(
        "slow route ${routeIdentity.diagnosticLabel} for connId $connID "
        "took ${routeSw.elapsedMilliseconds}ms (cancelled=$_cancelled)",
      );
    }
    Log.v("response: status=${response.status}");

    await _deliverRoutedResponse(
      connection: connection,
      connID: connID,
      response: response,
      routeIdentity: routeIdentity,
      phoneIncarnation: phoneIncarnation,
      activePhoneIncarnations: activePhoneIncarnations,
    );

    if (_cancelled) return;
    switch (outcome) {
      case ResponseOnly():
        break;
      case final RestartAccepted accepted:
        try {
          await _restartDispatcher.dispatch(restart: accepted);
        } on Object catch (error, stackTrace) {
          Log.e("route ${routeIdentity.diagnosticLabel} failed for connId $connID", error, stackTrace);
        }
    }
  }

  Future<void> _deliverRoutedResponse({
    required RelayConnection connection,
    required int connID,
    required RelayResponse response,
    required RouteIdentity routeIdentity,
    required Object phoneIncarnation,
    required Map<int, Object> activePhoneIncarnations,
  }) async {
    final ({Uint8List payload, int cleartextLength}) encrypted;
    try {
      encrypted = await _encryptRelayMessage(message: response, connID: connID);
    } on Object catch (error, stackTrace) {
      Log.e("failed to encrypt response for ${routeIdentity.diagnosticLabel} and connId $connID", error, stackTrace);
      return;
    }

    if (_cancelled) {
      Log.v(
        "[shutdown] route ${routeIdentity.diagnosticLabel} completed after cancel — "
        "dropping response (status=${response.status})",
      );
      return;
    }

    try {
      final sendOutcome = _sendEncryptedResponseIfCurrent(
        connection: connection,
        connID: connID,
        payload: encrypted.payload,
        cleartextLength: encrypted.cleartextLength,
        phoneIncarnation: phoneIncarnation,
        activePhoneIncarnations: activePhoneIncarnations,
      );
      if (sendOutcome == RelaySendOutcome.sent) {
        Log.v("response sent to connID=$connID");
      } else if (_cancelled) {
        Log.v("[shutdown] response dropped after cancellation");
        return;
      } else {
        Log.v("response dropped because its client incarnation or relay connection is stale");
      }
    } on Object catch (error, stackTrace) {
      Log.w("failed to send response for ${routeIdentity.diagnosticLabel} to connId $connID", error, stackTrace);
    }
  }

  Future<void> _completeShutdownRejection({
    required RelayConnection connection,
    required int connID,
    required RelayResponse response,
    required Object phoneIncarnation,
    required Map<int, Object> activePhoneIncarnations,
  }) async {
    try {
      final encrypted = await _encryptRelayMessage(message: response, connID: connID);
      if (_cancelled) return;
      _sendEncryptedResponseIfCurrent(
        connection: connection,
        connID: connID,
        payload: encrypted.payload,
        cleartextLength: encrypted.cleartextLength,
        phoneIncarnation: phoneIncarnation,
        activePhoneIncarnations: activePhoneIncarnations,
      );
    } on Object catch (error, stackTrace) {
      Log.w("failed to send shutdown rejection to connId $connID", error, stackTrace);
    }
  }

  Future<void> _completeInitialProjectsSummary({required int connID}) {
    return _enqueueProjectsSummaryInOrder(
      operation: () async {
        try {
          if (_cancelled) return;
          final projectsSummary = await _buildProjectsSummary();
          if (_cancelled) return;
          if (projectsSummary != null) {
            _enqueueWireEvent(projectsSummary);
            _completionListener.handleSseEvent(projectsSummary);
          }
          Log.v("initial projectsSummary enqueued");
        } on Object catch (error, stackTrace) {
          Log.e("initial projectsSummary failed for connId $connID", error, stackTrace);
        }
      },
    );
  }

  // Ordinary drop (network blip, relay restart) reconnects promptly; a
  // takeover drop reconnects on a minutes-order backoff so two always-on
  // bridges don't tight-loop kicking each other (ADR A22).

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
    if (!takenOver) return _reconnectBackoff.ordinaryInitial;
    // Jitter the takeover backoff so two mutually-displacing bridges don't
    // resynchronize onto the same retry cadence.
    return _jitter(_reconnectBackoff.takeoverInitial);
  }

  Duration _nextBackoff(Duration backoff, {required bool takenOver}) {
    final max = takenOver ? _reconnectBackoff.takeoverMax : _reconnectBackoff.ordinaryMax;
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

  Future<({Uint8List payload, int cleartextLength})> _encryptRelayMessage({
    required int connID,
    required RelayMessage message,
  }) async {
    final respJson = jsonEncode(message.toJson());
    final jsonBytes = utf8.encode(respJson);
    Log.v("[response] encrypting ${jsonBytes.length} bytes for connID=$connID");
    final framed = await frame(jsonBytes, encryptor: _sessionEncryptor);
    return (payload: framed, cleartextLength: jsonBytes.length);
  }

  RelaySendOutcome _sendEncryptedResponseIfCurrent({
    required RelayConnection connection,
    required int connID,
    required Uint8List payload,
    required int cleartextLength,
    required Object phoneIncarnation,
    required Map<int, Object> activePhoneIncarnations,
  }) {
    if (_cancelled) return RelaySendOutcome.stale;
    if (!identical(activePhoneIncarnations[connID], phoneIncarnation)) return RelaySendOutcome.stale;
    if (!identical(_relayConnection, connection)) return RelaySendOutcome.stale;
    final outcome = _sendIfCurrent(
      connection: connection,
      connID: connID,
      payload: payload,
    );
    if (outcome == RelaySendOutcome.sent) {
      _bytesSentController.add(cleartextLength);
    }
    return outcome;
  }

  RelaySendOutcome _sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required Uint8List payload,
  }) {
    try {
      return _client.sendIfCurrent(
        connection: connection,
        connID: connID,
        payload: payload,
      );
    } on Object {
      final closeFuture = _client.closeIfCurrent(connection: connection);
      if (identical(_relayConnection, connection)) {
        _relayConnection = null;
      }
      unawaited(
        closeFuture.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            Log.w("Failed to close relay after send failure", error, stackTrace);
          },
        ),
      );
      rethrow;
    }
  }
}

/// Reconnect backoff durations used by the relay loop.
///
/// Injectable so tests can exercise backoff and takeover scenarios with
/// milliseconds-order waits instead of real minutes; production uses
/// [ReconnectBackoffPolicy.standard].
class const ReconnectBackoffPolicy({
    /// Backoff for a plain network drop (network blip, relay restart).
  required final Duration ordinaryInitial,
    required final Duration ordinaryMax,
    /// Backoff for a takeover drop, so two always-on bridges don't tight-loop
  /// kicking each other (ADR A22).
  required final Duration takeoverInitial,
    required final Duration takeoverMax,
  }) {
  static const ReconnectBackoffPolicy standard = ReconnectBackoffPolicy(
    ordinaryInitial: Duration(seconds: 1),
    ordinaryMax: Duration(seconds: 30),
    takeoverInitial: Duration(minutes: 2),
    takeoverMax: Duration(minutes: 5),
  );
}
