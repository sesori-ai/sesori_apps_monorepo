import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/logging/logging.dart";
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
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
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
      return cubit;
    }

    test("buffers session-scoped SSE events during loading and replays after loaded", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
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
        time: null,
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
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Emit a global child-session event while still loading
      const childSession = Session(
        branchName: null,
        id: "child-1",
        pluginId: "plugin-1",
        projectID: "project-1",
        directory: "/home/user/my-project",
        parentID: _sessionId,
        title: "Child session",
        pullRequest: null,
        time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
        promptDefaults: null,
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
      await _awaitLoaded(cubit);

      // The buffered global event should have been replayed
      final state = cubit.state as SessionDetailLoaded;
      expect(state.children.length, 1);
      expect(state.children.first.id, "child-1");
    });

    test("refreshes commands when session.commands.updated arrives during loading", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final loadCompleter = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => loadCompleter.future);
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer(
        (_) async => SessionCommandsLoadResult.loaded(
          commands: [testCommandInfo(name: "compact", template: "/compact")],
        ),
      );

      final cubit = createCubit(loadService: mockLoadService);
      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      await Future<void>.delayed(Duration.zero);

      loadCompleter.complete(
        const SessionDetailLoadResult.loaded(
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

      await _awaitLoadedWithCommand(cubit, command: "compact");
      verify(() => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode")).called(1);
      verifyNever(
        () => mockLoadService.reload(
          sessionId: any(named: "sessionId"),
          projectId: any(named: "projectId"),
        ),
      );
    });

    test("command refresh changes only the catalog and retained staged command", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final initialCommand = testCommandInfo(name: "review", template: "/review old");
      final refreshedCommand = testCommandInfo(name: "review", template: "/review new");
      final replacementCommand = testCommandInfo(name: "compact", template: "/compact");
      final commandResponses = <List<CommandInfo>>[
        [refreshedCommand],
        [replacementCommand],
      ];
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [initialCommand]));
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer(
        (_) async => SessionCommandsLoadResult.loaded(commands: commandResponses.removeAt(0)),
      );

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      cubit.stageCommand(initialCommand);
      final beforeRefresh = cubit.state as SessionDetailLoaded;
      final retainedUpdate = cubit.stream.firstWhere(
        (state) =>
            state is SessionDetailLoaded &&
            state.availableCommands.length == 1 &&
            state.availableCommands.single.template == refreshedCommand.template,
      );

      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      final retained = await retainedUpdate.timeout(const Duration(seconds: 1)) as SessionDetailLoaded;

      expect(
        retained,
        beforeRefresh.copyWith(
          availableCommands: [refreshedCommand],
          stagedCommand: refreshedCommand,
        ),
      );
      expect(retained.isRefreshing, isFalse);

      final removedUpdate = cubit.stream.firstWhere(
        (state) =>
            state is SessionDetailLoaded &&
            state.availableCommands.length == 1 &&
            state.availableCommands.single.name == "compact",
      );
      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      final removed = await removedUpdate.timeout(const Duration(seconds: 1)) as SessionDetailLoaded;

      expect(
        removed,
        retained.copyWith(
          availableCommands: [replacementCommand],
          stagedCommand: null,
        ),
      );
      verify(() => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode")).called(2);
      verifyNever(
        () => mockLoadService.reload(
          sessionId: any(named: "sessionId"),
          projectId: any(named: "projectId"),
        ),
      );
    });

    test("newer command refresh wins when responses complete out of order", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final initialCommand = testCommandInfo(name: "review", template: "/review initial");
      final olderCommand = testCommandInfo(name: "review", template: "/review older");
      final newerCommand = testCommandInfo(name: "review", template: "/review newer");
      final firstRefresh = Completer<SessionCommandsLoadResult>();
      final secondRefresh = Completer<SessionCommandsLoadResult>();
      final commandRefreshes = [firstRefresh, secondRefresh];
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [initialCommand]));
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer((_) => commandRefreshes.removeAt(0).future);

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      const event = SesoriSessionCommandsUpdated(
        sessionID: _sessionId,
        projectID: "project-1",
      );
      sessionEvents.add(event);
      await untilCalled(
        () => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode"),
      );
      sessionEvents.add(event);
      await pumpEventQueue();

      secondRefresh.complete(SessionCommandsLoadResult.loaded(commands: [newerCommand]));
      await _awaitLoadedWithCommandTemplate(cubit, template: "/review newer");
      firstRefresh.complete(SessionCommandsLoadResult.loaded(commands: [olderCommand]));
      await pumpEventQueue();

      expect((cubit.state as SessionDetailLoaded).availableCommands, [newerCommand]);
      verify(() => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode")).called(2);
    });

    test("command refresh is not overwritten by an older silent snapshot", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final initialCommand = testCommandInfo(name: "review", template: "/review initial");
      final staleCommand = testCommandInfo(name: "review", template: "/review stale");
      final refreshedCommand = testCommandInfo(name: "review", template: "/review refreshed");
      final snapshotRefresh = Completer<SessionDetailLoadResult>();
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [initialCommand]));
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: "project-1",
        ),
      ).thenAnswer((_) => snapshotRefresh.future);
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer(
        (_) async => SessionCommandsLoadResult.loaded(commands: [refreshedCommand]),
      );

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      mockConnectionService.emitDataMayBeStale();
      await untilCalled(
        () => mockLoadService.reload(sessionId: _sessionId, projectId: "project-1"),
      );

      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      await _awaitLoadedWithCommandTemplate(cubit, template: "/review refreshed");
      snapshotRefresh.complete(_loadedResult(commands: [staleCommand]));
      await pumpEventQueue();

      final state = cubit.state as SessionDetailLoaded;
      expect(state.availableCommands, [refreshedCommand]);
      expect(state.isRefreshing, isFalse);
    });

    test("waiting command refresh preserves the loaded state", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final command = testCommandInfo(name: "review", template: "/review");
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [command]));
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer((_) async => const SessionCommandsLoadResult.waitingForConnection());

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      cubit.stageCommand(command);
      final beforeRefresh = cubit.state;

      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      await untilCalled(
        () => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode"),
      );
      await pumpEventQueue();

      expect(cubit.state, same(beforeRefresh));
    });

    test("failed command refresh keeps state and logs the original error and stack", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final command = testCommandInfo(name: "review", template: "/review");
      final error = StateError("command catalog unavailable");
      final stackTrace = StackTrace.fromString("command-catalog-stack");
      final logs = <String>[];
      final stackLogged = Completer<void>();
      final previousLogLevel = logLevel;
      setLogLevel(LogLevel.warning);
      addTearDown(() => setLogLevel(previousLogLevel));
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [command]));
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer(
        (_) async => SessionCommandsLoadResult.failed(error: error, stackTrace: stackTrace),
      );

      final cubit = runZoned(
        () => createCubit(loadService: mockLoadService),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
            if (line == stackTrace.toString() && !stackLogged.isCompleted) {
              stackLogged.complete();
            }
          },
        ),
      );
      await _awaitLoaded(cubit);
      cubit.stageCommand(command);
      final beforeRefresh = cubit.state;

      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      await stackLogged.future.timeout(const Duration(seconds: 1));

      expect(cubit.state, same(beforeRefresh));
      expect(logs, contains("Session command refresh failed: ${error.toString()}"));
      expect(logs, contains(stackTrace.toString()));
    });

    test("command refresh completion after close does not alter state", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final command = testCommandInfo(name: "review", template: "/review");
      final commandLoad = Completer<SessionCommandsLoadResult>();
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) async => _loadedResult(commands: [command]));
      when(
        () => mockLoadService.loadCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer((_) => commandLoad.future);

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      final beforeRefresh = cubit.state;
      sessionEvents.add(
        const SesoriSessionCommandsUpdated(
          sessionID: _sessionId,
          projectID: "project-1",
        ),
      );
      await untilCalled(
        () => mockLoadService.loadCommands(projectId: "project-1", pluginId: "opencode"),
      );

      await cubit.close();
      commandLoad.complete(
        SessionCommandsLoadResult.loaded(
          commands: [testCommandInfo(name: "compact", template: "/compact")],
        ),
      );
      await pumpEventQueue();

      expect(cubit.state, same(beforeRefresh));
    });

    test("clears pending events when load fails", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit(loadService: mockLoadService);

      // Emit an event while loading
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
        time: null,
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
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => reloadedCompleter.future);

      unawaited(cubit.reload());

      reloadedCompleter.complete(
        const SessionDetailLoadResult.loaded(
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
      await _awaitLoaded(cubit);

      // The old buffered event should have been cleared on failure
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages, isEmpty);
    });

    test("events arriving during failed state are dropped, not buffered", () async {
      final mockLoadService = MockSessionDetailLoadService();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
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
        time: null,
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Now reload successfully
      final reloadedCompleter = Completer<SessionDetailLoadResult>();
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => reloadedCompleter.future);

      unawaited(cubit.reload());

      reloadedCompleter.complete(
        const SessionDetailLoadResult.loaded(
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
      await _awaitLoaded(cubit);

      // The event emitted during failed state should NOT have been replayed
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages, isEmpty);
    });

    test("processes events immediately and updates archive state", () async {
      final mockLoadService = MockSessionDetailLoadService();

      when(
        () => mockLoadService.load(
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

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      // Emit an event after already loaded
      const updatedMessage = Message.assistant(
        id: "msg-1",
        sessionID: _sessionId,
        agent: "build",
        modelID: "gpt-4",
        providerID: "openai",
        time: null,
      );
      sessionEvents.add(const SesoriMessageUpdated(info: updatedMessage));
      await Future<void>.delayed(Duration.zero);

      // Should be processed immediately
      final state = cubit.state as SessionDetailLoaded;
      expect(state.messages.length, 1);
      expect(state.messages.first.info.id, "msg-1");

      sessionEvents.add(
        SesoriSessionUpdated(
          info: testSession(
            id: _sessionId,
            archivedAt: DateTime.utc(2026),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as SessionDetailLoaded).isArchived, isTrue);

      sessionEvents.add(SesoriSessionUpdated(info: testSession(id: _sessionId)));
      await Future<void>.delayed(Duration.zero);

      expect((cubit.state as SessionDetailLoaded).isArchived, isFalse);
    });
    test("does not buffer irrelevant global events (PTY, file watcher, etc.)", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final completer = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
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

Future<void> _awaitLoadedWithCommand(
  SessionDetailCubit cubit, {
  required String command,
}) async {
  for (var i = 0; i < 100; i++) {
    final state = cubit.state;
    if (state is SessionDetailLoaded &&
        !state.isRefreshing &&
        state.availableCommands.any((item) => item.name == command)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail("Timed out waiting for '$command'; current state: ${cubit.state}");
}

Future<void> _awaitLoadedWithCommandTemplate(
  SessionDetailCubit cubit, {
  required String template,
}) async {
  for (var i = 0; i < 100; i++) {
    final state = cubit.state;
    if (state is SessionDetailLoaded && state.availableCommands.any((item) => item.template == template)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail("Timed out waiting for '$template'; current state: ${cubit.state}");
}

SessionDetailLoadResult _loadedResult({required List<CommandInfo> commands}) {
  return SessionDetailLoadResult.loaded(
    snapshot: SessionDetailSnapshot(
      projectId: "project-1",
      pluginId: "opencode",
      messages: const <MessageWithParts>[],
      pendingQuestions: const <PendingQuestion>[],
      pendingPermissions: const <PendingPermission>[],
      childSessions: const <Session>[],
      statuses: const <String, SessionStatus>{},
      agents: const <AgentInfo?>[],
      providerData: null,
      commands: commands,
      canonicalSessionTitle: null,
      promptDefaults: null,
      isRootSession: true,
      isArchived: false,
    ),
    isBridgeConnected: true,
  );
}
