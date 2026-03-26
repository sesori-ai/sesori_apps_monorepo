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
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationCanceller extends Mock implements NotificationCanceller {}

void main() {
  const sessionId = "session-1";
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200"),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  group("SessionDetailCubit stale reconnect", () {
    late MockSessionService mockSessionService;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late StreamController<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionService = MockSessionService();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      globalEvents = StreamController<SseEvent>.broadcast();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);

      when(() => mockConnectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus.stream);
      when(() => mockConnectionService.currentStatus).thenReturn(connectedStatus);
      when(
        () => mockNotificationCanceller.cancelForSession(
          sessionId: any(named: "sessionId"),
          category: any(named: "category"),
        ),
      ).thenReturn(null);

      _stubLoadApis(mockSessionService, sessionId: sessionId);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    test(
      "stale signal triggers silent refresh — emits isRefreshing=true then updated data with isRefreshing=false",
      () async {
        final cubit = SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);

        when(() => mockSessionService.getMessages(sessionId)).thenAnswer(
          (_) async => ApiResponse.success([_messageWithParts(messageId: "msg-refreshed")]),
        );

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitStaleReconnect();
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

    test("silent refresh preserves selectedAgent, selectedProviderID, selectedModelID from current state", () async {
      final cubit = SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      cubit.selectAgent("oracle");
      cubit.selectModel("openai", "gpt-4.1");

      when(() => mockSessionService.listAgents()).thenAnswer(
        (_) async => ApiResponse.success([
          const AgentInfo(name: "build", description: "build", mode: AgentMode.primary),
        ]),
      );
      when(() => mockSessionService.listProviders()).thenAnswer(
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
                  ),
                },
              ),
            ],
          ),
        ),
      );

      mockConnectionService.emitStaleReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.selectedAgent, "oracle");
      expect(loaded.selectedProviderID, "openai");
      expect(loaded.selectedModelID, "gpt-4.1");
      expect(loaded.isRefreshing, isFalse);
    });

    test("silent refresh clears streaming text buffer", () async {
      final cubit = SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);

      sessionEvents.add(
        const SesoriMessagePartDelta(
          sessionID: sessionId,
          messageID: "msg-1",
          partID: "part-1",
          field: "text",
          delta: "stale-streaming",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final beforeRefresh = cubit.state as SessionDetailLoaded;
      expect(beforeRefresh.streamingText, {"part-1": "stale-streaming"});

      final emitted = <SessionDetailState>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      mockConnectionService.emitStaleReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final refreshing = emitted.first as SessionDetailLoaded;
      final refreshed = emitted.last as SessionDetailLoaded;
      expect(refreshing.streamingText, isEmpty);
      expect(refreshed.streamingText, isEmpty);
    });

    test("stale signal is ignored when state is SessionDetailLoading", () async {
      final messagesCompleter = Completer<ApiResponse<List<MessageWithParts>>>();
      when(() => mockSessionService.getMessages(sessionId)).thenAnswer((_) => messagesCompleter.future);

      final cubit = SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      );

      mockConnectionService.emitStaleReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockSessionService.getMessages(sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId)).called(1);
      verify(() => mockSessionService.getChildren(sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents()).called(1);
      verify(() => mockSessionService.listProviders()).called(1);

      messagesCompleter.complete(ApiResponse.success([_messageWithParts()]));
      await _awaitLoaded(cubit);
      await cubit.close();
    });

    test("stale signal is ignored when state is SessionDetailFailed", () async {
      when(
        () => mockSessionService.getMessages(sessionId),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      );
      addTearDown(cubit.close);

      await _awaitFailed(cubit);
      mockConnectionService.emitStaleReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockSessionService.getMessages(sessionId)).called(1);
      expect(cubit.state, isA<SessionDetailFailed>());
    });

    test(
      "silent refresh failure logs warning and resets isRefreshing to false without changing state",
      () async {
        final cubit = SessionDetailCubit(
          mockSessionService,
          mockConnectionService,
          sessionId: sessionId,
          notificationCanceller: mockNotificationCanceller,
        );
        addTearDown(cubit.close);

        await _awaitLoaded(cubit);
        final before = cubit.state as SessionDetailLoaded;

        when(
          () => mockSessionService.getMessages(sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        final emitted = <SessionDetailState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);

        mockConnectionService.emitStaleReconnect();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(emitted.length, 2);
        expect((emitted.first as SessionDetailLoaded).isRefreshing, isTrue);
        final afterFailure = emitted.last as SessionDetailLoaded;
        expect(afterFailure.isRefreshing, isFalse);
        expect(afterFailure.messages, before.messages);
        expect(afterFailure.selectedAgent, before.selectedAgent);
        expect(afterFailure.selectedProviderID, before.selectedProviderID);
        expect(afterFailure.selectedModelID, before.selectedModelID);
      },
    );

    test("concurrent stale signals are coalesced (single API call)", () async {
      final cubit = SessionDetailCubit(
        mockSessionService,
        mockConnectionService,
        sessionId: sessionId,
        notificationCanceller: mockNotificationCanceller,
      );
      addTearDown(cubit.close);

      await _awaitLoaded(cubit);
      reset(mockSessionService);

      final messagesCompleter = Completer<ApiResponse<List<MessageWithParts>>>();
      when(() => mockSessionService.getMessages(sessionId)).thenAnswer((_) => messagesCompleter.future);
      when(
        () => mockSessionService.getPendingQuestions(sessionId),
      ).thenAnswer((_) async => ApiResponse.success(<PendingQuestion>[]));
      when(() => mockSessionService.getChildren(sessionId)).thenAnswer((_) async => ApiResponse.success(<Session>[]));
      when(
        () => mockSessionService.getSessionStatuses(),
      ).thenAnswer((_) async => ApiResponse.success(<String, SessionStatus>{}));
      when(() => mockSessionService.listAgents()).thenAnswer((_) async => ApiResponse.success(_agents()));
      when(() => mockSessionService.listProviders()).thenAnswer((_) async => ApiResponse.success(_providers()));

      mockConnectionService.emitStaleReconnect();
      mockConnectionService.emitStaleReconnect();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      messagesCompleter.complete(ApiResponse.success([_messageWithParts(messageId: "msg-coalesced")]));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockSessionService.getMessages(sessionId)).called(1);
      verify(() => mockSessionService.getPendingQuestions(sessionId)).called(1);
      verify(() => mockSessionService.getChildren(sessionId)).called(1);
      verify(() => mockSessionService.getSessionStatuses()).called(1);
      verify(() => mockSessionService.listAgents()).called(1);
      verify(() => mockSessionService.listProviders()).called(1);
    });
  });
}

