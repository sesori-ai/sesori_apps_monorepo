import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/storage/session_launch_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/local_send_phase.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_abort_outcome.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_notice.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/composer/new_session_submission_snapshot.dart";
import "package:sesori_dart_core/src/foundation/models/composer/prompt_send_failure.dart";
import "package:sesori_dart_core/src/foundation/models/composer/queued_session_submission.dart";
import "package:sesori_dart_core/src/foundation/models/composer/unsent_composer.dart";
import "package:sesori_dart_core/src/foundation/models/session_launch/launch_follow_up.dart";
import "package:sesori_dart_core/src/foundation/models/session_launch/session_launch.dart";
import "package:sesori_dart_core/src/foundation/models/session_launch/session_launch_composer.dart";
import "package:sesori_dart_core/src/foundation/models/session_launch/session_launch_handoff.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_not_accepted_exception.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_rejected_exception.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/session_launch_repository.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_dart_core/src/services/session_approval_service.dart";
import "package:sesori_dart_core/src/services/session_auto_continuation_service.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_dart_core/src/services/session_interaction_calculator.dart";
import "package:sesori_dart_core/src/services/session_launch_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "../../services/session_interaction_calculator_test.dart" show managementFixture;

const _sessionId = "session-1";

/// The text part that makes [messageId] renderable — production user
/// envelopes are always followed by one.
SesoriMessagePartUpdated _textPartFor({required String messageId, required String text}) => SesoriMessagePartUpdated(
  part: MessagePart.text(
    id: "$messageId-text",
    sessionID: _sessionId,
    messageID: messageId,
    text: text,
  ),
);

const _queuedPrompt = QueuedSessionPrompt(
  commandSource: null,
  id: "prm_1",
  text: "steer it",
  command: null,
  attachmentCount: 0,
  createdAt: 100,
);

const _reviewCommand = CommandInfo(
  name: "review",
  template: null,
  hints: null,
  description: "Review this project",
  agent: null,
  model: null,
  provider: null,
  source: CommandSource.command,
  subtask: null,
);

SessionOptionsRepositoryResult _freshClaudeOptions() => SessionOptionsRepositoryAvailable(
  isStale: false,
  catalog: SessionOptionsCatalog(
    agents: const [
      AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
      AgentInfo(name: "Plan", description: "Plan", model: null, mode: AgentMode.primary),
    ],
    providers: const [],
    providersConnectedOnly: false,
    commands: const [],
    lastUsedPromptDefaults: null,
  ),
);

ProviderListResponse _providerDataWithVariants(List<String> variants) => ProviderListResponse(
  items: [
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      defaultModelID: "claude-opus",
      models: {
        "claude-opus": ProviderModel(
          fastMode: null,
          id: "claude-opus",
          providerID: "anthropic",
          name: "Opus",
          variants: variants,
          defaultVariant: null,
          family: null,
          releaseDate: null,
        ),
      },
    ),
  ],
  connectedOnly: false,
);

const ProviderModel _opusModel = ProviderModel(
  fastMode: null,
  id: "opus",
  providerID: "anthropic",
  name: "Opus",
  variants: ["high", "max"],
  defaultVariant: "high",
  family: null,
  releaseDate: null,
);

const ProviderModel _sonnetModel = ProviderModel(
  fastMode: null,
  id: "sonnet",
  providerID: "anthropic",
  name: "Sonnet",
  variants: ["high", "max"],
  defaultVariant: "high",
  family: null,
  releaseDate: null,
);

const ProviderListResponse _claudeProvidersWithOpus = ProviderListResponse(
  connectedOnly: false,
  items: [
    ProviderInfo(id: "anthropic", name: "Anthropic", defaultModelID: "opus", models: {"opus": _opusModel}),
  ],
);

/// Claude's one agent, declaring Opus as Claude's own catalog does.
const List<AgentInfo> _claudeCatalogDeclaringOpusAgents = [
  AgentInfo(
    name: "Agent",
    description: "Agent",
    model: AgentModel(providerID: "anthropic", modelID: "opus", variant: "high"),
    mode: AgentMode.primary,
  ),
];

SessionOptionsRepositoryResult _claudeCatalogDeclaringOpus() => SessionOptionsRepositoryAvailable(
  isStale: false,
  catalog: SessionOptionsCatalog(
    agents: _claudeCatalogDeclaringOpusAgents,
    providers: _claudeProvidersWithOpus.items,
    providersConnectedOnly: false,
    commands: const [],
    lastUsedPromptDefaults: null,
  ),
);

SessionDetailLoaded _loadedState(SessionDetailCubit cubit) {
  final state = cubit.state;
  if (state is! SessionDetailLoaded) fail("expected a loaded session, got $state");
  return state;
}

