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

  group("SessionDetailCubit SSE event buffering", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late StreamController<SesoriSessionEvent> sessionEvents;
    late StreamController<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      globalEvents = StreamController<SseEvent>.broadcast();
      connectionStatus = BehaviorSubject<ConnectionStatus>.seeded(connectedStatus);
    });

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    SessionDetailCubit createCubit({
      required SessionDetailLoadService loadService,
    }) {
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

      final cubit = SessionDetailCubit(
        mockConnectionService,
        loadService: loadService,
        promptDispatcher: mockSessionRepository,
        permissionRepository: mockPermissionRepository,
        sessionId: _sessionId,
        projectId: "project-1",
        notificationCanceller: mockNotificationCanceller,
        failureReporter: MockFailureReporter(),
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test("buffers session-scoped SSE events during loading and replays after loaded", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Cubit starts in loading state
      expect(cubit.state, const SessionDetailState.loading());

      // Emit a session-scoped event while still loading
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Still loading — event should be buffered, not processed yet
      expect(cubit.state, const SessionDetailState.loading());

      // Complete the load with an empty snapshot
      completer.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);

      // The buffered event should have been replayed, adding the message
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.length, 1);
      expect(state.messages.first.info.id, "msg-1");
      expect(state.agent, "build");
    });

    test("buffers global SSE events during loading and replays after loaded", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Emit a global child-session event while still loading
      const childSession = Session(
        id: "child-1",
        projectID: "project-1",
        directory: "/home/user/my-project",
        parentID: _sessionId,
        title: "Child session",
        summary: null,
        pullRequest: null,
        time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
      );
      globalEvents.add(
        SseEvent(data: const SesoriSessionCreated(info: childSession)),
      );
      await Future<void>.delayed(Duration.zero);

      // Still loading
      expect(cubit.state, const SessionDetailState.loading());

      // Complete the load
      completer.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);

      // The buffered global event should have been replayed
      final state = cubit.state as SessionDetailLoaded;
      expect(state.children.length, 1);
      expect(state.children.first.id, "child-1");
    });

    test("clears pending events when load fails", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Emit an event while loading
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Complete the load with failure
      completer.complete(
        SessionDetailLoadResult.failed(
          error: ApiError.generic(),
          stackTrace: StackTrace.current,
        ),
      );

      // Wait for the failure state to be emitted
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state, isA<SessionDetailFailed>());

      // Now reload manually — the old buffered event should NOT be replayed
      final reloadedCompleter = Completer<SessionDetailLoadResult>();
      when(
        () => mockLoadService.reload(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => reloadedCompleter.future);

      unawaited(cubit.reload());

      reloadedCompleter.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);

      // The old buffered event should have been cleared on failure
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages, isEmpty);
    });

    test("events arriving during failed state are dropped, not buffered", () async {
      final mockLoadService = MockSessionDetailLoadService();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => SessionDetailLoadResult.failed(
          error: ApiError.generic(),
          stackTrace: StackTrace.current,
        ),
      );

      final cubit = createCubit(loadService: mockLoadService);

      // Wait for the failure state
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state, isA<SessionDetailFailed>());

      // Emit an event while in failed state — should be dropped
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Now reload successfully
      final reloadedCompleter = Completer<SessionDetailLoadResult>();
      when(
        () => mockLoadService.reload(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => reloadedCompleter.future);

      unawaited(cubit.reload());

      reloadedCompleter.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);

      // The event emitted during failed state should NOT have been replayed
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages, isEmpty);
    });

    test("processes events immediately when already loaded", () async {
      final mockLoadService = MockSessionDetailLoadService();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      // Emit an event after already loaded
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Should be processed immediately
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.length, 1);
      expect(state.messages.first.info.id, "msg-1");
    });
    test("does not buffer irrelevant global events (PTY, file watcher, etc.)", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(sessionId: _sessionId, projectId: any(named: "projectId")),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Emit high-volume irrelevant global events while loading
      globalEvents.add(SseEvent(data: const SesoriPtyCreated()));
      globalEvents.add(SseEvent(data: const SesoriPtyUpdated()));
      globalEvents.add(SseEvent(data: const SesoriFileWatcherUpdated(file: null, event: null)));
      globalEvents.add(SseEvent(data: const SesoriLspUpdated()));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, const SessionDetailState.loading());

      // Complete the load
      completer.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
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
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);

      // No children or other side effects from the irrelevant events
      final state = cubit.state as SessionDetailLoaded;
      expect(state.children, isEmpty);
      expect(state.pendingPermissions, isEmpty);
      expect(state.pendingQuestions, isEmpty);
    });
  });
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  for (var i = 0; i < 100; i++) {
    if (cubit.state is SessionDetailLoaded) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail("Timed out waiting for SessionDetailLoaded; current state: ${cubit.state}");
}
