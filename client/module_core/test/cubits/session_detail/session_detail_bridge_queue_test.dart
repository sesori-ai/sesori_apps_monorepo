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
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class MockNotificationCanceller() extends Mock implements NotificationCanceller;

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockSessionDetailLoadService() extends Mock implements SessionDetailLoadService;

const _sessionId = "session-1";

const _queuedPrompt = QueuedSessionPrompt(
  id: "prm_1",
  text: "steer it",
  command: null,
  attachmentCount: 0,
  createdAt: 100,
);

void main() {
  const connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  group("SessionDetailCubit bridge-owned queue", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late StreamController<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      globalEvents = StreamController<SseEvent>.broadcast();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    Future<SessionDetailCubit> createLoadedCubit({
      List<QueuedSessionPrompt> snapshotQueue = const [],
    }) async {
      final mockLoadService = MockSessionDetailLoadService();
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
            pluginId: "claude",
            supportsPromptAttachments: false,
            messages: const <MessageWithParts>[],
            olderMessagesCursor: null,
            pendingQuestions: const <PendingQuestion>[],
            pendingPermissions: const <PendingPermission>[],
            bridgeQueuedPrompts: snapshotQueue,
            childSessions: const <Session>[],
            statuses: const <String, SessionStatus>{},
            agents: const <AgentInfo>[],
            providerData: null,
            commands: const <CommandInfo>[],
            canonicalSessionTitle: null,
            promptDefaults: null,
            isRootSession: true,
            isArchived: false,
          ),
          isBridgeConnected: true,
        ),
      );
      when(() => mockConnectionService.sessionEvents(_sessionId)).thenAnswer((_) => sessionEvents.stream);
      when(() => mockConnectionService.events).thenAnswer((_) => globalEvents.stream);
      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: mockLoadService,
        promptDispatcher: mockSessionRepository,
        permissionRepository: MockPermissionRepository(),
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: FakeLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: stubbedProductAnalyticsService(),
        sessionId: _sessionId,
        projectId: "project-1",
        notificationCanceller: MockNotificationCanceller(),
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => state is SessionDetailLoaded);
      return cubit;
    }

    test("loads the bridge queue from the snapshot", () async {
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);

      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, const [_queuedPrompt]);
    });

    test("replaces the queue from the SSE event and drops the accepted local copy", () async {
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();

      // Stage a send whose acceptance response is still in flight.
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final sending = (cubit.state as SessionDetailLoaded).sendingSubmission;
      final promptId = sending?.promptId;
      expect(promptId, isNotNull);

      // The bridge's queue event races ahead of the acceptance response: the
      // local copy hands over in the same emission.
      final acceptedPrompt = QueuedSessionPrompt(
        id: promptId ?? "",
        text: "steer it",
        command: null,
        attachmentCount: 0,
        createdAt: 100,
      );
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: [acceptedPrompt]) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts.single.id, promptId);
      expect(state.sendingSubmission, isNull, reason: "the bridge owns the prompt now");
      expect(state.queuedMessages, isEmpty);
      sendCompleter.complete(ApiResponse.success(null));
    });

    test("transforms the queued entry into its message in one emission", () async {
      final cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);

      final emissions = <SessionDetailState>[];
      final subscription = cubit.stream.listen(emissions.add);
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 200, completed: null),
            promptId: "prm_1",
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.single.info.id, "echo-1");
      expect(state.bridgeQueuedPrompts, isEmpty);
      final transition = emissions.whereType<SessionDetailLoaded>().firstWhere(
        (emitted) => emitted.messages.any((message) => message.info.id == "echo-1"),
      );
      expect(
        transition.bridgeQueuedPrompts,
        isEmpty,
        reason: "no frame may show both the queued bubble and its message",
      );
      await subscription.cancel();
    });

    test("cancel removes the entry on success and on not-found, keeps it on transport failure", () async {
      when(
        () => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"),
      ).thenAnswer((_) async => ApiResponse.success(null));
      var cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      expect((cubit.state as SessionDetailLoaded).bridgeQueuedPrompts, isEmpty);

      when(
        () => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));
      cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      expect(
        (cubit.state as SessionDetailLoaded).bridgeQueuedPrompts,
        isEmpty,
        reason: "not-found means it already dispatched or was removed elsewhere",
      );

      when(
        () => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("offline"))));
      cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      expect(
        (cubit.state as SessionDetailLoaded).bridgeQueuedPrompts,
        const [_queuedPrompt],
        reason: "an unreachable bridge proves nothing about the entry",
      );

      when(
        () => mockSessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: "prm_1"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null)));
      cubit = await createLoadedCubit(snapshotQueue: const [_queuedPrompt]);
      await cubit.cancelBridgeQueuedPrompt(promptId: "prm_1");
      expect(
        (cubit.state as SessionDetailLoaded).bridgeQueuedPrompts,
        const [_queuedPrompt],
        reason: "a server rejection other than not-found must not hide a still-live entry",
      );
    });

    test("a snapshot listing an accepted prompt drops its staged local copy", () async {
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).sendingSubmission?.promptId;
      expect(promptId, isNotNull);

      // A refresh whose snapshot already lists the prompt (the acceptance
      // response was lost) must not leave a duplicate staged copy behind.
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(id: promptId ?? "", text: "steer it", command: null, attachmentCount: 0, createdAt: 1),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.sendingSubmission, isNull);
      expect(state.queuedMessages, isEmpty);
      expect(state.bridgeQueuedPrompts.single.id, promptId);
      sendCompleter.complete(ApiResponse.success(null));
    });

    test("healing a lost-response prompt re-drains the sends staged behind it", () async {
      final firstSend = Completer<ApiResponse<void>>();
      final laterSends = <String>[];
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((invocation) {
        sendCalls++;
        if (sendCalls == 1) return firstSend.future;
        laterSends.add(invocation.namedArguments[#text]! as String);
        return Future.value(ApiResponse.success(null));
      });
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "first", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      unawaited(
        cubit.sendMessage(text: "second", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final firstPromptId = (cubit.state as SessionDetailLoaded).sendingSubmission?.promptId;
      expect(firstPromptId, isNotNull);

      // The first send's response was lost, but its message lands via SSE:
      // the second staged send must dispatch without an external trigger.
      firstSend.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-first",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 300, completed: null),
            promptId: firstPromptId,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(laterSends, ["second"]);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("abort drops locally staged sends", () async {
      when(() => mockSessionRepository.abortSession(sessionId: _sessionId)).thenAnswer(
        (_) async => ApiResponse.success(null),
      );
      final sendCompleter = Completer<ApiResponse<void>>();
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) => sendCompleter.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "one", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      unawaited(
        cubit.sendMessage(text: "two", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isNotEmpty);

      await cubit.abort();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages, isEmpty);
      expect(state.sendingSubmission, isNull);
      sendCompleter.complete(ApiResponse.success(null));
    });
  });
}
