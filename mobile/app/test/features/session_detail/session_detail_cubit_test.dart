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
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  const sessionId = "session-1";

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  group("SessionDetailCubit", () {
    late MockSessionService mockSessionService;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late BehaviorSubject<SesoriSessionEvent> sessionEvents;
    late BehaviorSubject<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionService = MockSessionService();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      sessionEvents = BehaviorSubject<SesoriSessionEvent>();
      globalEvents = BehaviorSubject<SseEvent>();
      connectionStatus = BehaviorSubject<ConnectionStatus>();

      _stubAllDefaults(
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
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      ),
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSessionService.getMessages(sessionId)).called(1);
        verify(() => mockSessionService.getPendingQuestions(sessionId)).called(1);
        verify(() => mockSessionService.getChildren(sessionId)).called(1);
        verify(() => mockSessionService.getSessionStatuses()).called(1);
        verify(() => mockSessionService.listAgents()).called(1);
        verify(() => mockSessionService.listProviders()).called(1);
        verify(() => mockConnectionService.sessionEvents(sessionId)).called(1);
        verify(() => mockConnectionService.events).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "initial load failure emits SessionDetailFailed",
      build: () {
        when(
          () => mockSessionService.getMessages(sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
      },
      expect: () => [
        isA<SessionDetailFailed>(),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "reload re-fetches all initial data",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        verify(() => mockSessionService.getMessages(sessionId)).called(2);
        verify(() => mockSessionService.getPendingQuestions(sessionId)).called(2);
        verify(() => mockSessionService.getChildren(sessionId)).called(2);
        verify(() => mockSessionService.getSessionStatuses()).called(2);
        verify(() => mockSessionService.listAgents()).called(2);
        verify(() => mockSessionService.listProviders()).called(2);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage when connected delegates to service with trimmed text",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage("  hi  ");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId,
            "hi",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage sends immediately when session is busy but connected",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Session becomes busy.
        sessionEvents.add(
          const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.busy()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Send message while busy — should send immediately (not queue).
        await cubit.sendMessage("hello");
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
            sessionId,
            "hello",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectAgent updates selected agent in loaded state",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectModel("openai", "gpt-4.1");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>()
            .having((state) => state.selectedProviderID, "selectedProviderID", "openai")
            .having((state) => state.selectedModelID, "selectedModelID", "gpt-4.1"),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "abort delegates to service.abortSession",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      ),
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.abort();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(() => mockSessionService.abortSession(sessionId)).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "replyToQuestion optimistically removes pending question and calls API",
      build: () {
        when(() => mockSessionService.getPendingQuestions(any())).thenAnswer(
          (_) async => ApiResponse.success([testPendingQuestion()]),
        );

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
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
        when(() => mockSessionService.getPendingQuestions(any())).thenAnswer(
          (_) async => ApiResponse.success([testPendingQuestion()]),
        );

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
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
        verify(() => mockSessionService.rejectQuestion("question-1")).called(1);
        verify(
          () => mockNotificationCanceller.cancelForSession(
            sessionId: sessionId,
            category: NotificationCategory.aiInteraction,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE message.updated adds message to state",
      build: () {
        when(
          () => mockSessionService.getMessages(sessionId),
        ).thenAnswer((_) async => ApiResponse.success(<MessageWithParts>[]));

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        const message = Message(
          id: "msg-new",
          role: "user",
          sessionID: sessionId,
          time: MessageTime(created: 1700000000001),
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
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        when(() => mockSessionService.getPendingQuestions(any())).thenAnswer(
          (_) async => ApiResponse.success([testPendingQuestion()]),
        );

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
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
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
      "close disposes event subscriptions",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
      build: () {
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );
        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage("hello");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            any(),
            any(),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage queues when reconnecting",
      build: () {
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.reconnecting(
            config: ServerConnectionConfig(relayHost: "fake.example.com"),
          ),
        );
        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage("hello");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            any(),
            any(),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage re-queues on send failure",
      build: () {
        when(
          () => mockSessionService.sendMessage(
            any(),
            any(),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage("hello");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        // Message re-queued after failed send.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId,
            "hello",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
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
          (_) async => ApiResponse.success({sessionId: const SessionStatus.busy()}),
        );
        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
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
        await cubit.sendMessage("queued msg");

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
          (state) => state.queuedMessages,
          "queuedMessages",
          ["queued msg"],
        ),
        // Session idle — queue NOT drained because disconnected.
        isA<SessionDetailLoaded>()
            .having((state) => state.sessionStatus, "sessionStatus", const SessionStatus.idle())
            .having((state) => state.queuedMessages, "queuedMessages", ["queued msg"]),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            any(),
            any(),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "connection restored drains queued messages",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        await cubit.sendMessage("retry me");

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
          (state) => state.queuedMessages,
          "queuedMessages",
          ["retry me"],
        ),
        // Queue drained after reconnection.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId,
            "retry me",
            agent: "coder",
            providerID: "anthropic",
            modelID: "claude-3-5-sonnet",
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "multiple queued messages drain sequentially on reconnection",
      build: () => SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
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
        await cubit.sendMessage("first");
        await cubit.sendMessage("second");

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
            sessionId,
            "first",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        ).called(1);
        verify(
          () => mockSessionService.sendMessage(
            sessionId,
            "second",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
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
            any(),
            any(),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
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
        await cubit.sendMessage("will fail");

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
          (state) => state.queuedMessages,
          "queuedMessages",
          ["will fail"],
        ),
        // Dequeued (optimistic).
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          isEmpty,
        ),
        // Re-queued after failure.
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages,
          "queuedMessages",
          ["will fail"],
        ),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            sessionId,
            "will fail",
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
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
  MockConnectionService connectionService, {
  required String sessionId,
  required MockNotificationCanceller notificationCanceller,
  required BehaviorSubject<SesoriSessionEvent> sessionEvents,
  required BehaviorSubject<SseEvent> globalEvents,
  required BehaviorSubject<ConnectionStatus> connectionStatus,
}) {
  when(
    () => service.getMessages(sessionId),
  ).thenAnswer((_) async => ApiResponse.success([testMessageWithParts()]));
  when(
    () => service.getPendingQuestions(any()),
  ).thenAnswer((_) async => ApiResponse.success(<PendingQuestion>[]));
  when(
    () => service.getChildren(sessionId),
  ).thenAnswer((_) async => ApiResponse.success(<Session>[]));
  when(
    () => service.getSessionStatuses(),
  ).thenAnswer((_) async => ApiResponse.success(<String, SessionStatus>{}));
  when(
    () => service.listAgents(),
  ).thenAnswer((_) async => ApiResponse.success([testAgentInfo()]));
  when(
    () => service.listProviders(),
  ).thenAnswer((_) async => ApiResponse.success(testProviderListResponse()));

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
  ).thenAnswer((_) => connectionStatus.stream);

  when(
    () => notificationCanceller.cancelForSession(
      sessionId: any(named: "sessionId"),
      category: any(named: "category"),
    ),
  ).thenReturn(null);

  when(
    () => service.sendMessage(
      any(),
      any(),
      agent: any(named: "agent"),
      providerID: any(named: "providerID"),
      modelID: any(named: "modelID"),
    ),
  ).thenAnswer((_) async => ApiResponse.success(true));
  when(
    () => service.abortSession(any()),
  ).thenAnswer((_) async => ApiResponse.success(true));
  when(
    () => service.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer((_) async => ApiResponse.success(true));
  when(
    () => service.rejectQuestion(any()),
  ).thenAnswer((_) async => ApiResponse.success(true));
}
