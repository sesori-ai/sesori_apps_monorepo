import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/logging/logging.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const _cooldown = Duration(milliseconds: 100);

void main() {
  const sessionId = "session-1";
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );
  const connectionLostStatus = ConnectionStatus.connectionLost(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  group("SessionDetailCubit stale reconnect", () {
    late MockSessionRepository mockSessionService;
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late MockProjectRepository mockProjectRepository;
    late SessionDetailLoadService loadService;
    late SessionRepository promptDispatcher;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late StreamController<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionService = MockSessionRepository();
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      mockProjectRepository = MockProjectRepository();
      loadService = SessionDetailLoadService(
        repository: mockSessionRepository,
        projectRepository: mockProjectRepository,
        pluginRepository: stubbedPluginRepository(),
        connectionService: mockConnectionService,
      );
      promptDispatcher = mockSessionRepository;
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      globalEvents = StreamController<SseEvent>.broadcast();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);

      when(() => mockConnectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
      delegateSessionRepository(repository: mockSessionRepository, source: mockSessionService);
      when(
        () => mockNotificationCanceller.cancelForSession(
          sessionId: any(named: "sessionId"),
        ),
      ).thenReturn(null);
      when(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));
      when(() => mockProjectRepository.findSessionContext(sessionId: sessionId)).thenAnswer(
        (_) async => const ProjectSessionContext(
          projectId: "test-project",
          pluginId: "plugin-1",
          sessionTitle: null,
        ),
      );
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );
      stubSessionRepositoryGetSession(repository: mockSessionRepository, sessionId: sessionId);

      _stubLoadApis(mockSessionService, sessionId: sessionId);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    test(
      "deferred refresh: stale while disconnected waits for ConnectionConnected before refreshing",
      () async {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);
        clearInteractions(mockSessionService);

        connectionStatus.add(connectionLostStatus);
        await pumpEventQueue();

        when(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-refreshed")], nextCursor: null),
          ),
        );

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitDataMayBeStale();
        await pumpEventQueue();

        verifyNever(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        );
        verifyNever(() => mockSessionService.getPendingQuestions(sessionId: sessionId));
        verifyNever(() => mockSessionService.getChildren(sessionId: sessionId));
        verifyNever(() => mockSessionService.getSessionStatuses());
        verifyNever(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: "plugin-1",
          ),
        );
        verifyNever(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: "plugin-1",
          ),
        );

        connectionStatus.add(connectedStatus);
        await pumpEventQueue();

        expect(emitted.length, 2);
        expect(emitted.first, isA<SessionDetailLoaded>().having((s) => s.isRefreshing, "isRefreshing", isTrue));
        expect(
          emitted.last,
          isA<SessionDetailLoaded>()
              .having((s) => s.isRefreshing, "isRefreshing", isFalse)
              .having((s) => s.messages.first.info.id, "updated message id", "msg-refreshed"),
        );
      },
    );

    test("deferred refresh: stale when connected triggers immediate refresh", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-immediate")], nextCursor: null),
        ),
      );

      final emitted = <SessionDetailState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      verify(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);
      verify(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);

      expect(emitted.first, isA<SessionDetailLoaded>().having((s) => s.isRefreshing, "isRefreshing", isTrue));
      expect(
        emitted.last,
        isA<SessionDetailLoaded>()
            .having((s) => s.isRefreshing, "isRefreshing", isFalse)
            .having((s) => s.messages.first.info.id, "updated message id", "msg-immediate"),
      );
    });

    test("selectAgent preserves the model when the agent has no model preference", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      final before = (cubit.state as SessionDetailLoaded).selectedAgentModel;
      cubit.selectAgent("Plan");

      final after = cubit.state as SessionDetailLoaded;
      expect(after.selectedAgent, "Plan");
      expect(after.selectedAgentModel, before);
    });

    test("silent refresh preserves selectedAgent and selectedAgentModel", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      cubit.selectAgent("oracle");
      cubit.selectModel(providerID: "openai", modelID: "gpt-4.1");
      cubit.selectVariant(const SessionVariant(id: "xhigh"));

      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Agents(
            agents: [
              AgentInfo(name: "build", description: "build", model: null, mode: AgentMode.primary),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const ProviderListResponse(
            connectedOnly: false,
            items: [
              ProviderInfo(
                id: "anthropic",
                name: "Anthropic",
                defaultModelID: "claude-3-5-sonnet",
                models: {
                  "claude-3-5-sonnet": ProviderModel(
                    id: "claude-3-5-sonnet",
                    providerID: "anthropic",
                    name: "Claude 3.5 Sonnet",
                    variants: [],
                    family: null,
                    releaseDate: null,
                  ),
                },
              ),
            ],
          ),
        ),
      );

      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.selectedAgent, "oracle");
      expect(
        loaded.selectedAgentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: "xhigh"),
      );
      expect(loaded.isRefreshing, isFalse);
    });

    test("sendMessage forwards selectedAgentModel variant to repository", () async {
      when(
        () => mockSessionRepository.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: sessionId,
          text: "hello",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "low"),
          command: null,
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      cubit.selectVariant(const SessionVariant(id: "low"));

      await cubit.sendMessage(
        attachments: const [],
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
      );

      verify(
        () => mockSessionRepository.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: sessionId,
          text: "hello",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "low"),
          command: null,
        ),
      ).called(1);
    });

    test("resume forwards the transcript model when the provider cache is stale", () async {
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const MessageWithPartsResponse(
            messages: [
              MessageWithParts(
                info: Message.error(
                  id: "msg-custom-model",
                  sessionID: sessionId,
                  agent: null,
                  modelID: "test-model",
                  providerID: "sesori-local",
                  errorName: "ProviderError",
                  errorMessage: "request failed",
                  time: null,
                ),
                parts: [],
              ),
            ],
            nextCursor: null,
          ),
        ),
      );
      when(
        () => mockSessionRepository.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: sessionId,
          text: "resume",
          agent: "coder",
          model: const PromptModel(providerID: "sesori-local", modelID: "test-model"),
          variant: null,
          command: null,
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      expect(
        (cubit.state as SessionDetailLoaded).selectedAgentModel,
        const AgentModel(providerID: "sesori-local", modelID: "test-model", variant: null),
      );

      await cubit.sendMessage(
        attachments: const [],
        text: "resume",
        command: null,
        inputMode: ComposerInputMode.typed,
      );

      verify(
        () => mockSessionRepository.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: sessionId,
          text: "resume",
          agent: "coder",
          model: const PromptModel(providerID: "sesori-local", modelID: "test-model"),
          variant: null,
          command: null,
        ),
      ).called(1);
    });

    test("delta race: streaming deltas arriving during refresh are preserved", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer((_) => messagesCompleter.future);
      when(
        () => mockSessionService.getPendingQuestions(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
      when(
        () => mockSessionService.getChildren(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
      when(
        () => mockSessionService.getSessionStatuses(),
      ).thenAnswer(
        (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
      );
      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: _agents())));
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_providers()));

      final emitted = <SessionDetailState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      sessionEvents.add(
        const SesoriMessagePartDelta(
          sessionID: sessionId,
          messageID: "msg-1",
          partID: "part-race",
          field: "text",
          delta: "delta-during-refresh",
        ),
      );
      await pumpEventQueue();

      messagesCompleter.complete(
        ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-race")], nextCursor: null),
        ),
      );
      await pumpEventQueue();

      final refreshed = emitted.last as SessionDetailLoaded;
      expect(refreshed.isRefreshing, isFalse);
      expect(refreshed.messages.first.info.id, "msg-race");
      expect(refreshed.streamingText, {"part-race": "delta-during-refresh"});
    });

    test("option failure retains the prior snapshot while waiting for retry", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);

      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-provider-fallback")], nextCursor: null),
        ),
      );
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.messages.first.info.id, "msg-1");
      expect(loaded.availableProviders, _providers().items);
    });

    test("stale signal is ignored when state is SessionDetailLoading", () async {
      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer((_) => messagesCompleter.future);

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );

      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      verify(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId"))).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);
      verify(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);

      messagesCompleter.complete(
        ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
      );
      await _awaitLoaded(cubit);
      await cubit.close();
    });

    test("stale signal is ignored when state is SessionDetailFailed", () async {
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitFailed(cubit);
      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      verify(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).called(1);
      expect(cubit.state, isA<SessionDetailFailed>());
    });

    test(
      "silent refresh failure logs warning and resets isRefreshing to false without changing state",
      () async {
        final logs = <String>[];
        final previousLogLevel = logLevel;
        setLogLevel(LogLevel.debug);
        addTearDown(() => setLogLevel(previousLogLevel));
        final cubit = runZoned(
          () => SessionDetailCubit(
            mockConnectionService,
            loadService: loadService,
            promptDispatcher: promptDispatcher,
            permissionRepository: mockPermissionRepository,
            sessionViewingService: stubbedSessionViewingService(),
            projectViewingService: stubbedProjectViewingService(),
            lifecycleSource: FakeLifecycleSource(),
            composerDraftRepository: inMemoryComposerDraftRepository(),
            productAnalyticsService: stubbedProductAnalyticsService(),
            sessionId: sessionId,
            projectId: "project-1",
            notificationCanceller: mockNotificationCanceller,
            failureReporter: MockFailureReporter(),
          ),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => logs.add(line),
          ),
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);
        final before = cubit.state as SessionDetailLoaded;
        final error = StateError("silent refresh sentinel");

        when(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenThrow(error);

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitDataMayBeStale();
        await pumpEventQueue();

        expect(emitted.length, 2);
        expect((emitted.first as SessionDetailLoaded).isRefreshing, isTrue);
        final afterFailure = emitted.last as SessionDetailLoaded;
        expect(afterFailure.isRefreshing, isFalse);
        expect(afterFailure.messages, before.messages);
        expect(afterFailure.selectedAgent, before.selectedAgent);
        expect(afterFailure.selectedAgentModel, before.selectedAgentModel);
        expect(logs, contains(contains("Silent refresh failed: Bad state: silent refresh sentinel")));
        expect(logs, contains(contains("SessionDetailCubit._doSilentRefresh")));
        expect(
          logs,
          contains(
            allOf(
              contains("[session-refresh] action=completed trigger=data_may_be_stale"),
              contains("result=failed"),
            ),
          ),
        );
        expect(
          logs.where((line) => line.startsWith("[session-refresh]")),
          everyElement(isNot(contains("silent refresh sentinel"))),
        );
      },
    );

    test("a failed leading stale refresh retries until a snapshot succeeds", () {
      fakeAsync((FakeAsync async) {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );
        var messageLoads = 0;
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) async {
          messageLoads++;
          if (messageLoads == 1) {
            return ApiResponse.error(ApiError.generic());
          }
          return ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null));
        });

        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        expect(messageLoads, 1);

        // The cooldown elapses and the restored staleness produces the retry.
        async.elapse(_cooldown);
        expect(messageLoads, 2);

        // The successful retry consumed the signal; later windows stay quiet.
        async.elapse(_cooldown * 2);
        expect(messageLoads, 2);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("an option load failure preserves catalogs and retries until options load", () {
      fakeAsync((FakeAsync async) {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        final before = cubit.state as SessionDetailLoaded;
        var providerLoads = 0;
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async {
          providerLoads++;
          return providerLoads == 1
              ? ApiResponse<ProviderListResponse>.error(ApiError.generic())
              : ApiResponse.success(_providers());
        });

        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);

        expect(providerLoads, 1);
        final afterFailure = cubit.state as SessionDetailLoaded;
        expect(afterFailure.availableAgents, before.availableAgents);
        expect(afterFailure.availableProviders, before.availableProviders);
        expect(afterFailure.availableCommands, before.availableCommands);

        // The cooldown elapses and the retained staleness retries the options.
        async.elapse(_cooldown);
        expect(providerLoads, 2);

        // The successful retry consumed the signal; later windows stay quiet.
        async.elapse(_cooldown * 2);
        expect(providerLoads, 2);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("a disconnected failed refresh waits for reconnect instead of retrying each cooldown", () async {
      late final SessionDetailCubit cubit;
      late final StreamSubscription<SessionDetailState> sub;
      fakeAsync((FakeAsync async) {
        cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        final firstMessages = Completer<ApiResponse<MessageWithPartsResponse>>();
        var messageLoads = 0;
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) {
          messageLoads++;
          if (messageLoads == 1) return firstMessages.future;
          return Future.value(
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
          );
        });

        final emitted = <SessionDetailState>[];
        sub = cubit.stream.listen(emitted.add);

        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        connectionStatus.add(connectionLostStatus);
        firstMessages.complete(ApiResponse.error(ApiError.generic()));

        // Several cooldown windows pass while disconnected: no retry fires.
        async.elapse(_cooldown * 3);
        expect(messageLoads, 1);
        expect(
          emitted.whereType<SessionDetailLoaded>().where((state) => state.isRefreshing),
          hasLength(1),
        );

        connectionStatus.add(connectedStatus);
        async.elapse(Duration.zero);
        expect(messageLoads, 2);
      });
      await sub.cancel();
      await cubit.close();
    });

    test("concurrent stale signals are coalesced (single API call)", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      reset(mockSessionService);

      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer((_) => messagesCompleter.future);
      when(
        () => mockSessionService.getPendingQuestions(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
      when(
        () => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId")),
      ).thenAnswer((_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])));
      when(
        () => mockSessionService.getChildren(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
      when(
        () => mockSessionService.getSessionStatuses(),
      ).thenAnswer(
        (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
      );
      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: _agents())));
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_providers()));
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );

      mockConnectionService.emitDataMayBeStale();
      mockConnectionService.emitDataMayBeStale();
      await pumpEventQueue();

      messagesCompleter.complete(
        ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-coalesced")], nextCursor: null),
        ),
      );
      await pumpEventQueue();

      verify(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId"))).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);
      verify(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: "plugin-1",
        ),
      ).called(1);
    });

    test("staleness bursts inside the cooldown collapse into one immediate and one trailing refresh", () {
      fakeAsync((FakeAsync async) {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        // A burst of staleness signals: the first refreshes immediately, the
        // rest queue behind the cooldown.
        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // Once the cooldown elapses, the queued signals collapse into exactly
        // one trailing refresh...
        async.elapse(_cooldown);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // ...and a drained queue schedules nothing further.
        async.elapse(_cooldown * 2);
        verifyNever(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        );

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("a queued signal survives a refresh that outlives the cooldown window", () {
      fakeAsync((FakeAsync async) {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        // Hold the first refresh's message fetch so the refresh itself spans
        // the entire cooldown window.
        final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) => messagesCompleter.future);

        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // The cooldown elapses while the first refresh is still in flight; the
        // queued signal must be retained, not silently coalesced into the
        // stale in-flight run.
        async.elapse(_cooldown);
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );
        messagesCompleter.complete(
          ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );

        // Once the next window elapses, the retained signal produces the
        // trailing refresh against fresh data.
        async.elapse(_cooldown * 2);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("the trailing refresh runs as soon as a slow refresh completes, not a window later", () {
      fakeAsync((FakeAsync async) {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) => messagesCompleter.future);

        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        // The minimum interval elapses while the first refresh is still in
        // flight.
        async.elapse(_cooldown);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // When the slow refresh finally completes, the queued trailing refresh
        // must start right away rather than waiting out another full cooldown
        // window.
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );
        messagesCompleter.complete(
          ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("the queue is held while hidden and consumed by the resume refresh", () {
      fakeAsync((FakeAsync async) {
        final lifecycle = FakeLifecycleSource();
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: lifecycle,
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // Backgrounding cancels the cooldown: the queued trailing refresh must
        // not spend the radio while the app is hidden.
        lifecycle.emitState(LifecycleState.paused);
        async.elapse(_cooldown * 3);
        verifyNever(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        );

        // The resume bypass refresh consumes the held signal...
        lifecycle.emitState(LifecycleState.resumed);
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // ...so nothing further fires afterwards.
        async.elapse(_cooldown * 3);
        verifyNever(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        );

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("a failed resume refresh preserves hidden staleness until a snapshot succeeds", () {
      fakeAsync((FakeAsync async) {
        final lifecycle = FakeLifecycleSource();
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: lifecycle,
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );
        var messageLoads = 0;
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) async {
          messageLoads++;
          if (messageLoads == 1) {
            return ApiResponse.error(ApiError.generic());
          }
          return ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null));
        });

        lifecycle.emitState(LifecycleState.paused);
        mockConnectionService.emitDataMayBeStale();
        async.elapse(_cooldown * 2);
        expect(messageLoads, 0);

        lifecycle.emitState(LifecycleState.resumed);
        async.elapse(Duration.zero);
        expect(messageLoads, 1);

        // The cooldown elapses and the preserved staleness retries.
        async.elapse(_cooldown);
        expect(messageLoads, 2);

        // The successful retry consumed the signal; later windows stay quiet.
        async.elapse(_cooldown * 2);
        expect(messageLoads, 2);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });

    test("a signal queued behind an in-flight refresh survives a pause/resume cycle", () {
      fakeAsync((FakeAsync async) {
        final lifecycle = FakeLifecycleSource();
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          projectViewingService: stubbedProjectViewingService(),
          lifecycleSource: lifecycle,
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
          eventRefreshMinInterval: _cooldown,
        );

        _settleLoaded(async: async, cubit: cubit);
        reset(mockSessionService);
        _stubLoadApis(mockSessionService, sessionId: sessionId);
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
        );

        final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer((_) => messagesCompleter.future);

        // Refresh A starts and stays in flight; a second signal queues.
        mockConnectionService.emitDataMayBeStale();
        mockConnectionService.emitDataMayBeStale();
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        // Pause cancels the cooldown (the only armed trailing trigger); the
        // resume bypass finds A still in flight and cannot start a refresh.
        lifecycle.emitState(LifecycleState.paused);
        lifecycle.emitState(LifecycleState.resumed);
        async.elapse(Duration.zero);

        // When A finally completes, the queued signal must still produce the
        // trailing refresh instead of being stranded.
        when(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );
        messagesCompleter.complete(
          ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
        );
        async.elapse(Duration.zero);
        verify(
          () => mockSessionService.getMessages(
            sessionId: any(named: "sessionId"),
            limit: any(named: "limit"),
            before: any(named: "before"),
          ),
        ).called(1);

        _completeCleanup(async: async, futures: [cubit.close()]);
      });
    });
  });
}

void _stubLoadApis(MockSessionRepository service, {required String sessionId}) {
  when(
    () => service.getMessages(
      sessionId: any(named: "sessionId"),
      limit: any(named: "limit"),
      before: any(named: "before"),
    ),
  ).thenAnswer(
    (_) => Future<ApiResponse<MessageWithPartsResponse>>.value(
      ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()], nextCursor: null)),
    ),
  );
  when(
    () => service.getPendingQuestions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<PendingQuestionResponse>>.value(
      ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])),
    ),
  );
  when(
    () => service.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<PendingPermissionResponse>>.value(
      ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])),
    ),
  );
  when(
    () => service.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<SessionListResponse>>.value(
      ApiResponse.success(const SessionListResponse(items: <Session>[])),
    ),
  );
  when(
    () => service.getSessionStatuses(),
  ).thenAnswer(
    (_) => Future<ApiResponse<SessionStatusResponse>>.value(
      ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
    ),
  );
  when(
    () => service.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) => Future<ApiResponse<Agents>>.value(ApiResponse.success(Agents(agents: _agents()))),
  );
  when(
    () => service.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) => Future<ApiResponse<ProviderListResponse>>.value(ApiResponse.success(_providers())),
  );
}

