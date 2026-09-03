import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  const sessionId = "session-1";
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  group("SessionDetailCubit permission handling", () {
    late MockSessionRepository mockSessionService;
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
      mockSessionService = MockSessionRepository();
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      mockFailureReporter = MockFailureReporter();
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

    test("permission event adds to state and fires stream", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
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
        displaySessionId: null,
        tool: "fs_write",
        description: "Allow writing file",
      );

      final permissionSeen = Completer<void>();
      final seenPermissions = <SesoriPermissionAsked>[];
      final sub = cubit.permissionStream.listen((permission) {
        seenPermissions.add(permission);
        permissionSeen.complete();
      });
      addTearDown(sub.cancel);

      sessionEvents.add(permission);
      await permissionSeen.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail("Timed out waiting for permission stream delivery"),
      );

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.pendingPermissions, [permission]);
      expect(seenPermissions, [permission]);
    });

    test("duplicate permission IDs are ignored", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
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
        displaySessionId: null,
        tool: "fs_write",
        description: "Allow writing file",
      );

      sessionEvents.add(permission);
      sessionEvents.add(permission);
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.pendingPermissions.isNotEmpty,
        description: "permission added",
      );

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
        projectId: "project-1",
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
          displaySessionId: null,
          tool: "fs_write",
          description: "Allow writing file",
        ),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.pendingPermissions.isNotEmpty,
        description: "permission added",
      );

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
        () => mockNotificationCanceller.cancelForSession(sessionId: "ses-456"),
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
        projectId: "project-1",
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
          displaySessionId: null,
          tool: "fs_write",
          description: "Allow writing file",
        ),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.pendingPermissions.isNotEmpty,
        description: "permission added",
      );

      final result = await cubit.replyToPermission(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      expect(result, isFalse);
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
    });

    test("replyToPermission rejects a non-throwing error response without reporting success", () async {
      when(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.error(ApiError.generic()));
      final analyticsService = stubbedProductAnalyticsService();
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
        productAnalyticsService: analyticsService,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      final success = await cubit.replyToPermission(
        requestId: "perm-123",
        sessionId: sessionId,
        reply: PermissionReply.always,
      );

      expect(success, isFalse);
      verifyNever(
        () => analyticsService.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    test("successful permission replies report only their bounded decisions", () async {
      final analyticsService = stubbedProductAnalyticsService();
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
        productAnalyticsService: analyticsService,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      for (final reply in PermissionReply.values) {
        expect(
          await cubit.replyToPermission(
            requestId: "perm-${reply.name}",
            sessionId: sessionId,
            reply: reply,
          ),
          isTrue,
        );
      }

      final events = verify(
        () => analyticsService.logEvent(
          event: captureAny(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).captured.cast<ProductAnalyticsEvent>();
      expect(events, [
        const ProductAnalyticsEvent.sessionPermissionAnswered(
          decision: AnalyticsPermissionDecision.once,
        ),
        const ProductAnalyticsEvent.sessionPermissionAnswered(
          decision: AnalyticsPermissionDecision.always,
        ),
        const ProductAnalyticsEvent.sessionPermissionAnswered(
          decision: AnalyticsPermissionDecision.reject,
        ),
      ]);
    });

    test("successful question controls and abort report content-free outcomes", () async {
      when(
        () => mockSessionService.replyToQuestion(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          answers: any(named: "answers"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));
      when(
        () => mockSessionService.rejectQuestion(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));
      when(
        () => mockSessionService.abortSession(
          sessionId: any(named: "sessionId"),
          subAgents: any(named: "subAgents"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));
      final analyticsService = stubbedProductAnalyticsService();
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
        productAnalyticsService: analyticsService,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      expect(
        await cubit.replyToQuestion(
          requestId: "question-1",
          sessionId: sessionId,
          answers: const <ReplyAnswer>[],
        ),
        isTrue,
      );
      expect(await cubit.rejectQuestion("question-2"), isTrue);
      await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

      final events = verify(
        () => analyticsService.logEvent(
          event: captureAny(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).captured.cast<ProductAnalyticsEvent>();
      expect(events, [
        const ProductAnalyticsEvent.sessionQuestionAnswered(),
        const ProductAnalyticsEvent.sessionQuestionRejected(),
        const ProductAnalyticsEvent.sessionAbortSucceeded(),
      ]);
    });

    test("non-loaded state buffers permission events and replays after loaded", () async {
      final messagesCompleter = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
        ),
      ).thenAnswer((_) => messagesCompleter.future);

      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);

      const permission = SesoriPermissionAsked(
        requestID: "perm-123",
        sessionID: sessionId,
        displaySessionId: null,
        tool: "fs_write",
        description: "Allow writing file",
      );
      sessionEvents.add(permission);
      await pumpEventQueue();

      expect(cubit.state, const SessionDetailState.loading());

      messagesCompleter.complete(
        ApiResponse.success(
          MessageWithPartsResponse(
            messages: [_messageWithParts()],
            nextCursor: null,
            replayedPromptDefaults: null,
          ),
        ),
      );
      await _awaitLoaded(cubit);

      // The buffered permission event should have been replayed after load
      expect((cubit.state as SessionDetailLoaded).pendingPermissions, [permission]);
    });

    test("child-session permission from initial load surfaces on the root", () async {
      when(() => mockSessionService.getPendingPermissions(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          const PendingPermissionResponse(
            data: [
              PendingPermission(
                id: "perm-child",
                sessionID: "child-1",
                displaySessionId: sessionId,
                tool: "bash",
                description: "Run ls",
                allowAlways: false,
              ),
            ],
          ),
        ),
      );

      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.pendingPermissions.map((p) => p.requestID), ["perm-child"]);
      expect(loaded.pendingPermissions.single.allowAlways, isFalse);
      expect(loaded.pendingPermissions.single.displaySessionId, sessionId);
    });

    test("child-session permission surfaces on the root via the global stream", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      const childPermission = SesoriPermissionAsked(
        requestID: "perm-child",
        sessionID: "child-1",
        displaySessionId: sessionId,
        tool: "bash",
        description: "Run ls",
      );

      final permissionSeen = Completer<void>();
      final seen = <SesoriPermissionAsked>[];
      final sub = cubit.permissionStream.listen((permission) {
        seen.add(permission);
        permissionSeen.complete();
      });
      addTearDown(sub.cancel);

      globalEvents.add(SseEvent(data: childPermission));
      await permissionSeen.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail("Timed out waiting for child permission stream delivery"),
      );

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.pendingPermissions, [childPermission]);
      expect(seen, [childPermission]);

      // Replied for the same child request removes it from the root view.
      globalEvents.add(
        SseEvent(
          data: const SesoriPermissionReplied(
            requestID: "perm-child",
            sessionID: "child-1",
            displaySessionId: sessionId,
            reply: "once",
          ),
        ),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.pendingPermissions.isEmpty,
        description: "permission removed",
      );
      expect((cubit.state as SessionDetailLoaded).pendingPermissions, isEmpty);
    });

    test("permission for an unrelated session is ignored on the global stream", () async {
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      globalEvents.add(
        SseEvent(
          data: const SesoriPermissionAsked(
            requestID: "perm-x",
            sessionID: "other-child",
            displaySessionId: "other-root",
            tool: "bash",
            description: "Run ls",
          ),
        ),
      );
      const relevantPermission = SesoriPermissionAsked(
        requestID: "perm-control",
        sessionID: "child-1",
        displaySessionId: sessionId,
        tool: "bash",
        description: "Run pwd",
      );
      globalEvents.add(SseEvent(data: relevantPermission));
      await awaitState(
        cubit: cubit,
        predicate: (state) =>
            state is SessionDetailLoaded &&
            state.pendingPermissions.any((permission) => permission.requestID == relevantPermission.requestID),
        description: "relevant permission processed after unrelated permission",
      );

      expect((cubit.state as SessionDetailLoaded).pendingPermissions, [relevantPermission]);
    });

    test("rejecting a surfaced child question targets the child (owner) session", () async {
      when(() => mockSessionService.getPendingQuestions(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          const PendingQuestionResponse(
            data: [
              PendingQuestion(
                id: "q-child",
                sessionID: "child-1",
                displaySessionId: sessionId,
                questions: [],
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.rejectQuestion(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
        ),
      ).thenAnswer((_) async => ApiResponse<void>.success(null));

      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      // The child question surfaced on the root.
      expect((cubit.state as SessionDetailLoaded).pendingQuestions.map((q) => q.id), ["q-child"]);

      final ok = await cubit.rejectQuestion("q-child");

      expect(ok, isTrue);
      // Reject targets the owning child session, not the open root.
      verify(() => mockSessionService.rejectQuestion(requestId: "q-child", sessionId: "child-1")).called(1);
    });

    test("archived sessions refuse prompts, permission replies, and question replies", () async {
      // Archiving is permanent, so the session is audit-only: the refusal lives
      // in the cubit, not in the widgets.
      stubSessionRepositoryGetSession(
        repository: mockSessionRepository,
        sessionId: sessionId,
        session: testSession(id: sessionId, archivedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000)),
      );
      final cubit = _buildCubit(
        sessionId: sessionId,
        projectId: "project-1",
        connectionService: mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        notificationCanceller: mockNotificationCanceller,
        permissionRepository: mockPermissionRepository,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      expect((cubit.state as SessionDetailLoaded).isArchived, isTrue);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect(
        await cubit.replyToPermission(requestId: "perm-1", sessionId: sessionId, reply: PermissionReply.once),
        isFalse,
      );
      expect(
        await cubit.replyToQuestion(requestId: "q-1", sessionId: sessionId, answers: const []),
        isFalse,
      );
      expect(await cubit.rejectQuestion("q-1"), isFalse);

      // Nothing reached the wire, and the refused prompt was not queued either.
      verifyNever(
        () => mockSessionRepository.sendMessage(
          promptId: any(named: "promptId"),
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      );
      verifyNever(
        () => mockPermissionRepository.replyToPermission(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          reply: any(named: "reply"),
        ),
      );
      verifyNever(
        () => mockSessionService.replyToQuestion(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
          answers: any(named: "answers"),
        ),
      );
      verifyNever(
        () => mockSessionService.rejectQuestion(
          requestId: any(named: "requestId"),
          sessionId: any(named: "sessionId"),
        ),
      );
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });
  });
}

SessionDetailCubit _buildCubit({
  required String sessionId,
  required String projectId,
  required MockConnectionService connectionService,
  required SessionDetailLoadService loadService,
  required SessionRepository promptDispatcher,
  required MockNotificationCanceller notificationCanceller,
  required MockPermissionRepository permissionRepository,
  required MockFailureReporter failureReporter,
  ProductAnalyticsService? productAnalyticsService,
}) {
  return SessionDetailCubit(
    connectionService,
    loadService: loadService,
    promptDispatcher: promptDispatcher,
    permissionRepository: permissionRepository,
    sessionViewingService: stubbedSessionViewingService(),
    projectViewingService: stubbedProjectViewingService(),
    lifecycleSource: FakeLifecycleSource(),
    composerDraftRepository: inMemoryComposerDraftRepository(),
    productAnalyticsService: productAnalyticsService ?? stubbedProductAnalyticsService(),
    sessionId: sessionId,
    projectId: projectId,
    notificationCanceller: notificationCanceller,
    failureReporter: failureReporter,
  );
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
      ApiResponse.success(
        MessageWithPartsResponse(
          messages: [_messageWithParts()],
          nextCursor: null,
          replayedPromptDefaults: null,
        ),
      ),
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
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded,
    description: "SessionDetailLoaded",
  );
}
