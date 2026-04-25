import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

class MockPermissionRepository extends Mock implements PermissionRepository {}

void main() {
  const sessionId = "session-1";

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  group("SessionDetailCubit", () {
    late MockSessionService mockSessionService;
    late MockSessionRepository mockSessionRepository;
    late MockProjectRepository mockProjectRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late MockFailureReporter mockFailureReporter;
    late SessionDetailLoadService loadService;
    late SessionRepository promptDispatcher;
    late BehaviorSubject<SesoriSessionEvent> sessionEvents;
    late BehaviorSubject<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionService = MockSessionService();
      mockSessionRepository = MockSessionRepository();
      mockProjectRepository = MockProjectRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      mockFailureReporter = MockFailureReporter();
      loadService = SessionDetailLoadService(
        repository: mockSessionRepository,
        projectRepository: mockProjectRepository,
        connectionService: mockConnectionService,
      );
      promptDispatcher = mockSessionRepository;
      sessionEvents = BehaviorSubject<SesoriSessionEvent>();
      globalEvents = BehaviorSubject<SseEvent>();
      connectionStatus = BehaviorSubject<ConnectionStatus>();

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

      delegateSessionRepositoryToService(repository: mockSessionRepository, service: mockSessionService);
      when(() => mockProjectRepository.findSessionContext(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => const ProjectSessionContext(projectId: "test-project", sessionTitle: null),
      );

      _stubAllDefaults(
        mockSessionService,
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        sessionEvents: sessionEvents,
        globalEvents: globalEvents,
        connectionStatus: connectionStatus,
      );
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "initial load success emits SessionDetailLoaded",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(1);
        verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(1);
        verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(1);
        verify(() => mockSessionService.getSessionStatuses()).called(1);
        verify(() => mockSessionService.listAgents()).called(1);
        verify(() => mockSessionService.listProviders()).called(1);
        verify(() => mockSessionService.listCommands(projectId: "test-project")).called(1);
        verify(() => mockConnectionService.sessionEvents(sessionId)).called(1);
        verify(() => mockConnectionService.events).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "initial load failure emits SessionDetailFailed",
      build: () {
        when(
          () => mockSessionService.getMessages(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      expect: () => [
        isA<SessionDetailFailed>(),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "reload re-fetches all initial data",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.reload();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoading>(),
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSessionService.getMessages(sessionId: sessionId)).called(2);
        verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(2);
        verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(2);
        verify(() => mockSessionService.getSessionStatuses()).called(2);
        verify(() => mockSessionService.listAgents()).called(2);
        verify(() => mockSessionService.listProviders()).called(2);
        verify(() => mockSessionService.listCommands(projectId: "test-project")).called(2);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage when connected delegates to service with trimmed text",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(text: "  hi  ", command: null);
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "hi",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
            variant: null,
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage with command when connected delegates to service",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(text: "lib/main.dart", command: "review");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "lib/main.dart",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
            variant: null,
            command: "review",
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage sends immediately when session is busy but connected",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Session becomes busy.
        sessionEvents.add(
          const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.busy()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Send message while busy — should send immediately (not queue).
        await cubit.sendMessage(text: "hello", command: null);
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        // Session busy.
        isA<SessionDetailLoaded>().having(
          (state) => state.sessionStatus,
          "sessionStatus",
          const SessionStatus.busy(),
        ),
        // No queuedMessages emission — message was sent directly.
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "hello",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
            variant: null,
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectAgent updates selected agent in loaded state",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectAgent("reviewer");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.selectedAgent,
          "selectedAgent",
          "reviewer",
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectModel updates selected provider and model",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectModel(providerID: "openai", modelID: "gpt-4.1");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>()
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
            ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "abort delegates to service.abortSession",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.abort();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSessionService.abortSession(sessionId: sessionId)).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "replyToQuestion optimistically removes pending question and calls API",
      build: () {
        when(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).thenAnswer(
          (_) async => ApiResponse.success(PendingQuestionResponse(data: [testPendingQuestion()])),
        );

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.replyToQuestion(
          requestId: "question-1",
          sessionId: sessionId,
          answers: const [
            ReplyAnswer(values: ["Yes"]),
          ],
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions.length, "pendingCount", 1),
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions, "pendingQuestions", isEmpty),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.replyToQuestion(
            requestId: "question-1",
            sessionId: sessionId,
            answers: const [
              ReplyAnswer(values: ["Yes"]),
            ],
          ),
        ).called(1);
        verify(
          () => mockNotificationCanceller.cancelForSession(
            sessionId: sessionId,
            category: NotificationCategory.aiInteraction,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "rejectQuestion optimistically removes pending question and calls API",
      build: () {
        when(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).thenAnswer(
          (_) async => ApiResponse.success(PendingQuestionResponse(data: [testPendingQuestion()])),
        );

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.rejectQuestion("question-1");
      },
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions.length, "pendingCount", 1),
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions, "pendingQuestions", isEmpty),
      ],
      verify: (_) {
        verify(() => mockSessionService.rejectQuestion(requestId: "question-1")).called(1);
        verify(
          () => mockNotificationCanceller.cancelForSession(
            sessionId: sessionId,
            category: NotificationCategory.aiInteraction,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "clearNotifications cancels all non-unknown notification categories",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.clearNotifications();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        for (final category in NotificationCategory.values) {
          if (category == NotificationCategory.unknown) continue;
          verify(
            () => mockNotificationCanceller.cancelForSession(
              sessionId: sessionId,
              category: category,
            ),
          ).called(1);
        }
        verifyNever(
          () => mockNotificationCanceller.cancelForSession(
            sessionId: sessionId,
            category: NotificationCategory.unknown,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE message.updated adds message to state",
      build: () {
        when(
          () => mockSessionService.getMessages(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(const MessageWithPartsResponse(messages: <MessageWithParts>[])));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        const message = Message.user(
          id: "msg-new",
          sessionID: sessionId,
          agent: null,
        );
        sessionEvents.add(const SesoriMessageUpdated(info: message));
      },
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.messages.length, "messagesLength", 0),
        isA<SessionDetailLoaded>()
            .having((state) => state.messages.length, "messagesLength", 1)
            .having((state) => state.messages.first.info.id, "messageId", "msg-new"),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE session.status updates session status",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        sessionEvents.add(
          const SesoriSessionStatus(
            sessionID: sessionId,
            status: SessionStatus.busy(),
          ),
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.sessionStatus,
          "sessionStatus",
          const SessionStatus.busy(),
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE question.asked adds pending question",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        sessionEvents.add(testSseQuestionAsked());
      },
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions, "pendingQuestions", isEmpty),
        isA<SessionDetailLoaded>()
            .having((state) => state.pendingQuestions.length, "pendingCount", 1)
            .having((state) => state.pendingQuestions.first.id, "questionId", "question-1"),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE question.resolved removes pending question",
      build: () {
        when(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).thenAnswer(
          (_) async => ApiResponse.success(PendingQuestionResponse(data: [testPendingQuestion()])),
        );

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        sessionEvents.add(
          const SesoriQuestionReplied(
            requestID: "question-1",
            sessionID: sessionId,
          ),
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions.length, "pendingCount", 1),
        isA<SessionDetailLoaded>().having((state) => state.pendingQuestions, "pendingQuestions", isEmpty),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE session.updated updates title",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        sessionEvents.add(
          SesoriSessionUpdated(
            info: testSession(
              id: sessionId,
              title: "Renamed Session",
            ),
          ),
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.sessionTitle,
          "sessionTitle",
          "Renamed Session",
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "children are sorted most-recent-first on initial load",
      build: () {
        final oldChild = testSession(id: "child-old", parentID: sessionId, updatedAt: 1000);
        final midChild = testSession(id: "child-mid", parentID: sessionId, updatedAt: 2000);
        final newChild = testSession(id: "child-new", parentID: sessionId, updatedAt: 3000);

        // Service returns children in ASC order (oldest first).
        when(
          () => mockSessionService.getChildren(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [oldChild, midChild, newChild])));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids (DESC)",
          ["child-new", "child-mid", "child-old"],
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "new child session via SSE is inserted in sorted order",
      build: () {
        final existingChild = testSession(id: "child-1", parentID: sessionId, updatedAt: 1000);

        when(
          () => mockSessionService.getChildren(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [existingChild])));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // A newer child session arrives via global SSE event.
        final newerChild = testSession(id: "child-2", parentID: sessionId, updatedAt: 5000);
        globalEvents.add(SseEvent(data: SesoriSessionCreated(info: newerChild)));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      expect: () => [
        // Initial load with one child.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids",
          ["child-1"],
        ),
        // After SSE event, newer child sorted first.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids (DESC)",
          ["child-2", "child-1"],
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "close disposes event subscriptions",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.close();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        expect(sessionEvents.hasListener, isFalse);
        expect(globalEvents.hasListener, isFalse);
        expect(connectionStatus.hasListener, isFalse);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage queues when connection is lost",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );
        await cubit.sendMessage(text: "hello", command: null);
      },
      skip: 1,
      expect: () => [
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage queues when reconnecting",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.reconnecting(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );
        await cubit.sendMessage(text: "hello", command: null);
      },
      skip: 1,
      expect: () => [
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage re-queues on send failure",
      build: () {
        when(
          () => mockSessionService.sendMessage(
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(text: "hello", command: null);
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        // Message re-queued after failed send.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "hello",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
            variant: null,
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "session becoming idle does not drain queue when disconnected",
      build: () {
        // Start with a busy session so the idle SSE event produces a real state
        // transition (idle vs busy), allowing the test to verify the queue is
        // NOT drained even when the session becomes idle while disconnected.
        when(
          () => mockSessionService.getSessionStatuses(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const SessionStatusResponse(statuses: {sessionId: SessionStatus.busy()}),
          ),
        );
        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Connection drops.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );

        // Send message while disconnected — queued.
        await cubit.sendMessage(text: "queued msg", command: null);

        // Session becomes idle — but connection is lost, so queue stays.
        sessionEvents.add(
          const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.idle()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      expect: () => [
        // Initial load.
        isA<SessionDetailLoaded>(),
        // Message queued.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["queued msg"],
        ),
        // Session idle — queue NOT drained because disconnected.
        isA<SessionDetailLoaded>()
            .having((state) => state.sessionStatus, "sessionStatus", const SessionStatus.idle())
            .having(
              (state) => state.queuedMessages.map((message) => message.displayText).toList(),
              "queuedMessages",
              ["queued msg"],
            ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "connection restored drains queued messages",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );

        // Send message — queued because disconnected.
        await cubit.sendMessage(text: "retry me", command: null);

        // Simulate reconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        // Initial load.
        isA<SessionDetailLoaded>(),
        // Message queued.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["retry me"],
        ),
        // Queue drained after reconnection.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "retry me",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
            variant: null,
            command: null,
          ),
        ).called(1);
      },
    );

    test("whitespace-only command is queued and drained as a normal prompt", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com"),
        ),
      );

      await cubit.sendMessage(text: "hello", command: "   ");

      expect(
        (cubit.state as SessionDetailLoaded).queuedMessages.map((message) => message.displayText).toList(),
        equals(["hello"]),
      );

      when(() => mockConnectionService.currentStatus).thenReturn(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com"),
          health: testHealthResponse(),
        ),
      );
      connectionStatus.add(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com"),
          health: testHealthResponse(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => mockSessionService.sendMessage(
          sessionId: sessionId,
          text: "hello",
          agent: "coder",
          providerID: "anthropic",
          modelID: "claude-3-5-sonnet",
          variant: null,
          command: null,
        ),
      ).called(1);
    });

    test("connected send while queued drain is in flight stays queued until earlier work finishes", () async {
      final firstSendStarted = Completer<void>();
      final allowFirstSendToComplete = Completer<void>();
      final sentTexts = <String>[];

      when(
        () => mockSessionService.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((invocation) async {
        final text = invocation.namedArguments[#text] as String;
        sentTexts.add(text);
        if (text == "first") {
          firstSendStarted.complete();
          await allowFirstSendToComplete.future;
        }
        return ApiResponse<void>.success(null);
      });

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com"),
        ),
      );
      await cubit.sendMessage(text: "first", command: null);

      when(() => mockConnectionService.currentStatus).thenReturn(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com"),
          health: testHealthResponse(),
        ),
      );
      connectionStatus.add(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com"),
          health: testHealthResponse(),
        ),
      );

      await firstSendStarted.future;
      await cubit.sendMessage(text: "second", command: null);

      expect(sentTexts, equals(["first"]));
      expect(
        (cubit.state as SessionDetailLoaded).queuedMessages.map((message) => message.displayText).toList(),
        equals(["second"]),
      );

      allowFirstSendToComplete.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sentTexts, equals(["first", "second"]));
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "multiple queued messages drain sequentially on reconnection",
      build: () => SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
        failureReporter: mockFailureReporter,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );

        // Queue two messages while disconnected.
        await cubit.sendMessage(text: "first", command: null);
        await cubit.sendMessage(text: "second", command: null);

        // Simulate reconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );

        // Wait for both messages to drain via self-chaining.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "first",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "second",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "queued message send failure re-queues the message",
      build: () {
        // Make sendMessage always fail — it is only called during drain,
        // not during initial load, so this is safe.
        when(
          () => mockSessionService.sendMessage(
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockConnectionService,
          loadService: loadService,
          promptDispatcher: promptDispatcher,
          permissionRepository: mockPermissionRepository,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
          failureReporter: mockFailureReporter,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );

        // Queue a message.
        await cubit.sendMessage(text: "will fail", command: null);

        // Simulate reconnection — triggers drain, but send will fail.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com"),
            health: testHealthResponse(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        // Initial load.
        isA<SessionDetailLoaded>(),
        // Message queued.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["will fail"],
        ),
        // Dequeued (optimistic).
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          isEmpty,
        ),
        // Re-queued after failure.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["will fail"],
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId: sessionId,
            text: "will fail",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
      },
    );
  });
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  for (var i = 0; i < 50; i++) {
    if (cubit.state is SessionDetailLoaded) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void _stubAllDefaults(
  MockSessionService service,
  MockSessionService sessionService,
  MockConnectionService connectionService, {
  required String sessionId,
  required MockNotificationCanceller notificationCanceller,
  required BehaviorSubject<SesoriSessionEvent> sessionEvents,
  required BehaviorSubject<SseEvent> globalEvents,
  required BehaviorSubject<ConnectionStatus> connectionStatus,
}) {
  when(
    () => service.getMessages(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<MessageWithPartsResponse>>.value(
      ApiResponse.success(MessageWithPartsResponse(messages: [testMessageWithParts()])),
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
  when(
    () => service.listAgents(),
  ).thenAnswer(
    (_) => Future<ApiResponse<Agents>>.value(
      ApiResponse.success(Agents(agents: [testAgentInfo()])),
    ),
  );
  when(
    () => service.listProviders(),
  ).thenAnswer(
    (_) => Future<ApiResponse<ProviderListResponse>>.value(
      ApiResponse.success(testProviderListResponse()),
    ),
  );
  when(
    () => sessionService.listCommands(projectId: any(named: "projectId")),
  ).thenAnswer(
    (_) => Future<ApiResponse<CommandListResponse>>.value(
      ApiResponse.success(const CommandListResponse(items: <CommandInfo>[])),
    ),
  );

  when(
    () => connectionService.sessionEvents(sessionId),
  ).thenAnswer((_) => sessionEvents.stream);
  when(
    () => connectionService.events,
  ).thenAnswer((_) => globalEvents.stream);
  when(
    () => connectionService.currentStatus,
  ).thenReturn(
    ConnectionStatus.connected(
      config: const ServerConnectionConfig(relayHost: "fake.example.com"),
      health: testHealthResponse(),
    ),
  );
  when(
    () => connectionService.status,
  ).thenAnswer((_) => connectionStatus);

  when(
    () => notificationCanceller.cancelForSession(
      sessionId: any(named: "sessionId"),
      category: any(named: "category"),
    ),
  ).thenReturn(null);

  when(
    () => sessionService.sendMessage(
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      agent: any(named: "agent"),
      providerID: any(named: "providerID"),
      modelID: any(named: "modelID"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
  when(
    () => service.abortSession(sessionId: any(named: "sessionId")),
  ).thenAnswer((_) async => ApiResponse.success(null));
  when(
    () => service.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
  when(
    () => service.rejectQuestion(requestId: any(named: "requestId")),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
}
