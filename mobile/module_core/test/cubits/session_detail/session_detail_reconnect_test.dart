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
    health: HealthResponse(healthy: true, version: "0.1.200"),
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
        category: any(named: "category"),
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
    when(() => mockProjectRepository.findSessionContext(sessionId: _sessionId)).thenAnswer(
      (_) async => const ProjectSessionContext(projectId: "project-1", sessionTitle: null),
    );
    _stubLoadApis(mockSessionService);

    final cubit = SessionDetailCubit(
      mockConnectionService,
      loadService: loadService,
      promptDispatcher: promptDispatcher,
      permissionRepository: mockPermissionRepository,
      sessionId: _sessionId,
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
        category: any(named: "category"),
      ),
    ).thenReturn(null);
    when(
      () => mockPermissionRepository.replyToPermission(
        requestId: any(named: "requestId"),
        sessionId: any(named: "sessionId"),
        reply: any(named: "reply"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    when(() => mockLoadService.load(sessionId: _sessionId)).thenAnswer(
      (_) async => const SessionDetailLoadResult.waitingForConnection(),
    );
    when(() => mockLoadService.reload(sessionId: _sessionId)).thenAnswer(
      (_) async => const SessionDetailLoadResult.loaded(
        snapshot: SessionDetailSnapshot(
          messages: const <MessageWithParts>[],
          pendingQuestions: const <PendingQuestion>[],
          childSessions: const <Session>[],
          statuses: const <String, SessionStatus>{},
          agents: const <AgentInfo?>[],
          providerData: null,
          commands: const <CommandInfo>[],
          canonicalSessionTitle: null,
        ),
        isBridgeConnected: true,
      ),
    );

    final cubit = SessionDetailCubit(
      mockConnectionService,
      loadService: mockLoadService,
      promptDispatcher: mockSessionRepository,
      permissionRepository: mockPermissionRepository,
      sessionId: _sessionId,
      notificationCanceller: mockNotificationCanceller,
      failureReporter: MockFailureReporter(),
    );
    addTearDown(cubit.close);

    await _awaitLoaded(cubit);

    verify(() => mockLoadService.load(sessionId: _sessionId)).called(1);
    verify(() => mockLoadService.reload(sessionId: _sessionId)).called(1);
    expect(cubit.state, isA<SessionDetailLoaded>());
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
    () => service.getChildren(sessionId: _sessionId),
  ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: <Session>[])));
  when(() => service.getSessionStatuses()).thenAnswer(
    (_) async => ApiResponse.success(const SessionStatusResponse(statuses: <String, SessionStatus>{})),
  );
  when(() => service.listAgents()).thenAnswer(
    (_) async => ApiResponse.success(
      const Agents(
        agents: [
          AgentInfo(name: "build", description: "build", model: null, variant: null, mode: AgentMode.primary),
        ],
      ),
    ),
  );
  when(() => service.listProviders()).thenAnswer(
    (_) async => ApiResponse.success(
      const ProviderListResponse(connectedOnly: false, items: <ProviderInfo>[]),
    ),
  );
  when(() => service.listCommands(projectId: "project-1")).thenAnswer(
    (_) async => ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
  );
}

MessageWithParts _messageWithParts() {
  return const MessageWithParts(
    info: Message(id: "msg-1", role: "assistant", sessionID: _sessionId, agent: null, modelID: null, providerID: null),
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
