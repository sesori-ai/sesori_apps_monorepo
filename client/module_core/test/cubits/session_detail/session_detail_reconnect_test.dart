import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationCanceller extends Mock implements NotificationCanceller {}

class MockPermissionRepository extends Mock implements PermissionRepository {}

class MockSessionDetailLoadService extends Mock implements SessionDetailLoadService {}

const _sessionId = "session-1";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  test("disconnected startup reaches loaded automatically once connection becomes available", () async {
    final mockSessionService = MockSessionService();
    final mockSessionRepository = MockSessionRepository();
    final mockProjectRepository = MockProjectRepository();
    final mockConnectionService = MockConnectionService();
    final mockNotificationCanceller = MockNotificationCanceller();
    final mockPermissionRepository = MockPermissionRepository();
    final loadService = SessionDetailLoadService(
      repository: mockSessionRepository,
      projectRepository: mockProjectRepository,
      connectionService: mockConnectionService,
    );
    final promptDispatcher = mockSessionRepository;
    final sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    final globalEvents = StreamController<SseEvent>.broadcast();
    final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());

    addTearDown(sessionEvents.close);
    addTearDown(globalEvents.close);
    addTearDown(connectionStatus.close);

    when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
    when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
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
    ).thenAnswer((_) async => ApiResponse.success(null));
    delegateSessionRepositoryToService(repository: mockSessionRepository, service: mockSessionService);
    stubSessionRepositoryGetSession(repository: mockSessionRepository, sessionId: _sessionId);
    when(() => mockProjectRepository.findSessionContext(sessionId: _sessionId)).thenAnswer(
      (_) async => const ProjectSessionContext(
        projectId: "project-1",
        pluginId: "plugin-1",
        sessionTitle: null,
      ),
    );
    _stubLoadApis(mockSessionService);

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
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
    );
    addTearDown(cubit.close);

    expect(cubit.state, const SessionDetailState.loading());

    connectionStatus.add(connectedStatus);
    await _awaitLoaded(cubit);

    expect(cubit.state, isA<SessionDetailLoaded>());
    verify(() => mockSessionService.getMessages(sessionId: _sessionId)).called(1);
  });

  test("reloads immediately when waiting result arrives after connection already recovered", () async {
    final mockLoadService = MockSessionDetailLoadService();
    final mockSessionRepository = MockSessionRepository();
    final mockConnectionService = MockConnectionService();
    final mockNotificationCanceller = MockNotificationCanceller();
    final mockPermissionRepository = MockPermissionRepository();
    final sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    final globalEvents = StreamController<SseEvent>.broadcast();
    final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    final projectViewingService = stubbedProjectViewingService();

    addTearDown(sessionEvents.close);
    addTearDown(globalEvents.close);
    addTearDown(connectionStatus.close);

    when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
    when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
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
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => mockLoadService.load(
        sessionId: _sessionId,
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => const SessionDetailLoadResult.waitingForConnection(),
    );
    when(
      () => mockLoadService.reload(
        sessionId: _sessionId,
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => const SessionDetailLoadResult.loaded(
        snapshot: SessionDetailSnapshot(
          projectId: "project-1",
          pluginId: "opencode",
          messages: <MessageWithParts>[],
          pendingQuestions: <PendingQuestion>[],
          pendingPermissions: <PendingPermission>[],
          childSessions: <Session>[],
          statuses: <String, SessionStatus>{},
          agents: <AgentInfo?>[],
          providerData: null,
          commands: <CommandInfo>[],
          canonicalSessionTitle: null,
          promptDefaults: null,
          isRootSession: true,
          isArchived: false,
        ),
        isBridgeConnected: true,
      ),
    );

    final cubit = SessionDetailCubit(
      mockConnectionService,
      loadService: mockLoadService,
      promptDispatcher: mockSessionRepository,
      permissionRepository: mockPermissionRepository,
      sessionViewingService: stubbedSessionViewingService(),
      projectViewingService: projectViewingService,
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
    );
    addTearDown(cubit.close);

    await _awaitLoaded(cubit);

    verify(() => mockLoadService.load(sessionId: _sessionId, projectId: "project-1")).called(1);
    verify(() => mockLoadService.reload(sessionId: _sessionId, projectId: "project-1")).called(1);
    verify(
      () => projectViewingService.markClaimFailed(claim: any(named: "claim")),
    ).called(1);
    expect(cubit.state, isA<SessionDetailLoaded>());
  });

  test("redirects matching sessions.updated bursts to command-only refreshes", () async {
    final mockLoadService = MockSessionDetailLoadService();
    final mockSessionRepository = MockSessionRepository();
    final mockConnectionService = MockConnectionService();
    final mockNotificationCanceller = MockNotificationCanceller();
    final mockPermissionRepository = MockPermissionRepository();
    final sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    final globalEvents = StreamController<SseEvent>.broadcast();
    final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    final commandRefresh = Completer<SessionCommandCatalogLoadResult>();
    var commandReloadCount = 0;
    final initialCommand = testCommandInfo(name: "review", template: "/review-old");
    final firstRefreshedCommand = testCommandInfo(name: "review", template: "/review-current");
    final trailingCommand = testCommandInfo(name: "review", template: "/review-latest");

    addTearDown(sessionEvents.close);
    addTearDown(globalEvents.close);
    addTearDown(connectionStatus.close);

    when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
    when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
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
    ).thenAnswer((_) async => ApiResponse.success(null));

    final loadedResult = SessionDetailLoadResult.loaded(
      snapshot: SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "opencode",
        messages: [_messageWithParts()],
        pendingQuestions: const <PendingQuestion>[],
        pendingPermissions: const <PendingPermission>[],
        childSessions: const <Session>[],
        statuses: const <String, SessionStatus>{},
        agents: const <AgentInfo?>[],
        providerData: null,
        commands: [initialCommand],
        canonicalSessionTitle: "Detail title",
        promptDefaults: null,
        isRootSession: true,
        isArchived: true,
      ),
      isBridgeConnected: true,
    );

    when(
      () => mockLoadService.load(
        sessionId: _sessionId,
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => loadedResult,
    );
    when(
      () => mockLoadService.reloadCommands(
        projectId: "project-1",
        pluginId: "opencode",
      ),
    ).thenAnswer((_) {
      commandReloadCount++;
      if (commandReloadCount == 1) return commandRefresh.future;
      return Future.value(SessionCommandCatalogLoadResult.loaded(commands: [trailingCommand]));
    });

    final cubit = SessionDetailCubit(
      mockConnectionService,
      loadService: mockLoadService,
      promptDispatcher: mockSessionRepository,
      permissionRepository: mockPermissionRepository,
      sessionViewingService: stubbedSessionViewingService(),
      projectViewingService: stubbedProjectViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
      eventRefreshMinInterval: const Duration(milliseconds: 10),
    );
    addTearDown(cubit.close);

    await _awaitLoaded(cubit);
    verify(() => mockLoadService.load(sessionId: _sessionId, projectId: "project-1")).called(1);
    cubit.stageCommand(initialCommand);
    final before = cubit.state as SessionDetailLoaded;

    globalEvents.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "project-2")));
    await pumpEventQueue();

    verifyNever(
      () => mockLoadService.reload(
        sessionId: _sessionId,
        projectId: any(named: "projectId"),
      ),
    );
    verifyNever(
      () => mockLoadService.reloadCommands(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    );

    for (var i = 0; i < 3; i++) {
      globalEvents.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "project-1")));
    }
    await pumpEventQueue();

    expect(commandReloadCount, 1);
    final duringRefresh = cubit.state as SessionDetailLoaded;
    expect(duringRefresh.isRefreshing, isFalse);
    expect(duringRefresh.messages, before.messages);

    commandRefresh.complete(
      SessionCommandCatalogLoadResult.loaded(commands: [firstRefreshedCommand]),
    );
    for (var i = 0; i < 100 && commandReloadCount < 2; i++) {
      await pumpEventQueue();
    }

    expect(commandReloadCount, 2);
    final refreshed = cubit.state as SessionDetailLoaded;
    expect(refreshed.availableCommands, [trailingCommand]);
    expect(refreshed.stagedCommand, trailingCommand);
    expect(refreshed.messages, before.messages);
    verifyNever(
      () => mockLoadService.reload(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    );

    final error = StateError("command refresh sentinel");
    final recoveredCommand = testCommandInfo(name: "review", template: "/review-recovered");
    var recoveryAttempts = 0;
    when(
      () => mockLoadService.reloadCommands(
        projectId: "project-1",
        pluginId: "opencode",
      ),
    ).thenAnswer((_) async {
      recoveryAttempts++;
      if (recoveryAttempts == 1) {
        return SessionCommandCatalogLoadResult.failed(
          error: error,
          stackTrace: StackTrace.current,
        );
      }
      return SessionCommandCatalogLoadResult.loaded(commands: [recoveredCommand]);
    });
    globalEvents.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "project-1")));
    await pumpEventQueue();

    final afterFailure = cubit.state as SessionDetailLoaded;
    expect(afterFailure.availableCommands, [trailingCommand]);
    expect(afterFailure.stagedCommand, trailingCommand);

    for (var i = 0; i < 100 && recoveryAttempts < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(recoveryAttempts, 2);
    expect((cubit.state as SessionDetailLoaded).availableCommands, [recoveredCommand]);

    final staleTargetedRefresh = Completer<SessionCommandCatalogLoadResult>();
    when(
      () => mockLoadService.reloadCommands(
        projectId: "project-1",
        pluginId: "opencode",
      ),
    ).thenAnswer((_) => staleTargetedRefresh.future);
    when(
      () => mockLoadService.reload(
        sessionId: _sessionId,
        projectId: "project-1",
      ),
    ).thenAnswer((_) async => loadedResult);
    globalEvents.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "project-1")));
    await pumpEventQueue();

    await cubit.reload();
    expect((cubit.state as SessionDetailLoaded).availableCommands, [initialCommand]);

    staleTargetedRefresh.complete(
      SessionCommandCatalogLoadResult.loaded(commands: [trailingCommand]),
    );
    await pumpEventQueue();
    expect((cubit.state as SessionDetailLoaded).availableCommands, [initialCommand]);
  });
}

void _stubLoadApis(MockSessionService service) {
  when(
    () => service.getMessages(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()])));
  when(
    () => service.getPendingQuestions(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
  when(
    () => service.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer((_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])));
  when(
    () => service.getChildren(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
  when(() => service.getSessionStatuses()).thenAnswer(
    (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
  );
  when(
    () => service.listAgents(
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
    () => service.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) async => ApiResponse.success(
      const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[]),
    ),
  );
  when(() => service.listCommands(projectId: "project-1", pluginId: "plugin-1")).thenAnswer(
    (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
  );
}

MessageWithParts _messageWithParts() {
  return const MessageWithParts(
    info: Message.assistant(
      id: "msg-1",
      sessionID: _sessionId,
      agent: null,
      modelID: null,
      providerID: null,
      time: null,
    ),
    parts: <MessagePart>[],
  );
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  for (var i = 0; i < 100; i++) {
    if (cubit.state is SessionDetailLoaded) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail("Timed out waiting for SessionDetailLoaded; current state: ${cubit.state}");
}
