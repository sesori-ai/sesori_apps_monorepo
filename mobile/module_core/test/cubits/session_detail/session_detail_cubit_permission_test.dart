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
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/agent_variant_options_builder.dart";
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
    health: HealthResponse(healthy: true, version: "0.1.200", serverManaged: false, serverState: null),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  group("SessionDetailCubit permission handling", () {
    late MockSessionService mockSessionService;
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late MockFailureReporter mockFailureReporter;
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
      mockFailureReporter = MockFailureReporter();
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
          category: any(named: "category"),
        ),
      ).thenReturn(null);
      when(
        () => mockFailureReporter.recordFailure(
          error: any(named: "error"),
          stackTrace: any(named: "stackTrace"),
          uniqueIdentifier: any(named: "uniqueIdentifier"),
          fatal: any(named: "fatal"),
          reason: any(named: "reason"),
          information: any(named: "information"),
        ),
      ).thenAnswer((_) async {});
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

      _stubLoadApis(mockSessionService, sessionId: sessionId);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    test("permission event adds to state and fires stream", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      const permission = SesoriPermissionAsked(
        requestID: "perm-123",
        sessionID: sessionId,
        tool: "fs_write",
        description: "Allow writing file",
      );

      final seenPermissions = <SesoriPermissionAsked>[];
      final sub = cubit.permissionStream.listen(seenPermissions.add);
      addTearDown(sub.cancel);

      sessionEvents.add(permission);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.pendingPermissions, [permission]);
      expect(seenPermissions, [permission]);
    });

    test("duplicate permission IDs are ignored", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      const permission = SesoriPermissionAsked(
        requestID: "perm-123",
        sessionID: sessionId,
        tool: "fs_write",
        description: "Allow writing file",
      );

      sessionEvents.add(permission);
      sessionEvents.add(permission);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.pendingPermissions, hasLength(1));
      expect(loaded.pendingPermissions.single.requestID, "perm-123");
    });

    test("replyToPermission optimistically removes and calls repository", () async {
      final completer = Completer<ApiResponse<void>>();
      when(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = _buildCubit(
        sessionId: sessionId,
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      sessionEvents.add(
        const SesoriPermissionAsked(
          requestID: "perm-123",
          sessionID: "ses-456",
          tool: "fs_write",
          description: "Allow writing file",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final resultFuture = cubit.replyToPermission(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      expect((cubit.state as SessionDetailLoaded).pendingPermissions, isEmpty);
      verify(
        () => mockPermissionRepository.replyToPermission(
          requestId: "perm-123",
          sessionId: "ses-456",
          reply: PermissionReply.once,
        ),
      ).called(1);
      verify(
        () => mockNotificationCanceller.cancelForSession(
          sessionId: "ses-456",
          category: NotificationCategory.aiInteraction,
        ),
      ).called(1);

      completer.complete(ApiResponse<void>.success(null));

      expect(await resultFuture, isTrue);
    });

    test("replyToPermission handles API failure", () async {
      when(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      ).thenThrow(Exception("boom"));

      final cubit = _buildCubit(
        sessionId: sessionId,
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      clearInteractions(mockSessionService);

      sessionEvents.add(
        const SesoriPermissionAsked(
          requestID: "perm-123",
          sessionID: "ses-456",
          tool: "fs_write",
          description: "Allow writing file",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final result = await cubit.replyToPermission(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      expect(result, isFalse);
      verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents()).called(1);
      verify(() => mockSessionService.listProviders()).called(1);
    });

    test("non-loaded state ignores permission events", () async {
      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(() => mockSessionService.getMessages(sessionId: sessionId)).thenAnswer((_) => messagesCompleter.future);

      final cubit = _buildCubit(
        sessionId: sessionId,
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);

      sessionEvents.add(
        const SesoriPermissionAsked(
          requestID: "perm-123",
          sessionID: sessionId,
          tool: "fs_write",
          description: "Allow writing file",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state, const SessionDetailState.loading());

      messagesCompleter.complete(ApiResponse.success(MessageWithPartsResponse(messages: [_messageWithParts()])));
      await _awaitLoaded(cubit);

      expect((cubit.state as SessionDetailLoaded).pendingPermissions, isEmpty);
    });
  });
}

SessionDetailCubit _buildCubit({
  required String sessionId,
  required MockConnectionService connectionService,
  required SessionDetailLoadService loadService,
  required SessionRepository promptDispatcher,
  required MockNotificationCanceller notificationCanceller,
  required MockPermissionRepository permissionRepository,
  required MockFailureReporter failureReporter,
}) {
  return SessionDetailCubit(
    connectionService,
    loadService: loadService,
    promptDispatcher: promptDispatcher,
    permissionRepository: permissionRepository,
    variantOptionsBuilder: const AgentVariantOptionsBuilder(),
    sessionId: sessionId,
    notificationCanceller: notificationCanceller,
    failureReporter: failureReporter,
  );
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
    () => service.getPendingPermissions(),
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
  when(() => service.listAgents()).thenAnswer(
    (_) => Future<ApiResponse<Agents>>.value(ApiResponse.success(Agents(agents: _agents()))),
  );
  when(() => service.listProviders()).thenAnswer(
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
    ),
    parts: const [],
  );
}

List<AgentInfo> _agents() {
  return const [
    AgentInfo(name: "coder", description: "A coding assistant", model: null, variant: null, mode: AgentMode.primary),
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
