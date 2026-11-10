import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_dart_core/src/services/session_approval_service.dart";
import "package:sesori_dart_core/src/services/session_auto_continuation_service.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_dart_core/src/services/session_interaction_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const _sessionId = "session-1";

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  test("disconnected startup reaches loaded automatically once connection becomes available", () async {
    final mockSourceRepository = MockSessionRepository();
    final mockSessionApi = MockSessionApi();
    final mockSessionRepository = MockSessionRepository();
    final mockConnectionService = MockConnectionService();
    final mockNotificationCanceller = MockNotificationCanceller();
    final mockPermissionRepository = MockPermissionRepository();
    final loadService = SessionDetailLoadService(
      repository: mockSessionRepository,
      pluginRepository: stubbedPluginRepository(),
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
    ).thenAnswer((_) async {});
    when(
      () => mockPermissionRepository.replyToPermission(
        requestId: any(named: "requestId"),
        sessionId: any(named: "sessionId"),
        reply: any(named: "reply"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    delegateSessionRepository(
      repository: mockSessionRepository,
      source: mockSourceRepository,
      optionsSource: mockSessionApi,
    );
    stubSessionRepositoryGetSession(repository: mockSessionRepository, sessionId: _sessionId);
    _stubLoadApis(mockSourceRepository, optionsApi: mockSessionApi);

    final cubit = SessionDetailCubit(
      mockConnectionService,
      pluginManagementService: stubbedPluginManagementService(),
      interactionCalculator: const SessionInteractionCalculator(),
      loadService: loadService,
      sessionAbortService: SessionAbortService(repository: promptDispatcher),
      autoContinuationService: SessionAutoContinuationService(repository: promptDispatcher),
      approvalService: SessionApprovalService(repository: promptDispatcher),
      promptDispatcher: promptDispatcher,
      permissionRepository: mockPermissionRepository,
      sessionViewingService: stubbedSessionViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      fileReferenceOpenService: MockFileReferenceOpenService(),
      window: idleSessionWindow(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);

    expect(cubit.state, const SessionDetailState.loading(launchHandoff: null, seededComposer: null));

    connectionStatus.add(connectedStatus);
    await _awaitLoaded(cubit);

    expect(cubit.state, isA<SessionDetailLoaded>());
    verify(
      () => mockSourceRepository.getMessages(
        sessionId: _sessionId,
        limit: any(named: "limit"),
        before: any(named: "before"),
        storedOnly: any(named: "storedOnly"),
      ),
    ).called(1);
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
    ).thenAnswer((_) async {});
    when(
      () => mockPermissionRepository.replyToPermission(
        requestId: any(named: "requestId"),
        sessionId: any(named: "sessionId"),
        reply: any(named: "reply"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(
      () => mockLoadService.load(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => const SessionDetailLoadResult.waitingForConnection(),
    );
    when(
      () => mockLoadService.reload(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(
      (_) async => const SessionDetailLoadResult.loaded(
        snapshot: SessionDetailSnapshot(
          areOptionsStale: false,
          bridgeQueuedPrompts: [],
          pluginId: "opencode",
          supportsPromptAttachments: false,
          supportsFileUploads: false,
          offersSessionMcp: true,
          messages: <MessageWithParts>[],
          olderMessagesCursor: null,
          userMessagesBefore: null,
          awaitingHarnessSync: false,
          pendingQuestions: <PendingQuestion>[],
          pendingPermissions: <PendingPermission>[],
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
        ),
      ),
    );

    final cubit = SessionDetailCubit(
      mockConnectionService,
      pluginManagementService: stubbedPluginManagementService(),
      interactionCalculator: const SessionInteractionCalculator(),
      loadService: mockLoadService,
      sessionAbortService: SessionAbortService(repository: mockSessionRepository),
      autoContinuationService: SessionAutoContinuationService(repository: mockSessionRepository),
      approvalService: SessionApprovalService(repository: mockSessionRepository),
      promptDispatcher: mockSessionRepository,
      permissionRepository: mockPermissionRepository,
      sessionViewingService: stubbedSessionViewingService(),
      lifecycleSource: FakeLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: stubbedProductAnalyticsService(),
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      fileReferenceOpenService: MockFileReferenceOpenService(),
      window: idleSessionWindow(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);

    await _awaitLoaded(cubit);

    verify(
      () => mockLoadService.load(
        session: any(named: "session"),
        projectId: "project-1",
      ),
    ).called(1);
    verify(
      () => mockLoadService.reload(
        session: any(named: "session"),
        projectId: "project-1",
      ),
    ).called(1);
    expect(cubit.state, isA<SessionDetailLoaded>());
  });

  test("a load that timed out while connected reloads once after the next reconnect", () async {
    final mockLoadService = MockSessionDetailLoadService();
    final mockSessionRepository = MockSessionRepository();
    final mockConnectionService = MockConnectionService();
    final mockNotificationCanceller = MockNotificationCanceller();
    final sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
    final globalEvents = StreamController<SseEvent>.broadcast();
    final connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);

    addTearDown(sessionEvents.close);
    addTearDown(globalEvents.close);
    addTearDown(connectionStatus.close);

    when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
    when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);
    when(
      () => mockNotificationCanceller.cancelForSession(sessionId: any(named: "sessionId")),
    ).thenAnswer((_) async {});
    var metadataCalls = 0;
    when(() => mockLoadService.loadMetadata(sessionId: any(named: "sessionId"))).thenAnswer((_) async {
      metadataCalls++;
      if (metadataCalls == 1) {
        return SessionDetailMetadataLoadResult.failed(
          error: ApiError.dartHttpClient(
            TimeoutException("Relay request timed out: POST /session/detail", const Duration(seconds: 30)),
          ),
          stackTrace: StackTrace.current,
        );
      }
      return SessionDetailMetadataLoadResult.found(session: testSession(id: _sessionId));
    });
    when(
      () => mockLoadService.reload(
        session: any(named: "session"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer((_) async => const SessionDetailLoadResult.loaded(snapshot: _emptySnapshot));

    final cubit = SessionDetailCubit(
      mockConnectionService,
      pluginManagementService: stubbedPluginManagementService(),
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
      feedbackPromptService: FakeFeedbackPromptService(),
      sessionId: _sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
      bridgeSettingsService: stubbedBridgeSettingsService(),
      sseEventTracker: MockSseEventTracker(),
      fileReferenceOpenService: MockFileReferenceOpenService(),
      window: idleSessionWindow(),
      sessionLaunchService: inMemorySessionLaunchService(launchRepository: inMemorySessionLaunchRepository()),
    );
    addTearDown(cubit.close);

    await awaitState(
      cubit: cubit,
      predicate: (state) => state is SessionDetailFailed,
      description: "SessionDetailFailed",
    );

    // A status emission that is not a reconnect leaves the failure for Retry.
    connectionStatus.add(connectedStatus);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<SessionDetailFailed>());
    expect(metadataCalls, 1);

    connectionStatus.add(const ConnectionStatus.disconnected());
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<SessionDetailFailed>());
    expect(metadataCalls, 1);

    connectionStatus.add(connectedStatus);
    await _awaitLoaded(cubit);

    expect(metadataCalls, 2);
    verify(
      () => mockLoadService.reload(
        session: any(named: "session"),
        projectId: "project-1",
      ),
    ).called(1);
  });
}

const _emptySnapshot = SessionDetailSnapshot(
  areOptionsStale: false,
  bridgeQueuedPrompts: [],
  pluginId: "opencode",
  supportsPromptAttachments: false,
  supportsFileUploads: false,
  offersSessionMcp: true,
  messages: <MessageWithParts>[],
  olderMessagesCursor: null,
  userMessagesBefore: null,
  awaitingHarnessSync: false,
  pendingQuestions: <PendingQuestion>[],
  pendingPermissions: <PendingPermission>[],
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
);

void _stubLoadApis(MockSessionRepository sourceRepository, {required MockSessionApi optionsApi}) {
  when(
    () => sourceRepository.getMessages(
      sessionId: _sessionId,
      limit: any(named: "limit"),
      before: any(named: "before"),
      storedOnly: any(named: "storedOnly"),
    ),
  ).thenAnswer(
    (_) async => ApiResponse.success(
      MessageWithPartsResponse(
        messages: [_messageWithParts()],
        nextCursor: null,
        userMessagesBefore: null,
        replayedPromptDefaults: null,
        cannotContinueMessage: null,
      ),
    ),
  );
  when(
    () => sourceRepository.getPendingQuestions(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(const PendingQuestionResponse(data: <PendingQuestion>[])));
  when(
    () => sourceRepository.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer((_) async => ApiResponse.success(const PendingPermissionResponse(data: <PendingPermission>[])));
  when(
    () => sourceRepository.getChildren(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
  when(() => sourceRepository.getSessionStatuses()).thenAnswer(
    (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
  );
  when(
    () => optionsApi.listAgents(
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
    () => optionsApi.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) async => ApiResponse.success(
      const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[]),
    ),
  );
  when(() => optionsApi.listCommands(projectId: "project-1", pluginId: "plugin-1")).thenAnswer(
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
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded,
    description: "SessionDetailLoaded",
  );
}
