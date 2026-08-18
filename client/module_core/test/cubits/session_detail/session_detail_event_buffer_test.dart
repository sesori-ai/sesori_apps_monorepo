import "dart:async";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
        lastUserActivityAt: null,
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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

    test("refreshes only commands when a catalog update arrives during loading", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final loadCompleter = Completer<SessionDetailLoadResult>();

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => loadCompleter.future);
      when(
        () => mockSessionRepository.listCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          CommandListResponse(
            items: [testCommandInfo(name: "compact", template: "/compact")],
          ),
        ),
      );

      final cubit = createCubit(loadService: mockLoadService);
      globalEvents.add(
        SseEvent(data: const SesoriCommandCatalogUpdated(pluginId: "cursor")),
      );
      globalEvents.add(
        SseEvent(data: const SesoriCommandCatalogUpdated(pluginId: "opencode")),
      );
      await Future<void>.delayed(Duration.zero);

      loadCompleter.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
            pluginId: "opencode",
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
      verify(
        () => mockSessionRepository.listCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).called(1);
      verifyNever(
        () => mockSessionRepository.listCommands(
          projectId: "project-1",
          pluginId: "cursor",
        ),
      );
      verifyNever(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      );
    });

    test("keeps the newest command catalog when refreshes finish out of order", () async {
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
      final responses = <Completer<ApiResponse<CommandListResponse>>>[];
      when(
        () => mockSessionRepository.listCommands(
          projectId: "project-1",
          pluginId: "opencode",
        ),
      ).thenAnswer((_) {
        final response = Completer<ApiResponse<CommandListResponse>>();
        responses.add(response);
        return response.future;
      });

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      globalEvents.add(
        SseEvent(data: const SesoriCommandCatalogUpdated(pluginId: "opencode")),
      );
      await _awaitCondition(() => responses.length == 1);
      globalEvents.add(
        SseEvent(data: const SesoriCommandCatalogUpdated(pluginId: "opencode")),
      );
      await _awaitCondition(() => responses.length == 2);

      responses[1].complete(
        ApiResponse.success(
          CommandListResponse(
            items: [testCommandInfo(name: "newest", template: "/newest")],
          ),
        ),
      );
      await _awaitLoadedWithCommand(cubit, command: "newest");
      responses[0].complete(
        ApiResponse.success(
          CommandListResponse(
            items: [testCommandInfo(name: "stale", template: "/stale")],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.availableCommands.map((command) => command.name), ["newest"]);
    });

    test("silent refresh fails closed when attachment support is unresolved", () async {
      final mockLoadService = MockSessionDetailLoadService();
      SessionDetailSnapshot snapshot({required bool? supportsPromptAttachments}) {
        return SessionDetailSnapshot(
          projectId: "project-1",
          pluginId: "codex",
          supportsPromptAttachments: supportsPromptAttachments,
          messages: const <MessageWithParts>[],
          olderMessagesCursor: null,
          pendingQuestions: const <PendingQuestion>[],
          pendingPermissions: const <PendingPermission>[],
          childSessions: const <Session>[],
          statuses: const <String, SessionStatus>{},
          agents: const <AgentInfo?>[],
          providerData: null,
          commands: const <CommandInfo>[],
          canonicalSessionTitle: null,
          promptDefaults: null,
          isRootSession: true,
          isArchived: false,
        );
      }

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => SessionDetailLoadResult.loaded(
          snapshot: snapshot(supportsPromptAttachments: true),
          isBridgeConnected: true,
        ),
      );
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => SessionDetailLoadResult.loaded(
          snapshot: snapshot(supportsPromptAttachments: null),
          isBridgeConnected: true,
        ),
      );

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      expect((cubit.state as SessionDetailLoaded).supportsPromptAttachments, isTrue);

      mockConnectionService.emitDataMayBeStale();
      await untilCalled(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      );
      for (var i = 0; i < 100; i++) {
        final state = cubit.state;
        if (state is SessionDetailLoaded && !state.isRefreshing) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final refreshed = cubit.state as SessionDetailLoaded;
      expect(refreshed.isRefreshing, isFalse);
      expect(refreshed.supportsPromptAttachments, isNull);
    });

    test("queued attachment waits for a current capability load after reconnect", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final refreshes = <Completer<SessionDetailLoadResult>>[];
      const snapshot = SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "codex",
        supportsPromptAttachments: true,
        messages: <MessageWithParts>[],
        olderMessagesCursor: null,
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
      );
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) {
        final refresh = Completer<SessionDetailLoadResult>();
        refreshes.add(refresh);
        return refresh.future;
      });
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async {
        sendCalls++;
        return sendCalls == 1 ? ApiResponse<void>.error(ApiError.generic()) : ApiResponse<void>.success(null);
      });

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      await cubit.sendMessage(
        text: "look at this",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: [
          ComposerAttachment(
            mime: "image/png",
            bytes: Uint8List(1),
            filename: "shot.png",
          ),
        ],
      );
      expect(sendCalls, 1);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, hasLength(1));

      unawaited(cubit.reload());
      await _awaitCondition(() => refreshes.length == 1);
      connectionStatus.add(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<SessionDetailLoading>());

      connectionStatus.add(connectedStatus);
      expect(sendCalls, 1);

      refreshes.first.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      await _awaitCondition(() => refreshes.length == 2);
      expect(sendCalls, 1);

      refreshes[1].complete(
        const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      for (var i = 0; i < 100 && sendCalls < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(sendCalls, 2);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("connected send stays visible until the bridge accepts it", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final accepted = Completer<ApiResponse<void>>();
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) => accepted.future);

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      final send = cubit.sendMessage(
        text: "Cold-start prompt",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await _awaitCondition(() {
        final state = cubit.state;
        return state is SessionDetailLoaded && state.sendingSubmission?.displayText == "Cold-start prompt";
      });

      var state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages, isEmpty);
      expect(state.sendingSubmission?.displayText, "Cold-start prompt");

      accepted.complete(ApiResponse.success(null));
      await send;

      state = cubit.state as SessionDetailLoaded;
      expect(state.sendingSubmission, isNull);
      expect(state.queuedMessages, isEmpty);
    });

    test("a send failed after reconnect is retried on the replacement connection", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final firstAttempt = Completer<ApiResponse<void>>();
      const snapshot = SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "opencode",
        supportsPromptAttachments: false,
        messages: <MessageWithParts>[],
        olderMessagesCursor: null,
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
      );
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) {
        sendCalls++;
        return sendCalls == 1 ? firstAttempt.future : Future.value(ApiResponse.success(null));
      });

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      unawaited(
        cubit.sendMessage(
          text: "Retry me",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        ),
      );
      await _awaitCondition(() => sendCalls == 1);

      connectionStatus.add(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      connectionStatus.add(connectedStatus);
      await Future<void>.delayed(Duration.zero);
      expect(sendCalls, 1);

      firstAttempt.complete(ApiResponse.error(ApiError.generic()));
      await _awaitCondition(() => sendCalls == 2);

      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("stale pre-disconnect refresh cannot authorize a queued attachment", () async {
      final mockLoadService = MockSessionDetailLoadService();
      const supportedSnapshot = SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "codex",
        supportsPromptAttachments: true,
        messages: <MessageWithParts>[],
        olderMessagesCursor: null,
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
      );
      const unsupportedSnapshot = SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "codex",
        supportsPromptAttachments: false,
        messages: <MessageWithParts>[],
        olderMessagesCursor: null,
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
      );
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: supportedSnapshot,
          isBridgeConnected: true,
        ),
      );
      final refreshes = <Completer<SessionDetailLoadResult>>[];
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) {
        final refresh = Completer<SessionDetailLoadResult>();
        refreshes.add(refresh);
        return refresh.future;
      });
      var sendCalls = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((_) async {
        sendCalls++;
        return sendCalls == 1 ? ApiResponse<void>.error(ApiError.generic()) : ApiResponse<void>.success(null);
      });

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      await cubit.sendMessage(
        text: "look at this",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: [
          ComposerAttachment(
            mime: "image/png",
            bytes: Uint8List(1),
            filename: "shot.png",
          ),
        ],
      );
      expect(sendCalls, 1);

      mockConnectionService.emitDataMayBeStale();
      await _awaitCondition(() => refreshes.length == 1);
      connectionStatus.add(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      connectionStatus.add(connectedStatus);

      refreshes.first.complete(
        const SessionDetailLoadResult.loaded(
          snapshot: supportedSnapshot,
          isBridgeConnected: true,
        ),
      );
      await _awaitCondition(() => refreshes.length == 2);
      expect(sendCalls, 1);
      expect((cubit.state as SessionDetailLoaded).supportsPromptAttachments, isNull);

      refreshes[1].complete(
        const SessionDetailLoadResult.loaded(
          snapshot: unsupportedSnapshot,
          isBridgeConnected: true,
        ),
      );
      await _awaitCondition(() {
        final state = cubit.state;
        return state is SessionDetailLoaded && !state.isRefreshing;
      });

      expect(sendCalls, 1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.supportsPromptAttachments, isFalse);
      expect(state.queuedMessages, hasLength(1));

      await cubit.sendMessage(
        text: "continue without the image",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      expect(sendCalls, 1);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, hasLength(2));

      cubit.cancelQueuedMessage(0);
      await _awaitCondition(() => sendCalls == 2);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("stale pre-disconnect failure cannot overwrite the reconnect load", () async {
      final mockLoadService = MockSessionDetailLoadService();
      const snapshot = SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "codex",
        supportsPromptAttachments: true,
        messages: <MessageWithParts>[],
        olderMessagesCursor: null,
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
      );
      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      final refreshes = <Completer<SessionDetailLoadResult>>[];
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) {
        final refresh = Completer<SessionDetailLoadResult>();
        refreshes.add(refresh);
        return refresh.future;
      });

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      unawaited(cubit.reload());
      await _awaitCondition(() => refreshes.length == 1);
      connectionStatus.add(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token"),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      connectionStatus.add(connectedStatus);

      refreshes.first.complete(
        SessionDetailLoadResult.failed(
          error: ApiError.generic(),
          stackTrace: StackTrace.current,
        ),
      );
      await _awaitCondition(() => refreshes.length == 2);
      expect(cubit.state, isA<SessionDetailLoading>());

      refreshes[1].complete(
        const SessionDetailLoadResult.loaded(
          snapshot: snapshot,
          isBridgeConnected: true,
        ),
      );
      await _awaitLoaded(cubit);
      expect((cubit.state as SessionDetailLoaded).supportsPromptAttachments, isTrue);
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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

    test("refresh supersedes older deferred parts and retains in-flight events", () async {
      final mockLoadService = MockSessionDetailLoadService();
      final refresh = Completer<SessionDetailLoadResult>();

      MessagePart textPart({required String id, required String text}) => MessagePart(
        id: id,
        sessionID: _sessionId,
        messageID: "message-1",
        type: MessagePartType.text,
        text: text,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: null,
      );

      SessionDetailSnapshot snapshot({required List<MessageWithParts> messages}) => SessionDetailSnapshot(
        projectId: "project-1",
        pluginId: "opencode",
        supportsPromptAttachments: false,
        messages: messages,
        olderMessagesCursor: null,
        pendingQuestions: const <PendingQuestion>[],
        pendingPermissions: const <PendingPermission>[],
        childSessions: const <Session>[],
        statuses: const <String, SessionStatus>{},
        agents: const <AgentInfo?>[],
        providerData: null,
        commands: const <CommandInfo>[],
        canonicalSessionTitle: null,
        promptDefaults: null,
        isRootSession: true,
        isArchived: false,
      );

      when(
        () => mockLoadService.load(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer(
        (_) async => SessionDetailLoadResult.loaded(
          snapshot: snapshot(messages: const []),
          isBridgeConnected: true,
        ),
      );
      when(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      ).thenAnswer((_) => refresh.future);

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);

      sessionEvents.add(
        SesoriMessagePartUpdated(
          part: textPart(id: "part-before-refresh", text: "stale"),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      mockConnectionService.emitDataMayBeStale();
      await untilCalled(
        () => mockLoadService.reload(
          sessionId: _sessionId,
          projectId: any(named: "projectId"),
        ),
      );

      sessionEvents.add(
        SesoriMessagePartUpdated(
          part: textPart(id: "part-during-refresh", text: "live"),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final snapshotPart = textPart(id: "part-before-refresh", text: "fresh snapshot");
      refresh.complete(
        SessionDetailLoadResult.loaded(
          snapshot: snapshot(
            messages: [
              MessageWithParts(
                info: const Message.user(
                  promptId: null,
                  id: "message-1",
                  sessionID: _sessionId,
                  agent: "build",
                  time: MessageTime(created: 100, completed: null),
                ),
                parts: [snapshotPart],
              ),
            ],
          ),
          isBridgeConnected: true,
        ),
      );
      await _awaitCondition(() {
        final state = cubit.state;
        return state is SessionDetailLoaded && !state.isRefreshing && state.messages.single.parts.length == 2;
      });

      final parts = (cubit.state as SessionDetailLoaded).messages.single.parts;
      expect(parts.map((part) => (part.id, part.text)), [
        ("part-before-refresh", "fresh snapshot"),
        ("part-during-refresh", "live"),
      ]);
    });

    test("keeps a finalized part that arrives before its message envelope", () async {
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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

      const part = MessagePart(
        id: "part-1",
        sessionID: _sessionId,
        messageID: "message-1",
        type: MessagePartType.text,
        text: "Keep this prompt",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: null,
      );
      sessionEvents.add(const SesoriMessagePartUpdated(part: part));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).messages, isEmpty);

      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            promptId: null,
            id: "message-1",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final message = (cubit.state as SessionDetailLoaded).messages.single;
      expect(message.info.id, "message-1");
      expect(message.parts, [part]);
    });

    test("applies the latest deferred update without changing part order", () async {
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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

      MessagePart part({required String id, required String text}) => MessagePart(
        id: id,
        sessionID: _sessionId,
        messageID: "message-1",
        type: MessagePartType.text,
        text: text,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: null,
      );

      final cubit = createCubit(loadService: mockLoadService);
      await _awaitLoaded(cubit);
      sessionEvents.add(
        SesoriMessagePartUpdated(
          part: part(id: "part-a", text: "old"),
        ),
      );
      sessionEvents.add(
        SesoriMessagePartUpdated(
          part: part(id: "part-b", text: "second"),
        ),
      );
      sessionEvents.add(
        SesoriMessagePartUpdated(
          part: part(id: "part-a", text: "new"),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            promptId: null,
            id: "message-1",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final parts = (cubit.state as SessionDetailLoaded).messages.single.parts;
      expect(parts.map((item) => item.id), ["part-a", "part-b"]);
      expect(parts.map((item) => item.text), ["new", "second"]);
    });

    test("inserts late message envelopes by transcript time", () async {
      final mockLoadService = MockSessionDetailLoadService();
      const newest = MessageWithParts(
        info: Message.assistant(
          id: "message-3",
          sessionID: _sessionId,
          agent: "build",
          modelID: "gpt-4",
          providerID: "openai",
          time: MessageTime(created: 300, completed: null),
        ),
        parts: <MessagePart>[],
      );
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[newest],
            olderMessagesCursor: null,
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
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            promptId: null,
            id: "message-1",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
        ),
      );
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.assistant(
            id: "message-2",
            sessionID: _sessionId,
            agent: "build",
            modelID: "gpt-4",
            providerID: "openai",
            time: MessageTime(created: 200, completed: null),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).messages.map((message) => message.info.id),
        ["message-1", "message-2", "message-3"],
      );
    });

    test("appends a late envelope when its timestamp ties existing messages", () async {
      final mockLoadService = MockSessionDetailLoadService();
      const assistant = MessageWithParts(
        info: Message.assistant(
          id: "a-assistant",
          sessionID: _sessionId,
          agent: "build",
          modelID: "gpt-4",
          providerID: "openai",
          time: MessageTime(created: 100, completed: null),
        ),
        parts: <MessagePart>[],
      );
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[assistant],
            olderMessagesCursor: null,
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
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            promptId: null,
            id: "z-user",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).messages.map((message) => message.info.id),
        ["a-assistant", "z-user"],
      );
    });

    test("appends a later same-time user envelope after an existing turn", () async {
      final mockLoadService = MockSessionDetailLoadService();
      const messages = <MessageWithParts>[
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "user-1",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
          parts: <MessagePart>[],
        ),
        MessageWithParts(
          info: Message.assistant(
            id: "assistant-1",
            sessionID: _sessionId,
            agent: "build",
            modelID: "gpt-4",
            providerID: "openai",
            time: MessageTime(created: 100, completed: null),
          ),
          parts: <MessagePart>[],
        ),
      ];
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
            supportsPromptAttachments: false,
            messages: messages,
            olderMessagesCursor: null,
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
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            promptId: null,
            id: "user-2",
            sessionID: _sessionId,
            agent: "build",
            time: MessageTime(created: 100, completed: null),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).messages.map((message) => message.info.id),
        ["user-1", "assistant-1", "user-2"],
      );
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
            supportsPromptAttachments: false,
            messages: <MessageWithParts>[],
            olderMessagesCursor: null,
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

Future<void> _awaitCondition(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail("Timed out waiting for condition");
}
