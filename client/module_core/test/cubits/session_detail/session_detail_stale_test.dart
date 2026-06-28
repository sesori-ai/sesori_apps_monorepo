import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationCanceller extends Mock implements NotificationCanceller {}

class MockPermissionRepository extends Mock implements PermissionRepository {}

void main() {
  const sessionId = "session-1";
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
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
    late MockSessionService mockSessionService;
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
      mockSessionService = MockSessionService();
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      mockProjectRepository = MockProjectRepository();
      loadService = SessionDetailLoadService(
        repository: mockSessionRepository,
        projectRepository: mockProjectRepository,
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
      delegateSessionRepositoryToService(repository: mockSessionRepository, service: mockSessionService);
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
        (_) async => const ProjectSessionContext(projectId: "test-project", sessionTitle: null),
      );
      when(() => mockSessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
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
          lifecycleSource: FakeLifecycleSource(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);
        clearInteractions(mockSessionService);

        connectionStatus.add(connectionLostStatus);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
          (_) async =>
              ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-refreshed")])),
        );

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitDataMayBeStale();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        verifyNever(() => mockSessionService.getMessages(sessionId: sessionId));
        verifyNever(() => mockSessionService.getPendingQuestions(sessionId: sessionId));
        verifyNever(() => mockSessionService.getChildren(sessionId: sessionId));
        verifyNever(() => mockSessionService.getSessionStatuses());
        verifyNever(() => mockSessionService.listAgents(projectId: any(named: "projectId")));
        verifyNever(() => mockSessionService.listProviders(projectId: any(named: "projectId")));

        connectionStatus.add(connectedStatus);
        await Future<void>.delayed(const Duration(milliseconds: 20));

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
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async =>
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-immediate")])),
      );

      final emitted = <SessionDetailState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents(projectId: any(named: "projectId"))).called(1);
      verify(() => mockSessionService.listProviders(projectId: any(named: "projectId"))).called(1);

      expect(emitted.first, isA<SessionDetailLoaded>().having((s) => s.isRefreshing, "isRefreshing", isTrue));
      expect(
        emitted.last,
        isA<SessionDetailLoaded>()
            .having((s) => s.isRefreshing, "isRefreshing", isFalse)
            .having((s) => s.messages.first.info.id, "updated message id", "msg-immediate"),
      );
    });

    test("silent refresh re-asserts the viewing session once fresh content renders", () async {
      final viewingService = stubbedSessionViewingService();
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      // Initial load declares the view exactly once.
      verify(() => viewingService.setViewingSession(sessionId)).called(1);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async =>
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-refreshed")])),
      );

      // A resume/reconnect-driven stale refresh while connected.
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // The refresh rendered fresh content, so the view is re-asserted.
      verify(() => viewingService.setViewingSession(sessionId)).called(1);
    });

    test("resume drives a refresh that re-asserts the viewing session", () async {
      final viewingService = stubbedSessionViewingService();
      final lifecycle = FakeLifecycleSource();
      addTearDown(lifecycle.close);
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: lifecycle,
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      verify(() => viewingService.setViewingSession(sessionId)).called(1);
      clearInteractions(mockSessionService);
      clearInteractions(viewingService);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async =>
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-resumed")])),
      );

      // A short background then resume WITHOUT any dataMayBeStale signal: the
      // cubit must still refresh and re-assert so the bridge has an active
      // viewer for subsequent in-view activity.
      lifecycle.emitState(LifecycleState.paused);
      lifecycle.emitState(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => viewingService.setViewingSession(sessionId)).called(1);
    });

    test("resume forces a fresh refresh rather than coalescing onto a pre-background one", () async {
      final viewingService = stubbedSessionViewingService();
      final lifecycle = FakeLifecycleSource();
      addTearDown(lifecycle.close);
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: lifecycle,
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);
      clearInteractions(viewingService);

      // Gate the first refresh's getMessages so it is still in flight when the
      // app backgrounds (simulating a refresh that began before backgrounding).
      final gate = Completer<void>();
      var firstGet = true;
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) async {
        if (firstGet) {
          firstGet = false;
          await gate.future;
        }
        return ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-resumed")]),
        );
      });

      // Start a refresh (in flight, gated).
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Background, then resume while the first refresh is still gated.
      lifecycle.emitState(LifecycleState.paused);
      lifecycle.emitState(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Release the first refresh; the forced post-resume refresh must run too.
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Two getMessages: the pre-background one and the forced post-resume one
      // (it did NOT coalesce onto the older request).
      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(2);
      // The view is re-asserted after the (fresh) refresh renders.
      verify(() => viewingService.setViewingSession(sessionId)).called(greaterThanOrEqualTo(1));
    });

    test("rapid resumes during an in-flight refresh do not start overlapping refreshes", () async {
      final viewingService = stubbedSessionViewingService();
      final lifecycle = FakeLifecycleSource();
      addTearDown(lifecycle.close);
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: lifecycle,
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      // Track concurrency of getMessages: it must never run two at once
      // (single-flight). Gate the first call so it stays in flight across the
      // rapid resume cycles.
      var concurrent = 0;
      var maxConcurrent = 0;
      final gate = Completer<void>();
      var firstGet = true;
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) async {
        concurrent++;
        if (concurrent > maxConcurrent) maxConcurrent = concurrent;
        try {
          if (firstGet) {
            firstGet = false;
            await gate.future;
          }
          return ApiResponse.success(
            MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-resumed")]),
          );
        } finally {
          concurrent--;
        }
      });

      // Start an in-flight refresh.
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Two rapid pause/resume cycles while the first refresh is gated.
      lifecycle.emitState(LifecycleState.paused);
      lifecycle.emitState(LifecycleState.resumed);
      lifecycle.emitState(LifecycleState.paused);
      lifecycle.emitState(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Never two refreshes at once.
      expect(maxConcurrent, equals(1));
      // The rapid resumes coalesce into a single appended forced refresh, so at
      // most the in-flight one plus one more ran.
      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(lessThanOrEqualTo(2));
    });

    test("foreground relay reconnect re-asserts the view without a stale signal", () async {
      final viewingService = stubbedSessionViewingService();
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);
      clearInteractions(viewingService);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async =>
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-reconnected")])),
      );

      // A foreground relay drop + reconnect: no lifecycle resume, no
      // dataMayBeStale. The bridge released the old viewer, so the cubit must
      // refresh and re-declare the view on the reconnect transition.
      connectionStatus.add(connectionLostStatus);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connectionStatus.add(connectedStatus);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => viewingService.setViewingSession(sessionId)).called(greaterThanOrEqualTo(1));
    });

    test("resume while disconnected forces a fresh refresh on reconnect", () async {
      final viewingService = stubbedSessionViewingService();
      final lifecycle = FakeLifecycleSource();
      addTearDown(lifecycle.close);
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: viewingService,
        lifecycleSource: lifecycle,
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);
      clearInteractions(viewingService);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async =>
            ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-resumed")])),
      );

      // Disconnect, background, resume — all while disconnected: the refresh is
      // deferred to the reconnect path.
      connectionStatus.add(connectionLostStatus);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      lifecycle.emitState(LifecycleState.paused);
      lifecycle.emitState(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      verifyNever(() => mockSessionService.getMessages(sessionId: sessionId));

      // Reconnect: the deferred resume refresh runs and re-asserts the view.
      connectionStatus.add(connectedStatus);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => viewingService.setViewingSession(sessionId)).called(greaterThanOrEqualTo(1));
    });

    test("silent refresh preserves selectedAgent and selectedAgentModel", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
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

      when(() => mockSessionService.listAgents(projectId: any(named: "projectId"))).thenAnswer(
        (_) async => ApiResponse.success(
          const Agents(
            agents: [
              AgentInfo(name: "build", description: "build", model: null, mode: AgentMode.primary),
            ],
          ),
        ),
      );
      when(() => mockSessionService.listProviders(projectId: any(named: "projectId"))).thenAnswer(
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
      await Future<void>.delayed(const Duration(milliseconds: 20));

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
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      cubit.selectVariant(const SessionVariant(id: "low"));

      await cubit.sendMessage(text: "hello", command: null);

      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: sessionId,
          text: "hello",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "low"),
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
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) => messagesCompleter.future);
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
        () => mockSessionService.listAgents(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: _agents())));
      when(
        () => mockSessionService.listProviders(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(_providers()));

      final emitted = <SessionDetailState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      sessionEvents.add(
        const SesoriMessagePartDelta(
          sessionID: sessionId,
          messageID: "msg-1",
          partID: "part-race",
          field: "text",
          delta: "delta-during-refresh",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      messagesCompleter.complete(
        ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-race")])),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final refreshed = emitted.last as SessionDetailLoaded;
      expect(refreshed.isRefreshing, isFalse);
      expect(refreshed.messages.first.info.id, "msg-race");
      expect(refreshed.streamingText, {"part-race": "delta-during-refresh"});
    });

    test("partial API failure: providers fail and refresh still succeeds with empty providers", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);

      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer(
        (_) async => ApiResponse.success(
          MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-provider-fallback")]),
        ),
      );
      when(
        () => mockSessionService.listProviders(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.isRefreshing, isFalse);
      expect(loaded.messages.first.info.id, "msg-provider-fallback");
      expect(loaded.availableProviders, isEmpty);
    });

    test("stale signal is ignored when state is SessionDetailLoading", () async {
      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) => messagesCompleter.future);

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );

      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId"))).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents(projectId: any(named: "projectId"))).called(1);
      verify(() => mockSessionService.listProviders(projectId: any(named: "projectId"))).called(1);

      messagesCompleter.complete(ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()])));
      await _awaitLoaded(cubit);
      await cubit.close();
    });

    test("stale signal is ignored when state is SessionDetailFailed", () async {
      when(
        () => mockSessionService.getMessages(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitFailed(cubit);
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      expect(cubit.state, isA<SessionDetailFailed>());
    });

    test(
      "silent refresh failure logs warning and resets isRefreshing to false without changing state",
      () async {
        final cubit = SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionViewingService: stubbedSessionViewingService(),
          lifecycleSource: FakeLifecycleSource(),
          sessionId: sessionId,
          projectId: "project-1",
          notificationCanceller: mockNotificationCanceller,
          failureReporter: MockFailureReporter(),
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);
        final before = cubit.state as SessionDetailLoaded;

        when(
          () => mockSessionService.getMessages(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitDataMayBeStale();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(emitted.length, 2);
        expect((emitted.first as SessionDetailLoaded).isRefreshing, isTrue);
        final afterFailure = emitted.last as SessionDetailLoaded;
        expect(afterFailure.isRefreshing, isFalse);
        expect(afterFailure.messages, before.messages);
        expect(afterFailure.selectedAgent, before.selectedAgent);
        expect(afterFailure.selectedAgentModel, before.selectedAgentModel);
      },
    );

    test("concurrent stale signals are coalesced (single API call)", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      reset(mockSessionService);

      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) => messagesCompleter.future);
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
        () => mockSessionService.listAgents(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(Agents(agents: _agents())));
      when(
        () => mockSessionService.listProviders(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(_providers()));
      when(() => mockSessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
        (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
      );

      mockConnectionService.emitDataMayBeStale();
      mockConnectionService.emitDataMayBeStale();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      messagesCompleter.complete(
        ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts(messageId: "msg-coalesced")])),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId"))).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents(projectId: any(named: "projectId"))).called(1);
      verify(() => mockSessionService.listProviders(projectId: any(named: "projectId"))).called(1);
    });
  });
}

void _stubLoadApis(MockSessionService service, {required String sessionId}) {
  when(
    () => service.getMessages(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<MessageWithPartsResponse>>.value(
      ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()])),
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
  when(() => service.listAgents(projectId: any(named: "projectId"))).thenAnswer(
    (_) => Future<ApiResponse<Agents>>.value(ApiResponse.success(Agents(agents: _agents()))),
  );
  when(() => service.listProviders(projectId: any(named: "projectId"))).thenAnswer(
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

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  for (var i = 0; i < 100; i++) {
    if (cubit.state is SessionDetailLoaded) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail("Timed out waiting for SessionDetailLoaded; current state: ${cubit.state}");
}

Future<void> _awaitFailed(SessionDetailCubit cubit) async {
  for (var i = 0; i < 100; i++) {
    if (cubit.state is SessionDetailFailed) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail("Timed out waiting for SessionDetailFailed");
}