SessionOptionsRepositoryResult _claudeOptionsWithVariants(List<String> variants) => SessionOptionsRepositoryAvailable(
  isStale: false,
  catalog: SessionOptionsCatalog(
    agents: const [
      AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
    ],
    providers: _providerDataWithVariants(variants).items,
    providersConnectedOnly: false,
    commands: const [],
    lastUsedPromptDefaults: null,
  ),
);

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  group("SessionDetailCubit bridge-owned queue", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late StreamController<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late List<MessageWithParts> reloadSnapshotMessages;
    late List<QueuedSessionPrompt> reloadSnapshotQueue;
    Completer<void>? reloadGate;
    late FakeFeedbackPromptService feedbackPromptService;

    setUp(() {
      reloadSnapshotMessages = const <MessageWithParts>[];
      reloadSnapshotQueue = const <QueuedSessionPrompt>[];
      reloadGate = null;
      feedbackPromptService = FakeFeedbackPromptService();
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      globalEvents = StreamController<SseEvent>.broadcast();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    Future<SessionDetailCubit> createLoadedCubit({
      List<QueuedSessionPrompt> snapshotQueue = const [],
      List<AgentInfo> agents = const [],
      ProviderListResponse? providerData,
      List<CommandInfo> commands = const [],
      SessionPromptDefaults? promptDefaults,
      bool areOptionsStale = false,
      bool supportsPromptAttachments = false,
      bool isArchived = false,
      List<MessageWithParts> snapshotMessages = const [],
      SessionLaunchRepository? sessionLaunchRepository,
      // One that delivers follow-ups through mockSessionRepository; replaces
      // [sessionLaunchRepository].
      SessionLaunchService? sessionLaunchService,
      void Function(SessionDetailState initial)? onInitialState,
      // Holds the first load until completed; the cubit is returned before it.
      Completer<void>? loadGate,
      bool firstLoadFails = false,
      // Blocks the session's harness, with nothing stored for the session.
      bool harnessBlocked = false,
      // The harness's setup and runtime as the bridge reports them over time.
      ValueStream<PluginManagementLoadResult>? managementSnapshots,
    }) async {
      final mockLoadService = MockSessionDetailLoadService();
      when(
        () => mockLoadService.load(
          session: any(named: "session"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async {
        await loadGate?.future;
        if (firstLoadFails) return SessionDetailLoadResult.failed(error: StateError("offline"), stackTrace: null);
        return SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            areOptionsStale: areOptionsStale,
            pluginId: "claude",
            supportsPromptAttachments: supportsPromptAttachments,
            supportsFileUploads: false,
            offersSessionMcp: true,
            messages: snapshotMessages,
            olderMessagesCursor: null,
            userMessagesBefore: null,
            awaitingHarnessSync: false,
            pendingQuestions: const <PendingQuestion>[],
            pendingPermissions: const <PendingPermission>[],
            bridgeQueuedPrompts: snapshotQueue,
            childSessions: const <Session>[],
            statuses: const <String, SessionStatus>{},
            agents: agents,
            providerData: providerData,
            commands: commands,
            canonicalSessionTitle: null,
            promptDefaults: promptDefaults,
            isRootSession: true,
            isArchived: isArchived,
            cannotContinueMessage: null,
            namesCommandInvocations: false,
          ),
        );
      });
      when(
        () => mockLoadService.loadWithoutHarness(
          session: any(named: "session"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async {
        await loadGate?.future;
        return const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            areOptionsStale: false,
            pluginId: "plugin-1",
            supportsPromptAttachments: false,
            supportsFileUploads: false,
            offersSessionMcp: true,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
            userMessagesBefore: null,
            awaitingHarnessSync: true,
            pendingQuestions: <PendingQuestion>[],
            pendingPermissions: <PendingPermission>[],
            bridgeQueuedPrompts: <QueuedSessionPrompt>[],
            childSessions: <Session>[],
            statuses: <String, SessionStatus>{},
            agents: <AgentInfo>[],
            providerData: null,
            commands: <CommandInfo>[],
            canonicalSessionTitle: null,
            promptDefaults: null,
            isRootSession: true,
            isArchived: false,
            cannotContinueMessage: null,
            namesCommandInvocations: false,
          ),
        );
      });
      final pluginManagementService = stubbedPluginManagementService();
      if (harnessBlocked) {
        final blocked = managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        );
        final snapshots = Stream.value(blocked).shareValueSeeded(blocked);
        when(() => pluginManagementService.snapshots).thenAnswer((_) => snapshots);
      }
      if (managementSnapshots != null) {
        when(() => pluginManagementService.snapshots).thenAnswer((_) => managementSnapshots);
      }
      when(
        () => mockLoadService.reload(
          session: any(named: "session"),
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async {
        // The snapshot is read before the gate holds it back, as a slow fetch's
        // queue read predates whatever lands while the rest of it finishes.
        final messages = reloadSnapshotMessages;
        final queue = reloadSnapshotQueue;
        await reloadGate?.future;
        return SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            areOptionsStale: false,
            pluginId: "claude",
            supportsPromptAttachments: supportsPromptAttachments,
            supportsFileUploads: false,
            offersSessionMcp: true,
            messages: messages,
            olderMessagesCursor: null,
            userMessagesBefore: null,
            awaitingHarnessSync: false,
            pendingQuestions: const <PendingQuestion>[],
            pendingPermissions: const <PendingPermission>[],
            bridgeQueuedPrompts: queue,
            childSessions: const <Session>[],
            statuses: const <String, SessionStatus>{},
            agents: const <AgentInfo>[],
            providerData: null,
            commands: const <CommandInfo>[],
            canonicalSessionTitle: null,
            promptDefaults: null,
            isRootSession: true,
            isArchived: false,
            cannotContinueMessage: null,
            namesCommandInvocations: false,
          ),
        );
      });
      when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);

      final cubit = SessionDetailCubit(
        mockConnectionService,
        pluginManagementService: pluginManagementService,
        interactionCalculator: const SessionInteractionCalculator(),
        loadService: mockLoadService,
        sessionAbortService: SessionAbortService(repository: mockSessionRepository),
        autoContinuationService: SessionAutoContinuationService(repository: mockSessionRepository),
        approvalService: SessionApprovalService(repository: mockSessionRepository),
        promptDispatcher: mockSessionRepository,
        permissionRepository: MockPermissionRepository(),
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        feedbackPromptService: feedbackPromptService,
        sessionId: _sessionId,
        projectId: "project-1",
        notificationCanceller: MockNotificationCanceller(),
        failureReporter: MockFailureReporter(),
        bridgeSettingsService: stubbedBridgeSettingsService(),
        sseEventTracker: MockSseEventTracker(),
        fileReferenceOpenService: MockFileReferenceOpenService(),
        window: idleSessionWindow(),
        sessionLaunchService:
            sessionLaunchService ??
            inMemorySessionLaunchService(
              launchRepository: sessionLaunchRepository ?? inMemorySessionLaunchRepository(),
            ),
      );
      addTearDown(cubit.close);
      onInitialState?.call(cubit.state);
      if (loadGate == null) await cubit.stream.firstWhere((state) => state is SessionDetailLoaded);
      return cubit;
    }

    test("loads the bridge queue from the snapshot", () async {
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);

      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, const [_queuedPrompt]);
    });

    test("a stale-reported snapshot refreshes the options in the background without a notice", () async {
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());

      final cubit = await createLoadedCubit(areOptionsStale: true);
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);
      await _awaitCondition(() => (cubit.state as SessionDetailLoaded).availableAgents.isNotEmpty);

      expect(
        (cubit.state as SessionDetailLoaded).availableAgents.map((agent) => agent.name),
        ["Agent", "Plan"],
      );
      expect(notices, isEmpty);
    });

    for (final (description, areOptionsStale, isArchived) in [
      ("a fresh snapshot", false, false),
      ("an archived session's stale snapshot", true, true),
    ]) {
      test("$description refreshes nothing", () async {
        final cubit = await createLoadedCubit(areOptionsStale: areOptionsStale, isArchived: isArchived);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<SessionDetailLoaded>());
        verifyNever(
          () => mockSessionRepository.loadSessionOptions(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            mode: any(named: "mode"),
          ),
        );
      });
    }

    test("an options update re-reads the cache and drops a withdrawn agent", () async {
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      expect((cubit.state as SessionDetailLoaded).selectedAgent, "Default");

      globalEvents.add(
        SseEvent(
          data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-1"),
        ),
      );
      await _awaitCondition(() => (cubit.state as SessionDetailLoaded).selectedAgent != "Default");

      final state = cubit.state as SessionDetailLoaded;
      expect(state.availableAgents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(state.selectedAgent, "Agent");
    });

    test("a refresh that drops the selected agent adopts the replacement's own model", () async {
      // The old agent's model is still in the catalog, so it would survive on
      // its own. It must not, because the agent that preferred it is gone.
      const replacement = AgentInfo(
        name: "Agent",
        description: "Agent",
        model: AgentModel(providerID: "anthropic", modelID: "haiku", variant: null),
        mode: AgentMode.primary,
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer(
        (_) async => SessionOptionsRepositoryAvailable(
          isStale: false,
          catalog: SessionOptionsCatalog(
            agents: const [replacement],
            providers: [
              const ProviderInfo(
                id: "anthropic",
                name: "Anthropic",
                defaultModelID: "opus",
                models: {
                  "opus": ProviderModel(
                    fastMode: null,
                    id: "opus",
                    providerID: "anthropic",
                    name: "Opus",
                    variants: [],
                    defaultVariant: null,
                    family: null,
                    releaseDate: null,
                  ),
                  "haiku": ProviderModel(
                    fastMode: null,
                    id: "haiku",
                    providerID: "anthropic",
                    name: "Haiku",
                    variants: [],
                    defaultVariant: null,
                    family: null,
                    releaseDate: null,
                  ),
                },
              ),
            ],
            providersConnectedOnly: false,
            commands: const [],
            lastUsedPromptDefaults: null,
          ),
        ),
      );
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(
            name: "Departing",
            description: "Departing",
            model: AgentModel(providerID: "anthropic", modelID: "opus", variant: null),
            mode: AgentMode.primary,
          ),
        ],
        promptDefaults: const SessionPromptDefaults(
          agent: "Departing",
          model: AgentModel(providerID: "anthropic", modelID: "opus", variant: null),
        ),
        providerData: const ProviderListResponse(
          connectedOnly: false,
          items: [
            ProviderInfo(
              id: "anthropic",
              name: "Anthropic",
              defaultModelID: "opus",
              models: {
                "opus": ProviderModel(
                  fastMode: null,
                  id: "opus",
                  providerID: "anthropic",
                  name: "Opus",
                  variants: [],
                  defaultVariant: null,
                  family: null,
                  releaseDate: null,
                ),
              },
            ),
          ],
        ),
      );
      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.modelID, "opus");

      globalEvents.add(
        SseEvent(
          data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-1"),
        ),
      );
      await _awaitCondition(() => (cubit.state as SessionDetailLoaded).selectedAgent == "Agent");

      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.modelID, "haiku");
    });

    group("a session's own model the catalog does not list", () {
      const sessionModel = AgentModel(providerID: "anthropic", modelID: "proxy-alias", variant: "high");

      Future<List<SessionDetailLoaded>> openAndRefresh({required ProviderListResponse? cachedProviders}) async {
        final refreshed = Completer<void>();
        when(
          () => mockSessionRepository.loadSessionOptions(
            projectId: "project-1",
            pluginId: "claude",
            mode: SessionOptionsRequestMode.forceRefresh,
          ),
        ).thenAnswer((_) async {
          refreshed.complete();
          return _claudeCatalogDeclaringOpus();
        });
        final loaded = <SessionDetailLoaded>[];
        final cubit = await createLoadedCubit(
          agents: cachedProviders == null ? const [] : _claudeCatalogDeclaringOpusAgents,
          providerData: cachedProviders,
          promptDefaults: const SessionPromptDefaults(agent: null, model: sessionModel),
          areOptionsStale: true,
        );
        loaded.add(_loadedState(cubit));
        final subscription = cubit.stream.listen((state) {
          if (state is SessionDetailLoaded) loaded.add(state);
        });
        addTearDown(subscription.cancel);
        await refreshed.future;
        await _awaitCondition(() => _loadedState(cubit).availableAgents.isNotEmpty);
        await Future<void>.delayed(Duration.zero);
        return loaded;
      }

      void expectKeptThroughout(List<SessionDetailLoaded> loaded) {
        expect(loaded, isNotEmpty);
        for (final state in loaded) {
          expect(state.selectedAgentModel, sessionModel);
          // The variant the session recorded, and nothing the catalog guesses.
          expect(state.availableVariants.map((variant) => variant.id), ["high"]);
        }
      }

      test("stays selected from the open through an options refresh", () async {
        expectKeptThroughout(await openAndRefresh(cachedProviders: _claudeProvidersWithOpus));
      });

      test("stays selected when the open had no cached catalog", () async {
        expectKeptThroughout(await openAndRefresh(cachedProviders: null));
      });

      test("is replaced once the user picks another model, and a pick the catalog drops is corrected", () async {
        when(
          () => mockSessionRepository.loadSessionOptions(
            projectId: "project-1",
            pluginId: "claude",
            mode: SessionOptionsRequestMode.cacheOnly,
          ),
        ).thenAnswer((_) async => _claudeCatalogDeclaringOpus());
        final cubit = await createLoadedCubit(
          agents: _claudeCatalogDeclaringOpusAgents,
          providerData: const ProviderListResponse(
            connectedOnly: false,
            items: [
              ProviderInfo(
                id: "anthropic",
                name: "Anthropic",
                defaultModelID: "opus",
                models: {"opus": _opusModel, "sonnet": _sonnetModel},
              ),
            ],
          ),
          promptDefaults: const SessionPromptDefaults(agent: null, model: sessionModel),
        );
        expect(_loadedState(cubit).selectedAgentModel, sessionModel);

        cubit.selectModel(providerID: "anthropic", modelID: "sonnet");
        expect(_loadedState(cubit).selectedAgentModel?.modelID, "sonnet");

        // The refreshed catalog no longer offers the user's pick, which is not
        // the session's own model, so the refresh corrects it.
        globalEvents.add(
          SseEvent(
            data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-1"),
          ),
        );
        await _awaitCondition(() => _loadedState(cubit).selectedAgentModel?.modelID != "sonnet");

        expect(_loadedState(cubit).selectedAgentModel?.modelID, "opus");
      });
    });

    test("an options update for another project is ignored", () async {
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
      );

      globalEvents.add(
        SseEvent(
          data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-2"),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => mockSessionRepository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: any(named: "mode"),
        ),
      );
      expect((cubit.state as SessionDetailLoaded).availableAgents.map((agent) => agent.name), ["Default"]);
    });

    test("refreshes stale options and retries the queued submission with a supported agent", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      var sendCount = 0;
      final promptIds = <String>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) async {
        sendCount++;
        promptIds.add(invocation.namedArguments[#promptId] as String);
        return sendCount == 1 ? ApiResponse.error(staleError) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      expect(promptIds.toSet(), hasLength(1));
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: "Default",
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).called(1);
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: "Agent",
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.selectedAgent, "Agent");
      expect(state.queuedMessages, isEmpty);
      expect(_sendingOf(state: state), isNull);
      expect(state.awaitingBridgeSubmissions.map((item) => item.submission.promptId), [promptIds.first]);
      expect(notices, [const SessionDetailPromptOptionsUpdated()]);
    });

    test("marks a removed command unavailable and waits for explicit removal", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "command unavailable",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      final sentCommands = <String?>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: const [],
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) async {
        final command = invocation.namedArguments[#command] as String?;
        sentCommands.add(command);
        return command == null ? ApiResponse.success(null) : ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(commands: const [_reviewCommand]);
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "src",
        command: testCommandInfo(name: "review"),
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );

      await Future<void>.delayed(Duration.zero);
      var state = cubit.state as SessionDetailLoaded;
      expect(state.availableCommands, isEmpty);
      expect(state.queuedMessages.single, isA<UnavailableQueuedCommandSubmission>());
      expect(state.queuedMessages.single.displayText, "/review src");
      expect(_sendingOf(state: state), isNull);
      expect(sentCommands, ["review"]);
      expect(notices, [const SessionDetailCommandUnavailable()]);

      await cubit.sendMessage(
        text: "continue",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect(sentCommands, ["review"], reason: "later prompts must not overtake the rejected command");

      cubit.cancelQueuedMessage(0);
      await awaitState(
        cubit: cubit,
        predicate: (candidate) =>
            candidate is SessionDetailLoaded &&
            candidate.awaitingBridgeSubmissions.length == 1 &&
            candidate.awaitingBridgeSubmissions.single.submission.text == "continue",
        description: "the next prompt to be accepted after removing the unavailable command",
      );

      state = cubit.state as SessionDetailLoaded;
      expect(sentCommands, ["review", null]);
      expect(state.queuedMessages, isEmpty);
      expect(state.awaitingBridgeSubmissions.single.submission.displayText, "continue");
    });

    test("marks a removed command unavailable when a cache update overtakes recovery", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "command unavailable",
          ).toJson(),
        ),
      );
      final forcedGate = Completer<SessionOptionsRepositoryResult>();
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) => forcedGate.future);
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      final sentCommands = <String?>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: const [],
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) async {
        final command = invocation.namedArguments[#command] as String?;
        sentCommands.add(command);
        return command == null ? ApiResponse.success(null) : ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(commands: const [_reviewCommand]);
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      final sending = cubit.sendMessage(
        text: "src",
        command: testCommandInfo(name: "review"),
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await _awaitCondition(() => sentCommands.isNotEmpty);
      globalEvents.add(
        SseEvent(
          data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-1"),
        ),
      );
      await _awaitCondition(() => (cubit.state as SessionDetailLoaded).availableCommands.isEmpty);
      forcedGate.complete(_freshClaudeOptions());
      await sending;
      await Future<void>.delayed(Duration.zero);
      var state = cubit.state as SessionDetailLoaded;
      expect(state.availableCommands, isEmpty);
      expect(state.queuedMessages.single, isA<UnavailableQueuedCommandSubmission>());
      expect(state.queuedMessages.single.displayText, "/review src");
      expect(_sendingOf(state: state), isNull);
      expect(sentCommands, ["review"]);
      expect(notices, [const SessionDetailCommandUnavailable()]);

      await cubit.sendMessage(
        text: "continue",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect(sentCommands, ["review"], reason: "later prompts must not overtake the rejected command");

      cubit.cancelQueuedMessage(0);
      await awaitState(
        cubit: cubit,
        predicate: (candidate) =>
            candidate is SessionDetailLoaded &&
            candidate.awaitingBridgeSubmissions.length == 1 &&
            candidate.awaitingBridgeSubmissions.single.submission.text == "continue",
        description: "the next prompt to be accepted after removing the unavailable command",
      );

      state = cubit.state as SessionDetailLoaded;
      expect(sentCommands, ["review", null]);
      expect(state.queuedMessages, isEmpty);
      expect(state.awaitingBridgeSubmissions.single.submission.displayText, "continue");
    });

    test("an options update landing mid-recovery still retries the queued submission", () async {
      // The forced refresh's own commit announces itself, so the cache-only
      // reload it triggers can apply before the refresh's response returns.
      // Recovery must still count as succeeded — the catalog on screen is the
      // one it was waiting for.
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      final forcedGate = Completer<SessionOptionsRepositoryResult>();
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) => forcedGate.future);
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      var sendCount = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async {
        sendCount++;
        return sendCount == 1 ? ApiResponse.error(staleError) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      unawaited(
        cubit.sendMessage(
          text: "hello",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        ),
      );
      await _awaitCondition(() => sendCount == 1);
      // The commit behind the still-pending forced refresh reaches this client.
      globalEvents.add(
        SseEvent(
          data: const SesoriSessionOptionsUpdated(pluginId: "claude", projectId: "project-1"),
        ),
      );
      await _awaitCondition(() => (cubit.state as SessionDetailLoaded).selectedAgent == "Agent");
      forcedGate.complete(_freshClaudeOptions());
      await _awaitCondition(() => sendCount == 2);

      expect(sendCount, 2);
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: "Agent",
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).called(1);
      // The user was told their rejected selection was corrected, even though
      // the reload that delivered it was not the one recovery started.
      expect(notices, [const SessionDetailPromptOptionsUpdated()]);
    });

    test("parks the prompt after one stale-options recovery attempt", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      var sendCount = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async {
        sendCount++;
        return ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      verify(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages.single.agent, "Agent");
      expect(_sendingOf(state: state), isNull);
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(
        notices,
        [const SessionDetailPromptOptionsUpdated(), const SessionDetailPromptOptionsRecoveryFailed()],
      );
      // Only the final give-up counts as a failed send for the rating prompt.
      expect(feedbackPromptService.failedSessions, [_sessionId]);
    });

    test("does not restart stale-options recovery after forced refresh fails", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());
      var sendCount = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async {
        sendCount++;
        return ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );

      await cubit.sendMessage(
        text: "first",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await cubit.sendMessage(
        text: "second",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      verify(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages.map((submission) => submission.text), ["first", "second"]);
      expect(_sendingOf(state: state), isNull);
      expect(state.awaitingBridgeSubmissions, isEmpty);
    });

    test("surfaces authentication guidance when stale-option recovery needs provider login", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer(
        (_) async => const SessionOptionsRepositoryAuthenticationRequired(
          actionHint: "Authenticate locally.",
        ),
      );
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          fastMode: false,
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(staleError));
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        notices,
        [
          isA<SessionDetailAuthenticationRequired>().having(
            (notice) => notice.actionHint,
            "action hint",
            "Authenticate locally.",
          ),
        ],
      );
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages.single.text, "hello");
      expect(state.awaitingBridgeSubmissions, isEmpty);
    });

    test("retries a withdrawn variant at a supported one rather than unsetting it", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude effort",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _claudeOptionsWithVariants(const ["low"]));
      var sendCount = 0;
      final sentVariants = <SessionVariant?>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: null,
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) async {
        sendCount++;
        sentVariants.add(invocation.namedArguments[#variant] as SessionVariant?);
        return sendCount == 1 ? ApiResponse.error(staleError) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
        ],
        providerData: _providerDataWithVariants(const ["low", "high"]),
        promptDefaults: const SessionPromptDefaults(
          agent: "Agent",
          model: AgentModel(providerID: "anthropic", modelID: "claude-opus", variant: "high"),
        ),
      );
      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.variant, "high");

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(sendCount, 2);
      // The composer renders the first available variant when none is
      // selected, so recovery must land on a real one instead of unsetting it.
      expect(sentVariants, const [SessionVariant(id: "high"), SessionVariant(id: "low")]);
      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.variant, "low");
    });

    test("replaces the queue from the SSE event and drops the accepted local copy", () async {
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();

      // Stage a send whose acceptance response is still in flight.
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final sending = _sendingOf(state: cubit.state as SessionDetailLoaded);
      final promptId = sending?.promptId;
      expect(promptId, isNotNull);

      // The bridge's queue event races ahead of the acceptance response: the
      // local copy hands over in the same emission.
      final acceptedPrompt = QueuedSessionPrompt(
        commandSource: null,
        id: promptId ?? "",
        text: "steer it",
        command: null,
        attachmentCount: 0,
        createdAt: 100,
      );
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: [acceptedPrompt]) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts.single.id, promptId);
      expect(_sendingOf(state: state), isNull, reason: "the bridge owns the prompt now");
      expect(state.queuedMessages, isEmpty);
      sendCompleter.complete(ApiResponse.success(null));
    });

    test("the bridge owning a failed send releases the sends waiting behind it", () async {
      final sentTexts = <String>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) async {
        sentTexts.add(invocation.namedArguments[#text] as String);
        return sentTexts.length == 1 ? ApiResponse.error(ApiError.generic()) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit();

      await cubit.sendMessage(text: "lost", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await cubit.sendMessage(
        text: "waiting",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      final failed = _failedOf(state: cubit.state as SessionDetailLoaded);
      expect(failed?.displayText, "lost");
      expect(sentTexts, ["lost"]);

      // The response was lost after the bridge accepted the prompt.
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(
              commandSource: null,
              id: failed?.promptId ?? "",
              text: "lost",
              command: null,
              attachmentCount: 0,
              createdAt: 100,
            ),
          ],
        ) as SesoriSessionEvent,
      );
      for (var attempt = 0; attempt < 20 && sentTexts.length < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(_failedOf(state: cubit.state as SessionDetailLoaded), isNull);
      expect(sentTexts, ["lost", "waiting"]);
    });

    test("keeps the queued entry through the bare envelope and releases it on the first part", () async {
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);

      final emissions = <SessionDetailState>[];
      final subscription = cubit.stream.listen(emissions.add);
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 200, completed: null),
            promptId: "prm_1",
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // The envelope alone cannot render; dropping the entry now would blank
      // the row until its text part lands.
      var state = cubit.state as SessionDetailLoaded;
      expect(state.messages.single.info.id, "echo-1");
      expect(state.bridgeQueuedPrompts, const [_queuedPrompt]);

      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts, isEmpty);
      // The no-blank invariant: every emission renders the prompt somewhere —
      // a renderable message, the bridge entry, or a staged copy.
      for (final emitted in emissions.whereType<SessionDetailLoaded>()) {
        final renderableMessage = emitted.messages.any(
          (message) => message.info.id == "echo-1" && message.parts.any((part) => part is MessagePartText),
        );
        final queued = emitted.bridgeQueuedPrompts.any((prompt) => prompt.id == "prm_1");
        expect(
          renderableMessage || queued,
          isTrue,
          reason: "no frame may leave the prompt without a renderable source",
        );
      }
      await subscription.cancel();
    });

    for (final acceptedFirst in [false, true]) {
      test(
        "queue handoff retains images ${acceptedFirst ? 'after' : 'before'} acceptance without a UI frame",
        () async {
          final send = Completer<ApiResponse<void>>();
          when(
            () => mockSessionRepository.sendMessage(
              sessionId: _sessionId,
              promptId: any(named: "promptId"),
              text: any(named: "text"),
              attachments: any(named: "attachments"),
              agent: any(named: "agent"),
              model: any(named: "model"),
              variant: any(named: "variant"),
              fastMode: any(named: "fastMode"),
              command: any(named: "command"),
              commandSource: any(named: "commandSource"),
            ),
          ).thenAnswer((_) => send.future);
          final cubit = await createLoadedCubit(supportsPromptAttachments: true);
          final attachment = ComposerImageAttachment(
            mime: "image/png",
            bytes: base64Decode(
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
            ),
            filename: "Fixture.png",
          );
          final sending = cubit.sendMessage(
            text: "Review image",
            command: null,
            inputMode: ComposerInputMode.typed,
            attachments: [attachment],
          );
          final promptId = _requireSendingOf(state: cubit.state as SessionDetailLoaded).promptId;
          if (acceptedFirst) {
            send.complete(ApiResponse.success(null));
            await sending;
          }
          final handedOff = cubit.stream.firstWhere(
            (state) => state is SessionDetailLoaded && state.bridgeQueuedPrompts.isNotEmpty,
          );
          sessionEvents.add(
            SesoriSseEvent.sessionQueuedPrompts(
              sessionID: _sessionId,
              prompts: [
                QueuedSessionPrompt(
                  commandSource: null,
                  id: promptId,
                  text: "Review image",
                  command: null,
                  attachmentCount: 1,
                  createdAt: 1,
                  dispatchState: QueuedPromptDispatchState.dispatched,
                ),
              ],
            ) as SesoriSessionEvent,
          );
          await handedOff;
          if (!acceptedFirst) {
            send.complete(ApiResponse.success(null));
            await sending;
          }
          final state = cubit.state as SessionDetailLoaded;
          expect(_sendingOf(state: state), isNull);
          expect(state.queuedMessages, isEmpty);
          expect(state.awaitingBridgeSubmissions, isEmpty);
          expect(state.bridgePromptAttachments[promptId]?.single, same(attachment));

          final settled = cubit.stream.firstWhere(
            (state) => state is SessionDetailLoaded && state.bridgeQueuedPrompts.isEmpty,
          );
          sessionEvents.add(
            SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: promptId) as SesoriSessionEvent,
          );
          await settled;
          expect((cubit.state as SessionDetailLoaded).bridgePromptAttachments, isEmpty);
        },
      );
    }

    test("an accepted send stays visible until the bridge queue lists it", () async {
      final send = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      final emissions = <SessionDetailState>[];
      final subscription = cubit.stream.listen(emissions.add);
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId;
      expect(promptId, isNotNull);

      // The acceptance response lands before the session.queued-prompts
      // event: the submission parks instead of vanishing.
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);
      var state = cubit.state as SessionDetailLoaded;
      expect(_sendingOf(state: state), isNull);
      expect(state.awaitingBridgeSubmissions.map((item) => item.submission.promptId), [promptId]);

      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(
              commandSource: null,
              id: promptId ?? "",
              text: "steer it",
              command: null,
              attachmentCount: 0,
              createdAt: 1,
            ),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      state = cubit.state as SessionDetailLoaded;
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(state.bridgeQueuedPrompts.map((prompt) => prompt.id), [promptId]);

      // The no-blank invariant: every emission after the send renders the
      // prompt from at least one surface.
      for (final emitted in emissions.whereType<SessionDetailLoaded>()) {
        final visible =
            _sendingOf(state: emitted)?.promptId == promptId ||
            emitted.queuedMessages.any((item) => item.promptId == promptId) ||
            emitted.awaitingBridgeSubmissions.any((item) => item.submission.promptId == promptId) ||
            emitted.bridgeQueuedPrompts.any((prompt) => prompt.id == promptId);
        expect(visible, isTrue, reason: "no frame may leave the accepted send without a surface");
      }
      await subscription.cancel();
    });

    test("a prompt-settled event removes an accepted command with no transcript output", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(
        text: "/fast",
        command: testCommandInfo(name: "fast"),
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      final promptId = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single.submission.promptId;

      sessionEvents.add(
        SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: promptId) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(_sendingOf(state: state), isNull);
      expect(state.queuedMessages, isEmpty);
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(state.bridgeQueuedPrompts, isEmpty);
    });

    test("prompt settlement racing the response resumes the staged FIFO", () async {
      final sends = <Completer<ApiResponse<void>>>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) {
        final send = Completer<ApiResponse<void>>();
        sends.add(send);
        return send.future;
      });
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(
          text: "/fast",
          command: testCommandInfo(name: "fast"),
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        ),
      );
      await _awaitCondition(() => sends.length == 1);
      final firstPromptId = _requireSendingOf(state: cubit.state as SessionDetailLoaded).promptId;
      unawaited(
        cubit.sendMessage(
          text: "next",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).queuedMessages.single.text, "next");

      sessionEvents.add(
        SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: firstPromptId) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      var state = cubit.state as SessionDetailLoaded;
      expect(_sendingOf(state: state), isNull, reason: "settled in-flight prompt is hidden immediately");
      expect(state.queuedMessages.single.text, "next");

      final refreshStates = <SessionDetailLoaded>[];
      final refreshSubscription = cubit.stream.whereType<SessionDetailLoaded>().listen(refreshStates.add);
      sessionEvents.add(
        const SesoriCommandExecuted(
          name: "refresh",
          sessionID: _sessionId,
          arguments: "",
          messageID: "refresh-message",
        ),
      );
      await _awaitCondition(
        () => refreshStates.any((candidate) => candidate.isRefreshing) && !refreshStates.last.isRefreshing,
      );
      for (final refreshState in refreshStates) {
        expect(
          [
            ...refreshState.queuedMessages.map((item) => item.promptId),
            ...refreshState.awaitingBridgeSubmissions.map((item) => item.submission.promptId),
            _sendingOf(state: refreshState)?.promptId,
          ],
          isNot(contains(firstPromptId)),
          reason: "refresh emissions must retain the bridge-aware settlement projection",
        );
      }
      await refreshSubscription.cancel();

      sends.first.complete(ApiResponse.success(null));
      await _awaitCondition(() => sends.length == 2);
      state = cubit.state as SessionDetailLoaded;
      final secondPromptId = _requireSendingOf(state: state).promptId;
      expect(_requireSendingOf(state: state).text, "next");

      sends.last.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);
      sessionEvents.add(
        SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: secondPromptId) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
    });

    test("a send whose entry was consumed before its response settles on its echo", () async {
      final send = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = _requireSendingOf(state: cubit.state as SessionDetailLoaded).promptId;

      // An immediately dispatched steering send: the bridge consumed the entry
      // and published the resulting queue before the acceptance response
      // travelled back, so the only statement this client sees omits the
      // prompt entirely.
      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);
      // The dispatched prompt's own message is what accounts for the row.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 300, completed: null),
            promptId: promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(
        state.awaitingBridgeSubmissions,
        isEmpty,
        reason: "the delivered echo replaced the parked copy; leaving it strands a bubble",
      );
      expect(_sendingOf(state: state), isNull);
      expect(state.queuedMessages, isEmpty);
    });

    test("a bridge-stamped harness echo settles the parked send", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(
        text: "steer it",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await Future<void>.delayed(Duration.zero);
      final parked = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single;

      // Codex and OpenCode author no prompt id of their own; the bridge stamps
      // its dispatch onto their echo so the client can still correlate it.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: parked.submission.promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions,
        isEmpty,
        reason: "the stamped echo replaced the copy it belongs to",
      );
    });

    test("a multi-part echo settles exactly one parked send", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "first", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await cubit.sendMessage(text: "second", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      final parked = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions;
      expect(parked, hasLength(2));

      // One echo, several updates: the envelope and each of its parts. Only
      // the first may settle a send.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: parked.first.submission.promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first"));
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first (edited)"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.submission.text),
        ["second"],
        reason: "later updates of one echo must not retire further sends",
      );
    });

    test("another surface's echo leaves this client's parked send alone", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();

      await cubit.sendMessage(text: "mine", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      // Another surface's prompt lands while this client's own copy is parked.
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "other-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 100, completed: null),
            promptId: null,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "other-1", text: "from another device"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.submission.text),
        ["mine"],
        reason: "a foreign echo carries different text and must not retire this copy",
      );
    });

    test("an echo that outruns its acceptance response prevents parking", () async {
      final send = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final inFlight = _requireSendingOf(state: cubit.state as SessionDetailLoaded).promptId;

      // A queue-less harness echoes at acceptance, so the stamped message can
      // land before the acceptance response completes.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: inFlight,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.awaitingBridgeSubmissions, isEmpty, reason: "the echo already renders this prompt");
      expect(_sendingOf(state: state), isNull);
      expect(state.messages.single.info.id, "echo-1");
    });

    test("an authoritative refresh settles a parked prompt the bridge no longer owns", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "lost", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      // A refresh whose fetch began after the park returns neither the queue
      // entry nor the message: the prompt is gone bridge-side, so the parked
      // ghost settles instead of rendering forever.
      await cubit.reload();

      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
    });

    test("a refresh fetched before a send cannot blank the prompt the bridge queued meanwhile", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();

      // The refresh that follows a return to the app is already reading when
      // the prompt is sent, so its snapshot predates the queue entry.
      final gate = reloadGate = Completer<void>();
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(Duration.zero);

      await cubit.sendMessage(text: "hello", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single.submission.promptId;
      final queued = QueuedSessionPrompt(
        commandSource: null,
        id: promptId,
        text: "hello",
        command: null,
        attachmentCount: 0,
        createdAt: 1,
      );
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: [queued]) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      // The row has no other source: the queue event released the local copy.
      final state = cubit.state as SessionDetailLoaded;
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(state.bridgeQueuedPrompts, [queued]);
    });

    test("a refresh fetched before a prompt left the queue cannot bring it back", () async {
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);

      reloadSnapshotQueue = const [_queuedPrompt];
      final gate = reloadGate = Completer<void>();
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(Duration.zero);

      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);
    });

    test("a refresh with no queue event during its fetch applies the fetched queue", () async {
      final cubit = await createLoadedCubit();
      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      reloadSnapshotQueue = const [_queuedPrompt];
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, [_queuedPrompt]);
    });

    test("a snapshot holding only the bare envelope keeps the parked bubble", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "steer", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single.submission.promptId;

      // The refresh carries the delivered message as a bare envelope: it
      // cannot render, so the parked copy must survive rather than be settled
      // as absent — otherwise the row blanks until the first part lands.
      reloadSnapshotMessages = [
        MessageWithParts(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 500, completed: null),
            promptId: promptId,
          ),
          parts: const <MessagePart>[],
        ),
      ];
      await cubit.reload();

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.submission.promptId),
        [promptId],
      );
    });

    test("abort clears a parked-only submission", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      when(
        () => mockSessionRepository.abortSession(
          sessionId: _sessionId,
          subAgents: any(named: "subAgents"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "parked", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
      expect(cubit.composerDraft, ComposerDraft.typed(text: "parked"));
      expect(feedbackPromptService.stoppedSessions, [_sessionId]);
      expect(feedbackPromptService.refusedStops, isEmpty);
    });

    test("a refused confirm stop returns the rejection and leaves queued work untouched", () async {
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      const rejection = SessionAbortRejection(runningSubAgentCount: 2, mainAgentRunning: true);
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.confirm),
      ).thenThrow(SessionAbortRejectedException(rejection: rejection, innerError: StateError("409")));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "parked", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);

      final outcome = await cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm);

      expect(outcome, isA<SessionAbortRejected>().having((o) => o.rejection, "rejection", rejection));
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));
      expect(feedbackPromptService.refusedStops, [_sessionId], reason: "the running turn can still earn a point");
    });

    test("not-performed refusal with unknown reason gates dispatch, preserves queue, then resumes drain", () async {
      final abortCompleter = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionRepository.abortSession(
          sessionId: _sessionId,
          subAgents: SessionAbortSubAgentPolicy.confirm,
        ),
      ).thenAnswer((_) => abortCompleter.future);
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm);
      await Future<void>.delayed(Duration.zero);
      await cubit.sendMessage(
        text: "queued during abort",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect((cubit.state as SessionDetailLoaded).queuedMessages, hasLength(1));

      const refusal = SessionAbortNotPerformedRefusal(
        reason: SessionAbortRefusalReason.unknownEnumValue,
      );
      abortCompleter.completeError(
        SessionAbortNotAcceptedException(refusal: refusal, innerError: StateError("409")),
      );
      expect(await aborting, isA<SessionAbortNotAccepted>());
      expect(feedbackPromptService.refusedStops, [_sessionId], reason: "the running turn can still earn a point");
      await _awaitCondition(
        () => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty,
      );
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("an accepted stop returns the bridge queue to the composer, in order, before the draft", () async {
      const dictated = QueuedSessionPrompt(
        commandSource: null,
        id: "prm_2",
        dispatchState: QueuedPromptDispatchState.queued,
        text: '🎙️ "spoken words"',
        command: null,
        createdAt: 101,
      );
      const dispatched = QueuedSessionPrompt(
        commandSource: null,
        id: "prm_steering",
        dispatchState: QueuedPromptDispatchState.dispatched,
        text: "steered, never echoed",
        command: null,
        createdAt: 102,
      );
      const command = QueuedSessionPrompt(
        commandSource: null,
        id: "prm_3",
        dispatchState: QueuedPromptDispatchState.queued,
        text: "the diff",
        command: "review",
        createdAt: 103,
      );
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
      ).thenAnswer((_) async => ApiResponse.success(true));
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt, dictated, dispatched, command]);
      cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

      expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop), isA<SessionAbortAccepted>());

      expect(
        cubit.composerDraft,
        ComposerDraft(
          text: "steer it\n\nspoken words\n\nsteered, never echoed\n\n/review the diff\n\nhalf typed",
          voiceSpans: [VoiceOriginSpan(start: 10, end: 22)],
        ),
      );
      final state = cubit.state as SessionDetailLoaded;
      expect(state.composerRestorations, 1);
      // The stop dropped what it returned, so the rows leave as the draft fills.
      expect(state.bridgeQueuedPrompts, isEmpty);
    });

    test("a stop returns a message staged while it runs, with its images and the composer's", () async {
      final abortCompleter = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
      ).thenAnswer((_) => abortCompleter.future);
      final staged = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([1]), filename: null);
      final held = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([2]), filename: null);
      final cubit = await createLoadedCubit(supportsPromptAttachments: true, commands: const [_reviewCommand]);
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      await Future<void>.delayed(Duration.zero);
      await cubit.sendMessage(text: "look", command: null, inputMode: ComposerInputMode.typed, attachments: [staged]);
      cubit
        ..stageCommand(_reviewCommand)
        ..saveComposerDraft(
          draft: ComposerDraft(text: " spoken", voiceSpans: [VoiceOriginSpan(start: 1, end: 7)]),
        )
        ..trackComposerAttachments(attachments: [held]);

      abortCompleter.complete(ApiResponse.success(true));
      expect(await aborting, isA<SessionAbortAccepted>());

      // The staged command becomes text, or the returned words would be its
      // arguments, and its dictated arguments stay dictated.
      expect(
        cubit.composerDraft,
        ComposerDraft(text: "look\n\n/review spoken", voiceSpans: [VoiceOriginSpan(start: 14, end: 20)]),
      );
      // The composer's own images go first: the restore stops at the first
      // image over the budget, and those already fit before the stop.
      expect(cubit.restoredAttachments, [held, staged]);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.stagedCommand, isNull);
      expect(state.queuedMessages, isEmpty);
      expect(state.composerRestorations, 1);
      cubit.acknowledgeRestoredAttachments();
      expect(cubit.restoredAttachments, isEmpty);
    });

    test("a stop does not return a queued prompt the transcript shows delivered", () async {
      final abortCompleter = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
      ).thenAnswer((_) => abortCompleter.future);
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 200, completed: null),
            promptId: "prm_1",
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      abortCompleter.complete(ApiResponse.success(true));
      await aborting;

      expect(cubit.composerDraft, ComposerDraft.typed(text: ""));
      expect((cubit.state as SessionDetailLoaded).composerRestorations, 0);
    });

    test("a stop returns a queued prompt whose echo has no words yet", () async {
      final abortCompleter = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
      ).thenAnswer((_) => abortCompleter.future);
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 200, completed: null),
            promptId: "prm_1",
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      abortCompleter.complete(ApiResponse.success(true));
      await aborting;

      // A bare envelope does not show the prompt, so nothing says it arrived.
      expect(cubit.composerDraft, ComposerDraft.typed(text: "steer it"));
      expect((cubit.state as SessionDetailLoaded).composerRestorations, 1);
    });

    test("a refused stop leaves the queue queued and the composer as it was", () async {
      const rejection = SessionAbortRejection(runningSubAgentCount: 1, mainAgentRunning: true);
      when(
        () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.confirm),
      ).thenThrow(SessionAbortRejectedException(rejection: rejection, innerError: StateError("409")));
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

      expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm), isA<SessionAbortRejected>());

      expect(cubit.composerDraft, ComposerDraft.typed(text: "half typed"));
      final state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts, const [_queuedPrompt]);
      expect(state.composerRestorations, 0);
    });

    test("ambiguous abort failure clears work queued during request into the composer", () async {
      final abortCompleter = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionRepository.abortSession(
          sessionId: _sessionId,
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer((_) => abortCompleter.future);
      final cubit = await createLoadedCubit();
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      await Future<void>.delayed(Duration.zero);
      await cubit.sendMessage(
        text: "ambiguous",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect((cubit.state as SessionDetailLoaded).queuedMessages, hasLength(1));

      abortCompleter.completeError(StateError("502 after cancellation"));
      expect(await aborting, isA<SessionAbortFailed>());
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
      expect(cubit.composerDraft, ComposerDraft.typed(text: "ambiguous"));
    });

    test("confirmed cancellation removes the entry without a failure notice", () async {
      when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"))
          .thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      final notices = <SessionDetailNotice>[];
      final subscription = cubit.noticeStream.listen(notices.add);
      addTearDown(subscription.cancel);
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);
      expect(notices, isEmpty);
      verifyNever(() => mockSessionRepository.getQueuedPrompts(sessionId: _sessionId));
    });

    test("repeated cancellation taps share one request without a false warning", () async {
      final response = Completer<ApiResponse<void>>();
      var requests = 0;
      when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1")).thenAnswer((_) {
        requests++;
        return requests == 1
            ? response.future
            : Future.value(ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));
      });
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      final notices = <SessionDetailNotice>[];
      final subscription = cubit.noticeStream.listen(notices.add);
      addTearDown(subscription.cancel);
      final first = cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      response.complete(ApiResponse.success(null));
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      expect(notices, isEmpty);
      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);
    });

    for (final removed in [false, true]) {
      test("refused cancellation follows a later ${removed ? 'removal' : 'dispatch'} queue event", () async {
        when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"))
            .thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));
        final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
        await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
        expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, const [_queuedPrompt]);
        final latestPrompts = [
          if (!removed) _queuedPrompt.copyWith(dispatchState: QueuedPromptDispatchState.dispatched),
        ];
        sessionEvents.add(
          SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: latestPrompts) as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);
        expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, latestPrompts);
        verifyNever(() => mockSessionRepository.getQueuedPrompts(sessionId: _sessionId));
      });
    }

    test("cancellation can be retried after a thrown repository failure", () async {
      final error = StateError("repository failure");
      when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1")).thenThrow(error);
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      await expectLater(cubit.cancelBridgeQueuedPrompt(promptId: "prm_1"), throwsA(same(error)));
      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, const [_queuedPrompt]);
      when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"))
          .thenAnswer((_) async => ApiResponse.success(null));
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);
      verify(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1")).called(2);
    });

    test("failed cancellation preserves the row, reports failure, and allows retry", () async {
      for (final error in [
        ApiError.dartHttpClient(Exception("offline")),
        ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null),
        ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null),
      ]) {
        when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"))
            .thenAnswer((_) async => ApiResponse.error(error));
        final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
        final notices = <SessionDetailNotice>[];
        final subscription = cubit.noticeStream.listen(notices.add);
        addTearDown(subscription.cancel);
        await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
        await Future<void>.delayed(Duration.zero);
        expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, const [_queuedPrompt]);
        expect(notices.single, isA<SessionDetailQueueCancellationFailed>());
        verifyNever(() => mockSessionRepository.getQueuedPrompts(sessionId: _sessionId));
        when(() => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"))
            .thenAnswer((_) async => ApiResponse.success(null));
        await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
        expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);
      }
    });

    test("a snapshot listing an accepted prompt drops its staged local copy", () async {
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId;
      expect(promptId, isNotNull);

      // A refresh whose snapshot already lists the prompt (the acceptance
      // response was lost) must not leave a duplicate staged copy behind.
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(
              commandSource: null,
              id: promptId ?? "",
              text: "steer it",
              command: null,
              attachmentCount: 0,
              createdAt: 1,
            ),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(_sendingOf(state: state), isNull);
      expect(state.queuedMessages, isEmpty);
      expect(state.bridgeQueuedPrompts.single.id, promptId);
      sendCompleter.complete(ApiResponse.success(null));
    });

    test("healing a lost-response prompt re-drains the sends staged behind it", () async {
      final firstSend = Completer<ApiResponse<void>>();
      final laterSends = <String>[];
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) {
        sendCalls++;
        if (sendCalls == 1) return firstSend.future;
        laterSends.add(invocation.namedArguments[#text] as String);
        return Future.value(ApiResponse.success(null));
      });
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "first", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      unawaited(
        cubit.sendMessage(text: "second", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final firstPromptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId;
      expect(firstPromptId, isNotNull);

      // The first send's response was lost, but its message lands via SSE:
      // the second staged send must dispatch without an external trigger.
      firstSend.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-first",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 300, completed: null),
            promptId: firstPromptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-first", text: "first"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(laterSends, ["second"]);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("a cancelled prompt does not resurrect from its late transport failure", () async {
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      when(
        () => mockSessionRepository.cancelQueuedPrompt(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId;
      expect(promptId, isNotNull);

      // Accepted by the bridge while the response is still in flight...
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(
              commandSource: null,
              id: promptId ?? "",
              text: "steer it",
              command: null,
              attachmentCount: 0,
              createdAt: 1,
            ),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      // ...then cancelled from this client...
      await cubit.cancelBridgeQueuedPrompt(promptId: promptId ?? "");
      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      // ...and only then does the original send fail at the transport layer.
      sendCompleter.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts, isEmpty);
      expect(state.queuedMessages, isEmpty, reason: "the cancelled prompt must not requeue locally");
      expect(_sendingOf(state: state), isNull);
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).called(1);
    });

    test("a snapshot already holding the prompt's message discards the in-flight send and drains on", () async {
      final firstSend = Completer<ApiResponse<void>>();
      final laterSends = <String>[];
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((invocation) {
        sendCalls++;
        if (sendCalls == 1) return firstSend.future;
        laterSends.add(invocation.namedArguments[#text] as String);
        return Future.value(ApiResponse.success(null));
      });
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "first", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      unawaited(
        cubit.sendMessage(text: "second", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId;
      expect(promptId, isNotNull);

      // The prompt already dispatched: its message arrives (queue no longer
      // lists it), then the acceptance response is lost.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            invocation: null,
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 400, completed: null),
            promptId: promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first"));
      await Future<void>.delayed(Duration.zero);
      expect(_sendingOf(state: cubit.state as SessionDetailLoaded), isNull);
      firstSend.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(laterSends, ["second"], reason: "the staged send behind the settled one must dispatch");
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages, isEmpty);
      expect(_sendingOf(state: state), isNull);
    });

    test("abort drops locally staged sends", () async {
      when(
        () => mockSessionRepository.abortSession(
          sessionId: _sessionId,
          subAgents: any(named: "subAgents"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          commandSource: any(named: "commandSource"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "one", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      unawaited(
        cubit.sendMessage(text: "two", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isNotEmpty);

      await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages, isEmpty);
      // The bridge may yet accept the one in flight, so it waits out its send.
      expect(_sendingOf(state: state)?.text, "one");
      expect(cubit.composerDraft, ComposerDraft.typed(text: "two"));
      sendCompleter.complete(ApiResponse.success(null));
    });

    group("a stop while this screen's own send is in flight", () {
      final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([5]), filename: null);
      late List<String> sentTexts;
      late Completer<ApiResponse<void>> firstSend;
      late Completer<ApiResponse<bool>> abortResponse;

      setUp(() {
        sentTexts = [];
        firstSend = Completer();
        abortResponse = Completer();
        when(
          () => mockSessionRepository.sendMessage(
            sessionId: _sessionId,
            promptId: any(named: "promptId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            fastMode: any(named: "fastMode"),
            command: any(named: "command"),
            commandSource: any(named: "commandSource"),
          ),
        ).thenAnswer((invocation) {
          final text = invocation.namedArguments[#text] as String;
          sentTexts.add(text);
          return text == "one" ? firstSend.future : Future.value(ApiResponse.success(null));
        });
        when(
          () => mockSessionRepository.abortSession(
            sessionId: _sessionId,
            subAgents: any(named: "subAgents"),
          ),
        ).thenAnswer((_) => abortResponse.future);
      });

      // "one" is sending, with "two" staged behind it, when Stop is pressed.
      Future<SessionDetailCubit> stopWhileSending({List<ComposerAttachment> firstAttachments = const []}) async {
        final cubit = await createLoadedCubit(supportsPromptAttachments: true, commands: const [_reviewCommand]);
        unawaited(
          cubit.sendMessage(
            text: "one",
            command: null,
            inputMode: ComposerInputMode.typed,
            attachments: firstAttachments,
          ),
        );
        await _awaitCondition(() => _sendingOf(state: cubit.state as SessionDetailLoaded) != null);
        await cubit.sendMessage(text: "two", command: null, inputMode: ComposerInputMode.typed, attachments: [image]);
        cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));
        return cubit;
      }

      test("returns with the stop when the bridge accepted it before the stop was answered", () async {
        // Sent before the stop and accepted first, it was in the bridge's queue
        // or steering the turn the stop then ended, so the stop dropped it.
        final cubit = await stopWhileSending();
        final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
        firstSend.complete(ApiResponse.success(null));
        await Future<void>.delayed(Duration.zero);
        abortResponse.complete(ApiResponse.success(true));
        await aborting;

        expect(cubit.composerDraft, ComposerDraft.typed(text: "one\n\ntwo\n\nhalf typed"));
        final state = cubit.state as SessionDetailLoaded;
        expect(_sendingOf(state: state), isNull);
        expect(state.awaitingBridgeSubmissions, isEmpty);
        expect(sentTexts, ["one"]);
      });

      for (final (outcome, finish) in <(String, void Function(Completer<ApiResponse<bool>>))>[
        ("an accepted", (stop) => stop.complete(ApiResponse.success(true))),
        ("an ambiguous", (stop) => stop.completeError(StateError("response lost"))),
      ]) {
        test("stays out of the composer at $outcome stop and counts as sent once accepted", () async {
          final cubit = await stopWhileSending();
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          finish(abortResponse);
          await aborting;

          expect(cubit.composerDraft, ComposerDraft.typed(text: "two\n\nhalf typed"));
          expect(cubit.restoredAttachments, [image]);
          var state = cubit.state as SessionDetailLoaded;
          expect(_sendingOf(state: state)?.text, "one", reason: "it stays in view while the bridge may take it");
          expect(state.queuedMessages, isEmpty);
          expect(state.composerRestorations, 1);

          // Sent after the stop, it waits behind the one still sending.
          await cubit.sendMessage(text: "three", command: null, inputMode: ComposerInputMode.typed, attachments: []);
          expect(sentTexts, ["one"]);

          firstSend.complete(ApiResponse.success(null));
          await _awaitCondition(() => sentTexts.length == 2);

          state = cubit.state as SessionDetailLoaded;
          expect(state.awaitingBridgeSubmissions.map((entry) => entry.submission.text), ["one", "three"]);
          expect(state.localSend, isA<LocalSendIdle>());
          expect(state.composerRestorations, 1);
          expect(cubit.composerDraft, ComposerDraft.typed(text: "two\n\nhalf typed"));
          expect(sentTexts, ["one", "three"]);
        });
      }

      final staleOptionsError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      for (final (failure, failSend) in <(String, void Function(Completer<ApiResponse<void>>))>[
        ("is refused", (send) => send.complete(ApiResponse.error(ApiError.generic()))),
        ("times out", (send) => send.completeError(TimeoutException("no answer"))),
        ("names stale options", (send) => send.complete(ApiResponse.error(staleOptionsError))),
      ]) {
        test("comes back once, after what the stop returned, when its send $failure", () async {
          final firstImage = ComposerImageAttachment(
            mime: "image/png",
            bytes: Uint8List.fromList([6]),
            filename: null,
          );
          final cubit = await stopWhileSending(firstAttachments: [firstImage]);
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());
          await cubit.sendMessage(text: "three", command: null, inputMode: ComposerInputMode.typed, attachments: []);

          failSend(firstSend);
          await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == 2);
          await _awaitCondition(() => sentTexts.length == 2);

          expect(cubit.composerDraft, ComposerDraft.typed(text: "two\n\none\n\nhalf typed"));
          expect(cubit.restoredAttachments, [image, firstImage]);
          final state = cubit.state as SessionDetailLoaded;
          expect(state.localSend, isA<LocalSendIdle>(), reason: "no Retry: the composer holds it");
          expect(state.awaitingBridgeSubmissions.map((entry) => entry.submission.text), ["three"]);
          // It is not sent again; what was sent after the stop goes on.
          expect(sentTexts, ["one", "three"]);
        });
      }

      test("one that fails after a command was staged over what the stop returned still comes after it", () async {
        final cubit = await stopWhileSending();
        final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
        abortResponse.complete(ApiResponse.success(true));
        expect(await aborting, isA<SessionAbortAccepted>());
        cubit.stageCommand(_reviewCommand);

        firstSend.complete(ApiResponse.error(ApiError.generic()));
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == 2);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "/review two\n\none\n\nhalf typed"));
        expect((cubit.state as SessionDetailLoaded).stagedCommand, isNull);
      });

      test("one the bridge listed while its send was pending returns at the stop, and never shows as sent", () async {
        final cubit = await stopWhileSending();
        final promptId = _sendingOf(state: cubit.state as SessionDetailLoaded)?.promptId ?? fail("not sending");
        sessionEvents.add(
          SesoriSseEvent.sessionQueuedPrompts(
            sessionID: _sessionId,
            prompts: [
              QueuedSessionPrompt(
                commandSource: null,
                id: promptId,
                text: "one",
                command: null,
                attachmentCount: 0,
                createdAt: 50,
              ),
            ],
          ) as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);
        final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
        abortResponse.complete(ApiResponse.success(true));
        expect(await aborting, isA<SessionAbortAccepted>());
        expect(cubit.composerDraft, ComposerDraft.typed(text: "one\n\ntwo\n\nhalf typed"));

        firstSend.complete(ApiResponse.success(null));
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        final state = cubit.state as SessionDetailLoaded;
        expect(state.localSend, isA<LocalSendIdle>());
        expect(state.awaitingBridgeSubmissions, isEmpty, reason: "the stop dropped it with the bridge's queue");
        expect(state.composerRestorations, 1);
        expect(cubit.composerDraft, ComposerDraft.typed(text: "one\n\ntwo\n\nhalf typed"));
      });
    });

    test("opening the created session discharges its launch", () async {
      final storage = SessionLaunchStorage();
      final repository = SessionLaunchRepository(storage: storage)
        ..start(
          launchId: "launch-1",
          projectId: "project-1",
          pluginId: "claude",
          startedAt: DateTime.utc(2026, 9, 27),
          projectName: null,
          submission: NewSessionSubmissionSnapshot.text(
            draft: ComposerDraft.typed(text: "Hello"),
            attachments: const [],
          ),
        )
        ..promote(
          launchId: "launch-1",
          session: testSession(id: _sessionId),
        );

      await createLoadedCubit(sessionLaunchRepository: repository);

      expect(storage.readAll(), isEmpty);
    });

    // A gateway or login failure mid-turn makes the bridge shut the harness
    // down, dropping the sends it accepted and had not shown yet.
    group("a harness block", () {
      final ready = managementFixture(
        pluginId: "plugin-1",
        setup: PluginSetupState.ready,
        runtime: PluginRuntimeState.active,
      );
      final gatewayRejected = managementFixture(
        pluginId: "plugin-1",
        setup: PluginSetupState.unavailable,
        runtime: PluginRuntimeState.stopping,
        actionHint: "Check the gateway's credentials and configuration, then refresh setup.",
      );
      late BehaviorSubject<PluginManagementLoadResult> snapshots;

      setUp(() {
        snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(ready);
        when(
          () => mockSessionRepository.sendMessage(
            sessionId: _sessionId,
            promptId: any(named: "promptId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            fastMode: any(named: "fastMode"),
            command: any(named: "command"),
            commandSource: any(named: "commandSource"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(null));
      });
      tearDown(() => snapshots.close());

      Future<void> block(SessionDetailCubit cubit) async {
        snapshots.add(gatewayRejected);
        await _awaitCondition(() => !(cubit.state as SessionDetailLoaded).interaction.canInteract);
      }

      test("puts an accepted send the harness never showed back into the composer", () async {
        final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([1]), filename: null);
        final cubit = await createLoadedCubit(managementSnapshots: snapshots, supportsPromptAttachments: true);
        await cubit.sendMessage(
          text: "Fix the build",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: [image],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty);

        await block(cubit);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "Fix the build"));
        expect(cubit.restoredAttachments, [image]);
        final state = cubit.state as SessionDetailLoaded;
        expect(state.composerRestorations, 1);
        // Its "Sending to" row leaves as the draft fills.
        expect(state.awaitingBridgeSubmissions, isEmpty);

        // Check setup's refresh finds the prompt gone and leaves the draft be.
        snapshots.add(ready);
        await cubit.checkHarnessSetup();
        expect((cubit.state as SessionDetailLoaded).interaction.canInteract, isTrue);
        expect(cubit.composerDraft, ComposerDraft.typed(text: "Fix the build"));
        expect((cubit.state as SessionDetailLoaded).composerRestorations, 1);
      });

      test("puts a send the harness accepts only after the block back into the composer", () async {
        final accepted = Completer<ApiResponse<void>>();
        when(
          () => mockSessionRepository.sendMessage(
            sessionId: _sessionId,
            promptId: any(named: "promptId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            fastMode: any(named: "fastMode"),
            command: any(named: "command"),
            commandSource: any(named: "commandSource"),
          ),
        ).thenAnswer((_) => accepted.future);
        final cubit = await createLoadedCubit(managementSnapshots: snapshots);
        final sending = cubit.sendMessage(
          text: "Fix the build",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).localSend is LocalSendSending);
        cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

        // The block lands while the send is still in flight, so nothing is
        // accepted yet to return.
        await block(cubit);
        expect(cubit.composerDraft, ComposerDraft.typed(text: "half typed"));

        accepted.complete(ApiResponse.success(null));
        await sending;

        expect(cubit.composerDraft, ComposerDraft.typed(text: "Fix the build\n\nhalf typed"));
        final state = cubit.state as SessionDetailLoaded;
        expect(state.awaitingBridgeSubmissions, isEmpty);
        expect(state.localSend, isA<LocalSendIdle>());

        // Check setup's refresh finds the prompt gone and leaves the draft be.
        snapshots.add(ready);
        await cubit.checkHarnessSetup();
        expect(cubit.composerDraft, ComposerDraft.typed(text: "Fix the build\n\nhalf typed"));
        expect((cubit.state as SessionDetailLoaded).composerRestorations, 1);
      });

      test("puts a send accepted after the block behind those it returned, images and all", () async {
        final held = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([1]), filename: null);
        final first = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([2]), filename: null);
        final second = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([3]), filename: null);
        final secondAccepted = Completer<ApiResponse<void>>();
        var sends = 0;
        when(
          () => mockSessionRepository.sendMessage(
            sessionId: _sessionId,
            promptId: any(named: "promptId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            fastMode: any(named: "fastMode"),
            command: any(named: "command"),
            commandSource: any(named: "commandSource"),
          ),
        ).thenAnswer((_) => ++sends == 1 ? Future.value(ApiResponse.success(null)) : secondAccepted.future);
        final cubit = await createLoadedCubit(managementSnapshots: snapshots, supportsPromptAttachments: true);
        await cubit.sendMessage(
          text: "first",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: [first],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty);
        final sending = cubit.sendMessage(
          text: "second",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: [second],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).localSend is LocalSendSending);
        cubit
          ..saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"))
          ..trackComposerAttachments(attachments: [held]);

        await block(cubit);
        expect(cubit.composerDraft, ComposerDraft.typed(text: "first\n\nhalf typed"));
        expect(cubit.restoredAttachments, [held, first]);

        // Accepted before the composer rebuilds to stage the first return.
        secondAccepted.complete(ApiResponse.success(null));
        await sending;

        expect(cubit.composerDraft, ComposerDraft.typed(text: "first\n\nsecond\n\nhalf typed"));
        expect(cubit.restoredAttachments, [held, first, second]);
        expect((cubit.state as SessionDetailLoaded).composerRestorations, 2);
      });

      for (final (outcome, finish) in <(String, void Function(Completer<ApiResponse<bool>>))>[
        ("succeeds", (stop) => stop.complete(ApiResponse.success(true))),
        ("fails ambiguously", (stop) => stop.completeError(StateError("502 after cancellation"))),
      ]) {
        test("returns a send once when it lands while a stop that then $outcome is in flight", () async {
          final stop = Completer<ApiResponse<bool>>();
          when(
            () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
          ).thenAnswer((_) => stop.future);
          final cubit = await createLoadedCubit(managementSnapshots: snapshots, snapshotQueue: const [_queuedPrompt]);
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

          await block(cubit);
          expect(cubit.composerDraft, ComposerDraft.typed(text: "steer it"));

          finish(stop);
          await aborting;

          expect(cubit.composerDraft, ComposerDraft.typed(text: "steer it"));
          expect((cubit.state as SessionDetailLoaded).composerRestorations, 1);
        });
      }

      test("does not return again what an ambiguous stop returned while the bridge still lists it", () async {
        when(
          () => mockSessionRepository.abortSession(sessionId: _sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
        ).thenAnswer((_) async => throw StateError("502 after cancellation"));
        final cubit = await createLoadedCubit(managementSnapshots: snapshots, snapshotQueue: const [_queuedPrompt]);
        expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop), isA<SessionAbortFailed>());
        expect(cubit.composerDraft, ComposerDraft.typed(text: "steer it"));
        expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isNotEmpty);

        await block(cubit);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "steer it"));
        final state = cubit.state as SessionDetailLoaded;
        expect(state.composerRestorations, 1);
        // The harness the block shut down dropped it, so its row goes too.
        expect(state.bridgeQueuedPrompts, isEmpty);
        expect(state.queuedMessages, isEmpty);
      });

      test("puts the sends back ahead of the draft, and the bridge's rows with them", () async {
        const dispatched = QueuedSessionPrompt(
          commandSource: null,
          id: "prm_steering",
          dispatchState: QueuedPromptDispatchState.dispatched,
          text: "steered, never echoed",
          command: null,
          createdAt: 101,
        );
        final cubit = await createLoadedCubit(managementSnapshots: snapshots, snapshotQueue: const [dispatched]);
        await cubit.sendMessage(
          text: "and then",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty);
        cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

        await block(cubit);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "steered, never echoed\n\nand then\n\nhalf typed"));
        final state = cubit.state as SessionDetailLoaded;
        expect(state.composerRestorations, 1);
        expect(state.bridgeQueuedPrompts, isEmpty);
        expect(state.awaitingBridgeSubmissions, isEmpty);
      });

      test("leaves a send the transcript shows as its sent message", () async {
        final cubit = await createLoadedCubit(managementSnapshots: snapshots);
        await cubit.sendMessage(
          text: "delivered",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty);
        final deliveredId = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single.submission.promptId;
        sessionEvents
          ..add(
            SesoriMessageUpdated(
              info: Message.user(
                invocation: null,
                id: "echo-1",
                sessionID: _sessionId,
                agent: null,
                time: const MessageTime(created: 200, completed: null),
                promptId: deliveredId,
              ),
            ),
          )
          ..add(_textPartFor(messageId: "echo-1", text: "delivered"));
        await cubit.sendMessage(
          text: "never shown",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        await _awaitCondition(
          () => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.any(
            (entry) => entry.submission.promptId != deliveredId,
          ),
        );

        await block(cubit);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "never shown"));
        expect((cubit.state as SessionDetailLoaded).composerRestorations, 1);
      });

      test("puts dictated words back as dictated", () async {
        final cubit = await createLoadedCubit(managementSnapshots: snapshots);
        await cubit.sendMessage(
          text: "fix the build",
          command: null,
          inputMode: ComposerInputMode.voiceAssisted,
          attachments: const [],
        );
        await _awaitCondition(() => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.isNotEmpty);

        await block(cubit);

        expect(
          cubit.composerDraft,
          ComposerDraft(text: "fix the build", voiceSpans: [VoiceOriginSpan(start: 0, end: 13)]),
        );
      });

      test("restores nothing when every send has been shown", () async {
        final cubit = await createLoadedCubit(managementSnapshots: snapshots);
        cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

        await block(cubit);

        expect(cubit.composerDraft, ComposerDraft.typed(text: "half typed"));
        expect((cubit.state as SessionDetailLoaded).composerRestorations, 0);
      });
    });

    group("launch handoff", () {
      final submission = NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Hello"),
        attachments: const [],
      );
      final startedAt = DateTime.utc(2026, 9, 27, 12);

      SessionLaunchRepository launchedRepository({
        Set<String> followUpIds = const {},
        List<LaunchFollowUp> followUps = const [],
        SessionLaunchComposer? composer,
      }) {
        final storage = SessionLaunchStorage();
        storage.write(
          launch: SessionLaunch.created(
            launchId: "launch-1",
            projectId: "project-1",
            pluginId: "claude",
            startedAt: startedAt,
            followUpIds: {...followUpIds, for (final followUp in followUps) followUp.submission.promptId},
            followUps: followUps,
            session: testSession(id: _sessionId),
            submission: submission,
            composer: composer,
          ),
        );
        return SessionLaunchRepository(storage: storage);
      }

      QueuedSessionSubmission followUp({required String promptId}) => QueuedSessionSubmission.text(
        promptId: promptId,
        text: "and then $promptId",
        inputMode: ComposerInputMode.typed,
        attachments: const [],
        agent: null,
        agentModel: null,
        fastMode: false,
      );

      final expectedHandoff = SessionLaunchHandoff(
        submission: submission,
        pluginId: "claude",
        startedAt: startedAt,
        followUpIds: const {},
        acceptedFollowUps: const [],
        composer: null,
      );

      Iterable<SessionDetailLoaded> showingBoth(List<SessionDetailState> emissions) =>
          emissions.whereType<SessionDetailLoaded>().where(
            (state) =>
                state.launchHandoff != null &&
                state.messages.any(
                  (message) => message.info is MessageUser && message.parts.any((part) => part is MessagePartText),
                ),
          );

      test("the first frame and the loaded screen carry the launch's first message", () async {
        final repository = launchedRepository();
        SessionDetailState? initial;
        final cubit = await createLoadedCubit(
          sessionLaunchRepository: repository,
          onInitialState: (state) => initial = state,
        );

        expect(initial, SessionDetailState.loading(launchHandoff: expectedHandoff, seededComposer: null));
        expect((cubit.state as SessionDetailLoaded).launchHandoff, expectedHandoff);
        expect(repository.takeHandoff(sessionId: _sessionId), isNull, reason: "the handoff is taken once");
      });

      test("an ordinary open has no launch bubble", () async {
        SessionDetailState? initial;
        final cubit = await createLoadedCubit(onInitialState: (state) => initial = state);

        expect(initial, const SessionDetailState.loading(launchHandoff: null, seededComposer: null));
        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNull);
      });

      test("a snapshot that already holds the user message never shows the bubble beside it", () async {
        final cubit = await createLoadedCubit(
          sessionLaunchRepository: launchedRepository(),
          snapshotMessages: [
            const MessageWithParts(
              info: Message.user(
                invocation: null,
                id: "msg-1",
                sessionID: _sessionId,
                agent: null,
                time: MessageTime(created: 100, completed: null),
                promptId: null,
              ),
              parts: [
                MessagePart.text(id: "part-1", sessionID: _sessionId, messageID: "msg-1", text: "Hello"),
              ],
            ),
          ],
        );

        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNull);
      });

      test("the bubble gives way to the streamed user message in the same frame it renders", () async {
        final cubit = await createLoadedCubit(sessionLaunchRepository: launchedRepository());
        final emissions = <SessionDetailState>[];
        final subscription = cubit.stream.listen(emissions.add);
        addTearDown(subscription.cancel);

        sessionEvents.add(
          const SesoriMessageUpdated(
            info: Message.user(
              invocation: null,
              id: "msg-1",
              sessionID: _sessionId,
              agent: null,
              time: MessageTime(created: 100, completed: null),
              promptId: null,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          (cubit.state as SessionDetailLoaded).launchHandoff,
          expectedHandoff,
          reason: "a bare envelope cannot render yet",
        );

        sessionEvents.add(_textPartFor(messageId: "msg-1", text: "Hello"));
        await Future<void>.delayed(Duration.zero);

        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNull);
        expect(showingBoth(emissions), isEmpty);
      });

      test("a queued prompt replaces the bubble unless it is one of the launch's follow-ups", () async {
        final cubit = await createLoadedCubit(sessionLaunchRepository: launchedRepository(followUpIds: {"prm_1"}));

        sessionEvents.add(
          const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: [_queuedPrompt])
              as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);
        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNotNull);

        sessionEvents.add(
          const SesoriSseEvent.sessionQueuedPrompts(
            sessionID: _sessionId,
            prompts: [
              _queuedPrompt,
              QueuedSessionPrompt(
                commandSource: null,
                id: "prm_2",
                text: "Hello",
                command: null,
                attachmentCount: 0,
                createdAt: 50,
              ),
            ],
          ) as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);
        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNull);
      });

      test("abort drops the launch bubble", () async {
        when(
          () => mockSessionRepository.abortSession(
            sessionId: any(named: "sessionId"),
            subAgents: any(named: "subAgents"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(true));
        final cubit = await createLoadedCubit(sessionLaunchRepository: launchedRepository());

        await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNull);
      });

      group("a stop while the launch's follow-ups wait", () {
        final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List.fromList([7]), filename: null);
        late List<String> sentPromptIds;
        late Completer<ApiResponse<void>> firstSend;
        late Completer<ApiResponse<bool>> abortResponse;

        setUp(() {
          sentPromptIds = [];
          firstSend = Completer();
          abortResponse = Completer();
          when(
            () => mockSessionRepository.sendMessage(
              sessionId: any(named: "sessionId"),
              promptId: any(named: "promptId"),
              text: any(named: "text"),
              attachments: any(named: "attachments"),
              agent: any(named: "agent"),
              model: any(named: "model"),
              variant: any(named: "variant"),
              fastMode: any(named: "fastMode"),
              command: any(named: "command"),
              commandSource: any(named: "commandSource"),
            ),
          ).thenAnswer((invocation) {
            final promptId = invocation.namedArguments[#promptId] as String;
            sentPromptIds.add(promptId);
            return promptId == "prm_a" ? firstSend.future : Future.value(ApiResponse.success(null));
          });
          when(
            () => mockSessionRepository.abortSession(
              sessionId: _sessionId,
              subAgents: any(named: "subAgents"),
            ),
          ).thenAnswer((_) => abortResponse.future);
        });

        SessionLaunchService launchService({required SessionLaunchRepository repository}) => SessionLaunchService(
          sessionRepository: mockSessionRepository,
          launchRepository: repository,
          feedbackPromptService: FakeFeedbackPromptService(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          selectionTracker: NewSessionSelectionTracker(),
          authSession: FakeAuthSession(initialState: const AuthState.initial()),
        );

        // The first follow-up failed; the user retries it and presses Stop while
        // it is sending, with the rest still queued behind it.
        Future<({SessionDetailCubit cubit, SessionLaunchRepository repository})> stopWhileSending({
          required List<LaunchFollowUp> queuedBehind,
          QueuedSessionSubmission? first,
          ValueStream<PluginManagementLoadResult>? managementSnapshots,
        }) async {
          final repository = launchedRepository(
            followUps: [
              LaunchFollowUp.failed(
                submission: first ?? followUp(promptId: "prm_a"),
                failure: const PromptSendFailure.uncertain(),
              ),
              ...queuedBehind,
            ],
          );
          final cubit = await createLoadedCubit(
            sessionLaunchService: launchService(repository: repository),
            managementSnapshots: managementSnapshots,
          );
          cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));
          cubit.retryLaunchFollowUp(promptId: "prm_a");
          expect(sentPromptIds, ["prm_a"]);
          return (cubit: cubit, repository: repository);
        }

        test("an accepted stop returns them to the composer, in order, and none sends after it", () async {
          final (:cubit, :repository) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: const QueuedSessionSubmission.text(
                  promptId: "prm_b",
                  text: "and then prm_b",
                  inputMode: ComposerInputMode.voiceAssisted,
                  attachments: [],
                  agent: null,
                  agentModel: null,
                  fastMode: false,
                ),
                since: DateTime(2026),
              ),
              LaunchFollowUp.queued(
                submission: QueuedSessionSubmission.text(
                  promptId: "prm_c",
                  text: "and then prm_c",
                  inputMode: ComposerInputMode.typed,
                  attachments: [image],
                  agent: null,
                  agentModel: null,
                  fastMode: false,
                ),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          // The retried one lands while the stop is decided; the next must wait.
          firstSend.complete(ApiResponse.success(null));
          await Future<void>.delayed(Duration.zero);
          expect(sentPromptIds, ["prm_a"]);

          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());

          expect(
            cubit.composerDraft,
            ComposerDraft(
              text: "and then prm_a\n\nand then prm_b\n\nand then prm_c\n\nhalf typed",
              voiceSpans: [VoiceOriginSpan(start: 16, end: 30)],
            ),
          );
          expect(cubit.restoredAttachments, [image]);
          final state = cubit.state as SessionDetailLoaded;
          expect(state.composerRestorations, 1);
          expect(state.launchFollowUps, isEmpty);
          expect(state.awaitingBridgeSubmissions, isEmpty);
          await Future<void>.delayed(Duration.zero);
          expect(repository.beginFollowUp(launchId: "launch-1"), isNull);
          expect(sentPromptIds, ["prm_a"]);
          expect((cubit.state as SessionDetailLoaded).launchFollowUps, isEmpty);
        });

        test(
          "one still sending at an accepted stop stays out of the composer and counts as sent once accepted",
          () async {
            final (:cubit, :repository) = await stopWhileSending(
              queuedBehind: [
                LaunchFollowUp.queued(
                  submission: followUp(promptId: "prm_b"),
                  since: DateTime(2026),
                ),
              ],
            );
            final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
            abortResponse.complete(ApiResponse.success(true));
            expect(await aborting, isA<SessionAbortAccepted>());
            expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_b\n\nhalf typed"));
            expect((cubit.state as SessionDetailLoaded).launchFollowUps.map((f) => f.submission.promptId), ["prm_a"]);

            firstSend.complete(ApiResponse.success(null));
            await _awaitCondition(
              () => (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.any(
                (entry) => entry.submission.promptId == "prm_a",
              ),
            );

            final state = cubit.state as SessionDetailLoaded;
            expect(state.launchFollowUps, isEmpty);
            expect(state.composerRestorations, 1);
            expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_b\n\nhalf typed"));
            expect(repository.beginFollowUp(launchId: "launch-1"), isNull);
            expect(sentPromptIds, ["prm_a"]);
          },
        );

        test("one still sending at an accepted stop that then fails comes back after the others, once", () async {
          final (:cubit, :repository) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_b"),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());

          firstSend.complete(ApiResponse.error(ApiError.generic()));
          await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == 2);
          await Future<void>.delayed(Duration.zero);

          expect(
            cubit.composerDraft,
            ComposerDraft.typed(text: "and then prm_b\n\nand then prm_a\n\nhalf typed"),
          );
          final state = cubit.state as SessionDetailLoaded;
          expect(state.launchFollowUps, isEmpty);
          expect(state.awaitingBridgeSubmissions, isEmpty);
          expect(state.composerRestorations, 2);
          expect(repository.retryFollowUp(promptId: "prm_a"), isNull, reason: "the launch no longer holds it");
          expect(sentPromptIds, ["prm_a"]);
        });

        QueuedSessionSubmission withImage({required String promptId, required String text}) =>
            QueuedSessionSubmission.text(
              promptId: promptId,
              text: text,
              inputMode: ComposerInputMode.typed,
              attachments: [image],
              agent: null,
              agentModel: null,
              fastMode: false,
            );

        Future<void> failFirstSend({required SessionDetailCubit cubit, required int restorations}) async {
          firstSend.complete(ApiResponse.error(ApiError.generic()));
          await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == restorations);
          await Future<void>.delayed(Duration.zero);
        }

        test("one that fails after the stop keeps the images the stop returned, not yet staged", () async {
          final secondImage = ComposerImageAttachment(
            mime: "image/png",
            bytes: Uint8List.fromList([8]),
            filename: null,
          );
          final (:cubit, repository: _) = await stopWhileSending(
            first: QueuedSessionSubmission.text(
              promptId: "prm_a",
              text: "and then prm_a",
              inputMode: ComposerInputMode.typed,
              attachments: [secondImage],
              agent: null,
              agentModel: null,
              fastMode: false,
            ),
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: withImage(promptId: "prm_b", text: "and then prm_b"),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());
          expect(cubit.restoredAttachments, [image]);

          await failFirstSend(cubit: cubit, restorations: 2);

          expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_b\n\nand then prm_a\n\nhalf typed"));
          expect(cubit.restoredAttachments, [image, secondImage]);
        });

        test("an image-only one that fails after the stop spells out a staged command", () async {
          final (:cubit, repository: _) = await stopWhileSending(
            first: withImage(promptId: "prm_a", text: ""),
            queuedBehind: const [],
          );
          cubit.stageCommand(_reviewCommand);
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());
          expect((cubit.state as SessionDetailLoaded).stagedCommand, _reviewCommand, reason: "nothing returned yet");

          await failFirstSend(cubit: cubit, restorations: 1);

          expect(cubit.composerDraft, ComposerDraft.typed(text: "/review half typed"));
          expect((cubit.state as SessionDetailLoaded).stagedCommand, isNull);
          expect(cubit.restoredAttachments, [image]);
        });

        test("one that fails after a command was staged over what the stop returned still comes after it", () async {
          final (:cubit, repository: _) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_b"),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());
          cubit.stageCommand(_reviewCommand);

          await failFirstSend(cubit: cubit, restorations: 2);

          expect(
            cubit.composerDraft,
            ComposerDraft.typed(text: "/review and then prm_b\n\nand then prm_a\n\nhalf typed"),
          );
          expect((cubit.state as SessionDetailLoaded).stagedCommand, isNull);
        });

        for (final succeeds in [true, false]) {
          test(
            "one the bridge listed while its send was pending returns at the stop, and the launch keeps no copy "
            "once the send ${succeeds ? "succeeds" : "fails"}",
            () async {
              final (:cubit, :repository) = await stopWhileSending(
                queuedBehind: [
                  LaunchFollowUp.queued(
                    submission: followUp(promptId: "prm_b"),
                    since: DateTime(2026),
                  ),
                ],
              );
              sessionEvents.add(
                const SesoriSseEvent.sessionQueuedPrompts(
                  sessionID: _sessionId,
                  prompts: [
                    QueuedSessionPrompt(
                      commandSource: null,
                      id: "prm_a",
                      text: "and then prm_a",
                      command: null,
                      attachmentCount: 0,
                      createdAt: 50,
                    ),
                  ],
                ) as SesoriSessionEvent,
              );
              await Future<void>.delayed(Duration.zero);
              final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
              abortResponse.complete(ApiResponse.success(true));
              expect(await aborting, isA<SessionAbortAccepted>());
              expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nand then prm_b\n\nhalf typed"));

              // The send's outcome reaches the launch and then this screen.
              firstSend.complete(succeeds ? ApiResponse.success(null) : ApiResponse.error(ApiError.generic()));
              for (var i = 0; i < 10; i++) {
                await Future<void>.delayed(Duration.zero);
              }

              expect(sentPromptIds, ["prm_a"]);
              expect(repository.beginFollowUp(launchId: "launch-1"), isNull);
              final state = cubit.state as SessionDetailLoaded;
              expect(state.awaitingBridgeSubmissions, isEmpty, reason: "the stop dropped it with the bridge's queue");
              expect(state.launchFollowUps, isEmpty);
              expect(state.bridgeQueuedPrompts, isEmpty);
              expect(state.composerRestorations, 1);
              expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nand then prm_b\n\nhalf typed"));

              // Opened again, the session shows no copy of it, sent or failed.
              expect(repository.retryFollowUp(promptId: "prm_a"), isNull);
              expect(await repository.watchForSession(sessionId: _sessionId).first, isEmpty);
              final reopened = await createLoadedCubit(sessionLaunchService: launchService(repository: repository));
              await Future<void>.delayed(Duration.zero);
              final reopenedState = reopened.state as SessionDetailLoaded;
              expect(reopenedState.launchFollowUps, isEmpty);
              expect(reopenedState.awaitingBridgeSubmissions, isEmpty);
            },
          );
        }

        test("an image-carrying one the bridge listed after its send failed comes back with its images", () async {
          final repository = launchedRepository(
            followUps: [
              LaunchFollowUp.failed(
                submission: withImage(promptId: "prm_a", text: "and then prm_a"),
                failure: const PromptSendFailure.uncertain(),
              ),
            ],
          );
          final cubit = await createLoadedCubit(sessionLaunchService: launchService(repository: repository));
          cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));
          sessionEvents.add(
            const SesoriSseEvent.sessionQueuedPrompts(
              sessionID: _sessionId,
              prompts: [
                QueuedSessionPrompt(
                  commandSource: null,
                  id: "prm_a",
                  text: "and then prm_a",
                  command: null,
                  attachmentCount: 1,
                  createdAt: 50,
                ),
              ],
            ) as SesoriSessionEvent,
          );
          await Future<void>.delayed(Duration.zero);

          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());

          expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nhalf typed"));
          expect(cubit.restoredAttachments, [image]);
        });

        test("one that fails after the stop and is then listed by the bridge comes back only once", () async {
          final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
            managementFixture(pluginId: "plugin-1", setup: PluginSetupState.ready, runtime: PluginRuntimeState.active),
          );
          addTearDown(snapshots.close);
          final (:cubit, repository: _) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_b"),
                since: DateTime(2026),
              ),
            ],
            managementSnapshots: snapshots,
          );
          abortResponse.complete(ApiResponse.success(true));
          expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop), isA<SessionAbortAccepted>());
          await failFirstSend(cubit: cubit, restorations: 2);
          const draft = "and then prm_b\n\nand then prm_a\n\nhalf typed";
          expect(cubit.composerDraft, ComposerDraft.typed(text: draft));

          // The timed-out send had reached the bridge after all.
          void bridgeLists() => sessionEvents.add(
            const SesoriSseEvent.sessionQueuedPrompts(
              sessionID: _sessionId,
              prompts: [
                QueuedSessionPrompt(
                  commandSource: null,
                  id: "prm_a",
                  text: "and then prm_a",
                  command: null,
                  attachmentCount: 0,
                  createdAt: 50,
                ),
              ],
            ) as SesoriSessionEvent,
          );
          bridgeLists();
          await Future<void>.delayed(Duration.zero);
          expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop), isA<SessionAbortAccepted>());
          expect(cubit.composerDraft, ComposerDraft.typed(text: draft), reason: "a second stop");

          bridgeLists();
          await Future<void>.delayed(Duration.zero);
          snapshots.add(
            managementFixture(
              pluginId: "plugin-1",
              setup: PluginSetupState.unavailable,
              runtime: PluginRuntimeState.stopping,
              actionHint: "Check the gateway's credentials and configuration, then refresh setup.",
            ),
          );
          await _awaitCondition(() => !(cubit.state as SessionDetailLoaded).interaction.canInteract);
          expect(cubit.composerDraft, ComposerDraft.typed(text: draft), reason: "a harness block");
          expect((cubit.state as SessionDetailLoaded).composerRestorations, 2);
        });

        group("a harness block", () {
          late BehaviorSubject<PluginManagementLoadResult> snapshots;

          setUp(() {
            snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
              managementFixture(
                pluginId: "plugin-1",
                setup: PluginSetupState.ready,
                runtime: PluginRuntimeState.active,
              ),
            );
          });
          tearDown(() => snapshots.close());

          Future<void> block(SessionDetailCubit cubit) async {
            snapshots.add(
              managementFixture(
                pluginId: "plugin-1",
                setup: PluginSetupState.unavailable,
                runtime: PluginRuntimeState.stopping,
                actionHint: "Check the gateway's credentials and configuration, then refresh setup.",
              ),
            );
            await _awaitCondition(() => !(cubit.state as SessionDetailLoaded).interaction.canInteract);
          }

          for (final succeeds in [true, false]) {
            test(
              "returns one the bridge listed while its send was pending with its images, and no row or launch "
              "copy is left once the send ${succeeds ? "succeeds" : "fails"}",
              () async {
                final (:cubit, :repository) = await stopWhileSending(
                  first: withImage(promptId: "prm_a", text: "and then prm_a"),
                  queuedBehind: const [],
                  managementSnapshots: snapshots,
                );
                sessionEvents.add(
                  const SesoriSseEvent.sessionQueuedPrompts(
                    sessionID: _sessionId,
                    prompts: [
                      QueuedSessionPrompt(
                        commandSource: null,
                        id: "prm_a",
                        text: "and then prm_a",
                        command: null,
                        attachmentCount: 1,
                        createdAt: 50,
                      ),
                    ],
                  ) as SesoriSessionEvent,
                );
                await Future<void>.delayed(Duration.zero);

                await block(cubit);

                expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nhalf typed"));
                expect(cubit.restoredAttachments, [image]);
                var state = cubit.state as SessionDetailLoaded;
                expect(state.bridgeQueuedPrompts, isEmpty);
                expect(state.launchFollowUps, isEmpty, reason: "its row leaves as the draft fills");

                firstSend.complete(succeeds ? ApiResponse.success(null) : ApiResponse.error(ApiError.generic()));
                for (var i = 0; i < 10; i++) {
                  await Future<void>.delayed(Duration.zero);
                }

                state = cubit.state as SessionDetailLoaded;
                expect(state.awaitingBridgeSubmissions, isEmpty);
                expect(state.launchFollowUps, isEmpty);
                expect(state.composerRestorations, 1);
                expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nhalf typed"));
                expect(repository.retryFollowUp(promptId: "prm_a"), isNull, reason: "the launch no longer holds it");
                expect(await repository.watchForSession(sessionId: _sessionId).first, isEmpty);
              },
            );
          }

          test("returns one the launch's send delivers only after the block landed", () async {
            final (:cubit, repository: _) = await stopWhileSending(
              queuedBehind: const [],
              managementSnapshots: snapshots,
            );

            await block(cubit);
            expect(cubit.composerDraft, ComposerDraft.typed(text: "half typed"), reason: "nothing accepted yet");

            firstSend.complete(ApiResponse.success(null));
            await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == 1);

            expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_a\n\nhalf typed"));
            final state = cubit.state as SessionDetailLoaded;
            expect(state.awaitingBridgeSubmissions, isEmpty, reason: "the harness the block shut down dropped it");
            expect(state.launchFollowUps, isEmpty);
          });

          test("returns one queued behind the launch's send with its images, and it never sends", () async {
            final (:cubit, :repository) = await stopWhileSending(
              queuedBehind: [
                LaunchFollowUp.queued(
                  submission: withImage(promptId: "prm_b", text: "and then prm_b"),
                  since: DateTime(2026),
                ),
              ],
              managementSnapshots: snapshots,
            );

            await block(cubit);

            expect(cubit.composerDraft, ComposerDraft.typed(text: "and then prm_b\n\nhalf typed"));
            expect(cubit.restoredAttachments, [image]);
            expect(
              [
                for (final followUp in (cubit.state as SessionDetailLoaded).launchFollowUps)
                  followUp.submission.promptId,
              ],
              ["prm_a"],
              reason: "only the one sending keeps its row",
            );

            firstSend.complete(ApiResponse.success(null));
            await _awaitCondition(() => (cubit.state as SessionDetailLoaded).composerRestorations == 2);
            for (var i = 0; i < 10; i++) {
              await Future<void>.delayed(Duration.zero);
            }

            expect(
              cubit.composerDraft,
              ComposerDraft.typed(text: "and then prm_b\n\nand then prm_a\n\nhalf typed"),
              reason: "accepted later, it comes back after what the block returned",
            );
            expect(sentPromptIds, ["prm_a"]);
            expect((cubit.state as SessionDetailLoaded).launchFollowUps, isEmpty);
            expect(await repository.watchForSession(sessionId: _sessionId).first, isEmpty);
          });
        });

        test("an ambiguous stop returns them to the composer too, and none sends after it", () async {
          final (:cubit, repository: _) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_b"),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          firstSend.complete(ApiResponse.success(null));
          await Future<void>.delayed(Duration.zero);
          abortResponse.completeError(StateError("response lost"));
          expect(await aborting, isA<SessionAbortFailed>());

          expect(
            cubit.composerDraft,
            ComposerDraft.typed(text: "and then prm_a\n\nand then prm_b\n\nhalf typed"),
          );
          await Future<void>.delayed(Duration.zero);
          expect((cubit.state as SessionDetailLoaded).launchFollowUps, isEmpty);
          expect(sentPromptIds, ["prm_a"]);
        });

        test("a refused stop leaves them queued, and they send once it is refused", () async {
          final (:cubit, repository: _) = await stopWhileSending(
            queuedBehind: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_b"),
                since: DateTime(2026),
              ),
            ],
          );
          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm);
          firstSend.complete(ApiResponse.success(null));
          await Future<void>.delayed(Duration.zero);
          expect(sentPromptIds, ["prm_a"], reason: "nothing new sends while the stop is decided");

          abortResponse.completeError(
            SessionAbortRejectedException(
              rejection: const SessionAbortRejection(runningSubAgentCount: 1, mainAgentRunning: true),
              innerError: StateError("409"),
            ),
          );
          expect(await aborting, isA<SessionAbortRejected>());

          await _awaitCondition(() => sentPromptIds.length == 2);
          expect(sentPromptIds, ["prm_a", "prm_b"]);
          expect(cubit.composerDraft, ComposerDraft.typed(text: "half typed"));
          expect((cubit.state as SessionDetailLoaded).composerRestorations, 0);
        });

        test("a launch list published before the stop took them back does not bring them back", () async {
          final launchFollowUps = StreamController<List<LaunchFollowUp>>.broadcast();
          addTearDown(launchFollowUps.close);
          final service = _MockSessionLaunchService();
          when(() => service.takeHandoff(sessionId: _sessionId)).thenReturn(null);
          when(() => service.watchForSession(sessionId: _sessionId)).thenAnswer((_) => launchFollowUps.stream);
          when(
            () => service.withdrawFollowUps(sessionId: _sessionId),
          ).thenReturn((
            withdrawn: [
              followUp(promptId: "prm_a"),
              followUp(promptId: "prm_b"),
            ],
            sendingPromptIds: {},
          ));
          final cubit = await createLoadedCubit(sessionLaunchService: service);
          launchFollowUps.add([
            LaunchFollowUp.sending(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_b"),
              since: DateTime(2026),
            ),
          ]);
          await Future<void>.delayed(Duration.zero);
          cubit.saveComposerDraft(draft: ComposerDraft.typed(text: "half typed"));

          final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
          abortResponse.complete(ApiResponse.success(true));
          expect(await aborting, isA<SessionAbortAccepted>());
          final restoredDraft = ComposerDraft.typed(text: "and then prm_a\n\nand then prm_b\n\nhalf typed");
          expect(cubit.composerDraft, restoredDraft);

          // Published before the withdrawal, delivered after it.
          launchFollowUps.add([
            LaunchFollowUp.accepted(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_b"),
              since: DateTime(2026),
            ),
          ]);
          await Future<void>.delayed(Duration.zero);

          final state = cubit.state as SessionDetailLoaded;
          expect(state.launchFollowUps, isEmpty);
          expect(state.awaitingBridgeSubmissions, isEmpty);
          expect(state.composerRestorations, 1);
          expect(cubit.composerDraft, restoredDraft);
        });
      });

      void stubSends({required List<String> sentTexts}) {
        when(
          () => mockSessionRepository.sendMessage(
            sessionId: any(named: "sessionId"),
            promptId: any(named: "promptId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            fastMode: any(named: "fastMode"),
            command: any(named: "command"),
            commandSource: any(named: "commandSource"),
          ),
        ).thenAnswer((invocation) async {
          sentTexts.add(invocation.namedArguments[#text] as String);
          return ApiResponse.success(null);
        });
      }

      test("a follow-up the launch delivers while the screen is open is parked beside the bubble", () async {
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);

        expect(repository.beginFollowUp(launchId: "launch-1")?.submission.promptId, "prm_a");
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
        await Future<void>.delayed(Duration.zero);

        final state = cubit.state as SessionDetailLoaded;
        expect(state.awaitingBridgeSubmissions.map((item) => item.submission.promptId), ["prm_a"]);
        expect(state.awaitingBridgeSubmissions.single.since, DateTime(2026));
        expect(state.launchHandoff, isNotNull, reason: "a follow-up is not the first message's replacement");
      });

      test("a follow-up accepted before the screen took over keeps its send time", () async {
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        repository.beginFollowUp(launchId: "launch-1");
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");

        final loadGate = Completer<void>();
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository, loadGate: loadGate);

        final state = cubit.state as SessionDetailLoading;
        expect(state.awaitingBridgeSubmissions.single.since, DateTime(2026));
        loadGate.complete();
      });

      test("a follow-up whose message landed before its acceptance is not parked beside it", () async {
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);
        repository.beginFollowUp(launchId: "launch-1");

        sessionEvents
          ..add(
            const SesoriMessageUpdated(
              info: Message.user(
                invocation: null,
                id: "msg-a",
                sessionID: _sessionId,
                agent: null,
                time: MessageTime(created: 100, completed: null),
                promptId: "prm_a",
              ),
            ),
          )
          ..add(_textPartFor(messageId: "msg-a", text: "and then prm_a"));
        await Future<void>.delayed(Duration.zero);
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
        await Future<void>.delayed(Duration.zero);

        expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
      });

      test("a follow-up the bridge settled before its acceptance is not parked", () async {
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);
        repository.beginFollowUp(launchId: "launch-1");

        sessionEvents.add(
          const SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: "prm_a") as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
        await Future<void>.delayed(Duration.zero);

        expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
      });

      test("a failed follow-up the bridge settles anyway releases the prompts sent here", () async {
        final sentTexts = <String>[];
        stubSends(sentTexts: sentTexts);
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);
        await cubit.sendMessage(
          text: "after",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        repository.beginFollowUp(launchId: "launch-1");
        repository.followUpFailed(
          launchId: "launch-1",
          promptId: "prm_a",
          failure: const PromptSendFailure.uncertain(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(sentTexts, isEmpty);

        sessionEvents.add(
          const SesoriSseEvent.sessionPromptSettled(sessionID: _sessionId, promptID: "prm_a") as SesoriSessionEvent,
        );
        await _awaitCondition(() => sentTexts.isNotEmpty);

        expect(sentTexts, ["after"]);
      });

      test("a prompt sent here waits for the launch's follow-ups pressed before it", () async {
        final sentTexts = <String>[];
        stubSends(sentTexts: sentTexts);
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);

        await cubit.sendMessage(
          text: "after",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        await Future<void>.delayed(Duration.zero);
        expect(sentTexts, isEmpty);
        expect((cubit.state as SessionDetailLoaded).queuedMessages.map((submission) => submission.text), ["after"]);

        repository.beginFollowUp(launchId: "launch-1");
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
        await _awaitCondition(() => sentTexts.isNotEmpty);

        expect(sentTexts, ["after"]);
      });

      test("the loaded screen shows the launch's unsent follow-ups as they change", () async {
        final repository = launchedRepository(
          followUps: [
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_a"),
              since: DateTime(2026),
            ),
            LaunchFollowUp.queued(
              submission: followUp(promptId: "prm_b"),
              since: DateTime(2026),
            ),
          ],
        );
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);
        List<LaunchFollowUp> shown() => (cubit.state as SessionDetailLoaded).launchFollowUps;
        expect(shown().map((followUp) => followUp.submission.promptId), ["prm_a", "prm_b"]);

        repository.beginFollowUp(launchId: "launch-1");
        repository.followUpFailed(
          launchId: "launch-1",
          promptId: "prm_a",
          failure: const PromptSendFailure.rejected(reason: null),
        );
        await Future<void>.delayed(Duration.zero);
        expect(shown().first, isA<FailedLaunchFollowUp>());

        cubit.removeLaunchFollowUp(promptId: "prm_a");
        await Future<void>.delayed(Duration.zero);
        expect(shown().map((followUp) => followUp.submission.promptId), ["prm_b"]);
      });

      test("a screen opened before the create reply still gets the launch's follow-ups", () async {
        // Reaching the session's row means its composer was left, which drops
        // the first message's handoff; the follow-ups stay owed.
        final repository = SessionLaunchRepository(storage: SessionLaunchStorage())
          ..start(
            launchId: "launch-1",
            projectId: "project-1",
            pluginId: "claude",
            startedAt: startedAt,
            projectName: null,
            submission: submission,
          )
          ..addFollowUp(
            launchId: "launch-1",
            submission: followUp(promptId: "prm_a"),
          )
          ..releaseHandoff(launchId: "launch-1");
        final cubit = await createLoadedCubit(sessionLaunchRepository: repository);
        SessionDetailLoaded loaded() => cubit.state as SessionDetailLoaded;
        expect(loaded().launchFollowUps, isEmpty, reason: "nothing names this session yet");

        repository.promote(
          launchId: "launch-1",
          session: testSession(id: _sessionId),
        );
        await Future<void>.delayed(Duration.zero);
        expect(loaded().launchFollowUps.map((followUp) => followUp.submission.promptId), ["prm_a"]);

        expect(repository.beginFollowUp(launchId: "launch-1")?.submission.promptId, "prm_a");
        repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
        await Future<void>.delayed(Duration.zero);
        expect(loaded().awaitingBridgeSubmissions.map((item) => item.submission.promptId), ["prm_a"]);
      });

      test("a prompt sent here does not release the launch bubble when the bridge queues it", () async {
        final sentTexts = <String>[];
        stubSends(sentTexts: sentTexts);
        final cubit = await createLoadedCubit(sessionLaunchRepository: launchedRepository());

        await cubit.sendMessage(
          text: "steer it",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        final promptId =
            verify(
                  () => mockSessionRepository.sendMessage(
                    sessionId: any(named: "sessionId"),
                    promptId: captureAny(named: "promptId"),
                    text: any(named: "text"),
                    attachments: any(named: "attachments"),
                    agent: any(named: "agent"),
                    model: any(named: "model"),
                    variant: any(named: "variant"),
                    fastMode: any(named: "fastMode"),
                    command: any(named: "command"),
                    commandSource: any(named: "commandSource"),
                  ),
                ).captured.single
                as String;
        sessionEvents.add(
          SesoriSseEvent.sessionQueuedPrompts(
            sessionID: _sessionId,
            prompts: [
              QueuedSessionPrompt(
                commandSource: null,
                id: promptId,
                text: "steer it",
                command: null,
                attachmentCount: 0,
                createdAt: 50,
              ),
            ],
          ) as SesoriSessionEvent,
        );
        await Future<void>.delayed(Duration.zero);

        expect((cubit.state as SessionDetailLoaded).launchHandoff, isNotNull);
      });

      group("the launch's composer before the first load", () {
        final image = ComposerImageAttachment(
          mime: "image/png",
          bytes: utf8.encode("png"),
          filename: "a.png",
        );
        SessionLaunchComposer composer({required UnsentComposer? unsent}) => SessionLaunchComposer(
          agents: const [],
          agent: "plan",
          providers: const [],
          agentModel: null,
          availableVariants: const [],
          commands: const [],
          fastMode: false,
          supportsPromptAttachments: true,
          supportsFileUploads: false,
          hadFocus: true,
          unsent: unsent,
          namesCommandInvocations: false,
        );

        Future<void> send(SessionDetailCubit cubit, {required String text}) =>
            cubit.sendMessage(text: text, command: null, inputMode: ComposerInputMode.typed, attachments: const []);

        test("takes over what the composing route held unsent", () async {
          final cubit = await createLoadedCubit(
            sessionLaunchRepository: launchedRepository(
              composer: composer(
                unsent: UnsentComposer(
                  draft: ComposerDraft.typed(text: "carry on"),
                  selection: null,
                  command: _reviewCommand,
                  attachments: [image],
                ),
              ),
            ),
            loadGate: Completer<void>(),
          );

          final loading = cubit.state as SessionDetailLoading;
          expect(loading.seededComposer?.stagedCommand, _reviewCommand);
          expect(cubit.composerDraft.text, "carry on");
          expect(cubit.launchAttachments, [same(image)]);
          cubit.acknowledgeLaunchAttachments();
          expect(cubit.launchAttachments, isEmpty);

          cubit.clearStagedCommand();
          expect((cubit.state as SessionDetailLoading).seededComposer?.stagedCommand, isNull);
        });

        test("queues and shows a send, then sends it after the load behind the launch's follow-ups", () async {
          final sentTexts = <String>[];
          stubSends(sentTexts: sentTexts);
          final gate = Completer<void>();
          final repository = launchedRepository(
            followUps: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_a"),
                since: DateTime(2026),
              ),
            ],
            composer: composer(unsent: null),
          );
          final cubit = await createLoadedCubit(sessionLaunchRepository: repository, loadGate: gate);

          await send(cubit, text: "early");
          await Future<void>.delayed(Duration.zero);
          final loading = cubit.state as SessionDetailLoading;
          expect(loading.queuedMessages.map((submission) => submission.text), ["early"]);
          expect(loading.queuedMessages.single.agent, "plan", reason: "it runs on the options the launch locked");
          expect(loading.launchFollowUps.map((followUp) => followUp.submission.promptId), ["prm_a"]);
          expect(loading.launchHandoff?.followUpIds, contains(loading.queuedMessages.single.promptId));

          gate.complete();
          await cubit.stream.firstWhere((state) => state is SessionDetailLoaded);
          await Future<void>.delayed(Duration.zero);
          expect(sentTexts, isEmpty, reason: "the launch's follow-up was pressed first");

          repository.beginFollowUp(launchId: "launch-1");
          repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
          await _awaitCondition(() => sentTexts.isNotEmpty);
          expect(sentTexts, ["early"]);
        });

        test("an ordinary load still refuses a send before it loads", () async {
          final cubit = await createLoadedCubit(loadGate: Completer<void>());

          await send(cubit, text: "early");

          expect((cubit.state as SessionDetailLoading).queuedMessages, isEmpty);
        });

        test("sends before a failed first load stay shown and the screen's own go out on retry", () async {
          final sentTexts = <String>[];
          stubSends(sentTexts: sentTexts);
          final gate = Completer<void>();
          final repository = launchedRepository(
            followUps: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_a"),
                since: DateTime(2026),
              ),
            ],
            composer: composer(unsent: null),
          );
          final cubit = await createLoadedCubit(
            sessionLaunchRepository: repository,
            loadGate: gate,
            firstLoadFails: true,
          );

          await send(cubit, text: "early");
          gate.complete();
          final failed = await cubit.stream.firstWhere((state) => state is SessionDetailFailed) as SessionDetailFailed;
          expect(failed.queuedMessages.map((submission) => submission.text), ["early"]);
          expect(failed.launchFollowUps.map((followUp) => followUp.submission.promptId), ["prm_a"]);

          repository.beginFollowUp(launchId: "launch-1");
          repository.followUpAccepted(launchId: "launch-1", promptId: "prm_a");
          await Future<void>.delayed(Duration.zero);
          final accepted = cubit.state as SessionDetailFailed;
          expect(accepted.launchFollowUps, isEmpty);
          expect(
            accepted.awaitingBridgeSubmissions.map((item) => item.submission.promptId),
            ["prm_a"],
            reason: "a send the bridge took stays shown until the load lists it",
          );

          await cubit.reload();
          await _awaitCondition(() => sentTexts.isNotEmpty);
          expect(sentTexts, ["early"]);
        });

        test("a first load that finds the harness blocked keeps what is owed in view", () async {
          final gate = Completer<void>();
          final repository = launchedRepository(
            followUps: [
              LaunchFollowUp.queued(
                submission: followUp(promptId: "prm_a"),
                since: DateTime(2026),
              ),
            ],
            composer: composer(unsent: null),
          );
          final cubit = await createLoadedCubit(
            sessionLaunchRepository: repository,
            loadGate: gate,
            harnessBlocked: true,
          );

          await send(cubit, text: "early");
          gate.complete();
          final blocked = await cubit.stream.firstWhere(
            (state) => state is SessionDetailHarnessUnavailable,
          ) as SessionDetailHarnessUnavailable;
          expect(blocked.queuedMessages.map((submission) => submission.text), ["early"]);
          expect(blocked.launchFollowUps.map((followUp) => followUp.submission.promptId), ["prm_a"]);

          cubit.cancelQueuedMessage(0);
          expect((cubit.state as SessionDetailHarnessUnavailable).queuedMessages, isEmpty);
        });
      });
    });
  });
}

Future<void> _awaitCondition(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Timed out waiting for condition");
}

QueuedSessionSubmission? _sendingOf({required SessionDetailLoaded state}) => switch (state.localSend) {
  LocalSendSending(:final submission) => submission,
  LocalSendIdle() || LocalSendFailed() => null,
};

QueuedSessionSubmission _requireSendingOf({required SessionDetailLoaded state}) =>
    _sendingOf(state: state) ?? fail("no prompt is sending");

QueuedSessionSubmission? _failedOf({required SessionDetailLoaded state}) => switch (state.localSend) {
  LocalSendFailed(:final submission) => submission,
  LocalSendIdle() || LocalSendSending() => null,
};

class _MockSessionLaunchService() extends Mock implements SessionLaunchService;