void _stubLoadApis(MockSessionService service, {required String sessionId}) {
  when(() => service.getMessages(sessionId)).thenAnswer((_) async => ApiResponse.success([_messageWithParts()]));
  when(() => service.getPendingQuestions(sessionId)).thenAnswer((_) async => ApiResponse.success(<PendingQuestion>[]));
  when(() => service.getChildren(sessionId)).thenAnswer((_) async => ApiResponse.success(<Session>[]));
  when(() => service.getSessionStatuses()).thenAnswer((_) async => ApiResponse.success(<String, SessionStatus>{}));
  when(() => service.listAgents()).thenAnswer((_) async => ApiResponse.success(_agents()));
  when(() => service.listProviders()).thenAnswer((_) async => ApiResponse.success(_providers()));
}

MessageWithParts _messageWithParts({String messageId = "msg-1"}) {
  return MessageWithParts(
    info: Message(id: messageId, role: "assistant", sessionID: "session-1"),
    parts: const [],
  );
}

List<AgentInfo> _agents() {
  return const [
    AgentInfo(name: "coder", description: "A coding assistant", mode: AgentMode.primary),
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
  fail("Timed out waiting for SessionDetailLoaded");
}

Future<void> _awaitFailed(SessionDetailCubit cubit) async {
  for (var i = 0; i < 100; i++) {
    if (cubit.state is SessionDetailFailed) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail("Timed out waiting for SessionDetailFailed");
}