MessageWithParts _messageWithParts({String messageId = "msg-1"}) {
  return MessageWithParts(
    info: Message.assistant(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
      time: null,
    ),
    parts: const [],
  );
}

List<AgentInfo> _agents() {
  return const [
    AgentInfo(name: "coder", description: "A coding assistant", model: null, mode: AgentMode.primary),
    AgentInfo(name: "oracle", description: "Answers questions", model: null, mode: AgentMode.primary),
    AgentInfo(name: "Plan", description: "Plans before editing", model: null, mode: AgentMode.primary),
  ];
}

ProviderListResponse _providers() {
  return const ProviderListResponse(
    connectedOnly: false,
    items: [
      ProviderInfo(
        id: "anthropic",
        name: "Anthropic",
        defaultModelID: "claude-3-5-sonnet",
        models: {
          "claude-3-5-sonnet": ProviderModel(
            id: "claude-3-5-sonnet",
            providerID: "anthropic",
            name: "Claude 3.5 Sonnet",
            variants: [],
            family: null,
            releaseDate: null,
          ),
        },
      ),
    ],
  );
}

void _settleLoaded({required FakeAsync async, required SessionDetailCubit cubit}) {
  async.elapse(Duration.zero);
  expect(
    cubit.state,
    isA<SessionDetailLoaded>(),
    reason: "initial load should settle synchronously under fake time",
  );
}

void _completeCleanup({required FakeAsync async, required List<Future<void>> futures}) {
  var completed = false;
  unawaited(Future.wait(futures).then((_) => completed = true));
  async.flushMicrotasks();
  expect(completed, isTrue, reason: "fake-time cleanup should complete");
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded,
    description: "SessionDetailLoaded",
  );
}

Future<void> _awaitFailed(SessionDetailCubit cubit) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailFailed,
    description: "SessionDetailFailed",
  );
}
