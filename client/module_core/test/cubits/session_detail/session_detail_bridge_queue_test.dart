import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_notice.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

const _sessionId = "session-1";

/// The text part that makes [messageId] renderable — production user
/// envelopes are always followed by one.
SesoriMessagePartUpdated _textPartFor({required String messageId, required String text}) => SesoriMessagePartUpdated(
  part: MessagePart(
    id: "$messageId-text",
    sessionID: _sessionId,
    messageID: messageId,
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
  ),
);

const _queuedPrompt = QueuedSessionPrompt(
  id: "prm_1",
  text: "steer it",
  command: null,
  attachmentCount: 0,
  createdAt: 100,
);

SessionOptionsRepositoryResult _freshClaudeOptions() => SessionOptionsRepositoryAvailable(
  isStale: false,
  catalog: SessionOptionsCatalog(
    agents: const [
      AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
      AgentInfo(name: "Plan", description: "Plan", model: null, mode: AgentMode.primary),
    ],
    providers: const [],
    providersConnectedOnly: false,
    commands: const [],
  ),
);

ProviderListResponse _providerDataWithVariants(List<String> variants) => ProviderListResponse(
  items: [
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      defaultModelID: "claude-opus",
      models: {
        "claude-opus": ProviderModel(
          id: "claude-opus",
          providerID: "anthropic",
          name: "Opus",
          variants: variants,
          family: null,
          releaseDate: null,
        ),
      },
    ),
  ],
  connectedOnly: false,
);

SessionOptionsRepositoryResult _claudeOptionsWithVariants(List<String> variants) => SessionOptionsRepositoryAvailable(
  isStale: false,
  catalog: SessionOptionsCatalog(
    agents: const [
      AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
    ],
    providers: _providerDataWithVariants(variants).items,
    providersConnectedOnly: false,
    commands: const [],
  ),
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
    late List<MessageWithParts> reloadSnapshotMessages;

    setUp(() {
      reloadSnapshotMessages = const <MessageWithParts>[];
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
      List<AgentInfo> agents = const [],
      ProviderListResponse? providerData,
      SessionPromptDefaults? promptDefaults,
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
            agents: agents,
            providerData: providerData,
            commands: const <CommandInfo>[],
            canonicalSessionTitle: null,
            promptDefaults: promptDefaults,
            isRootSession: true,
            isArchived: false,
          ),
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
          snapshot: SessionDetailSnapshot(
            projectId: "project-1",
            pluginId: "claude",
            supportsPromptAttachments: false,
            messages: reloadSnapshotMessages,
            olderMessagesCursor: null,
            pendingQuestions: const <PendingQuestion>[],
            pendingPermissions: const <PendingPermission>[],
            bridgeQueuedPrompts: const <QueuedSessionPrompt>[],
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

    test("refreshes stale options and retries the queued submission with a supported agent", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      var sendCount = 0;
      final promptIds = <String>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          command: null,
        ),
      ).thenAnswer((invocation) async {
        sendCount++;
        promptIds.add(invocation.namedArguments[#promptId]! as String);
        return sendCount == 1 ? ApiResponse.error(staleError) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      expect(promptIds.toSet(), hasLength(1));
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: "Default",
          model: null,
          variant: null,
          command: null,
        ),
      ).called(1);
      verify(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: "Agent",
          model: null,
          variant: null,
          command: null,
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.selectedAgent, "Agent");
      expect(state.queuedMessages, isEmpty);
      expect(state.sendingSubmission, isNull);
      expect(state.awaitingBridgeSubmissions.map((submission) => submission.promptId), [promptIds.first]);
      expect(notices, [SessionDetailNotice.promptOptionsUpdated]);
    });

    test("parks the prompt after one stale-options recovery attempt", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _freshClaudeOptions());
      var sendCount = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          command: null,
        ),
      ).thenAnswer((_) async {
        sendCount++;
        return ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );
      final notices = <SessionDetailNotice>[];
      final noticeSubscription = cubit.noticeStream.listen(notices.add);
      addTearDown(noticeSubscription.cancel);

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      verify(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages.single.agent, "Agent");
      expect(state.sendingSubmission, isNull);
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(
        notices,
        [SessionDetailNotice.promptOptionsUpdated, SessionDetailNotice.promptOptionsRecoveryFailed],
      );
    });

    test("does not restart stale-options recovery after forced refresh fails", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude agent",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());
      var sendCount = 0;
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: any(named: "text"),
          attachments: const [],
          agent: any(named: "agent"),
          model: null,
          variant: null,
          command: null,
        ),
      ).thenAnswer((_) async {
        sendCount++;
        return ApiResponse.error(staleError);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Default", description: "Default", model: null, mode: AgentMode.primary),
        ],
        promptDefaults: const SessionPromptDefaults(agent: "Default", model: null),
      );

      await cubit.sendMessage(
        text: "first",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await cubit.sendMessage(
        text: "second",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await Future<void>.delayed(Duration.zero);

      expect(sendCount, 2);
      verify(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).called(1);
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages.map((submission) => submission.text), ["first", "second"]);
      expect(state.sendingSubmission, isNull);
      expect(state.awaitingBridgeSubmissions, isEmpty);
    });

    test("retries a withdrawn variant at a supported one rather than unsetting it", () async {
      final staleError = ApiError.nonSuccessCode(
        errorCode: 409,
        rawErrorString: jsonEncode(
          const SendPromptErrorResponse(
            code: SendPromptErrorCode.staleSessionOptions,
            message: "unsupported Claude effort",
          ).toJson(),
        ),
      );
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "claude",
          mode: SessionOptionsRequestMode.forceRefresh,
        ),
      ).thenAnswer((_) async => _claudeOptionsWithVariants(const ["low"]));
      var sendCount = 0;
      final sentVariants = <SessionVariant?>[];
      when(
        () => mockSessionRepository.sendMessage(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
          text: "hello",
          attachments: const [],
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: null,
        ),
      ).thenAnswer((invocation) async {
        sendCount++;
        sentVariants.add(invocation.namedArguments[#variant] as SessionVariant?);
        return sendCount == 1 ? ApiResponse.error(staleError) : ApiResponse.success(null);
      });
      final cubit = await createLoadedCubit(
        agents: const [
          AgentInfo(name: "Agent", description: "Agent", model: null, mode: AgentMode.primary),
        ],
        providerData: _providerDataWithVariants(const ["low", "high"]),
        promptDefaults: const SessionPromptDefaults(
          agent: "Agent",
          model: AgentModel(providerID: "anthropic", modelID: "claude-opus", variant: "high"),
        ),
      );
      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.variant, "high");

      await cubit.sendMessage(
        text: "hello",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      for (var attempt = 0; attempt < 20 && sendCount < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(sendCount, 2);
      // The composer renders the first available variant when none is
      // selected, so recovery must land on a real one instead of unsetting it.
      expect(sentVariants, const [SessionVariant(id: "high"), SessionVariant(id: "low")]);
      expect((cubit.state as SessionDetailLoaded).selectedAgentModel?.variant, "low");
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

    test("keeps the queued entry through the bare envelope and releases it on the first part", () async {
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

      // The envelope alone cannot render; dropping the entry now would blank
      // the row until its text part lands.
      var state = cubit.state as SessionDetailLoaded;
      expect(state.messages.single.info.id, "echo-1");
      expect(state.bridgeQueuedPrompts, const [_queuedPrompt]);

      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts, isEmpty);
      // The no-blank invariant: every emission renders the prompt somewhere —
      // a renderable message, the bridge entry, or a staged copy.
      for (final emitted in emissions.whereType<SessionDetailLoaded>()) {
        final renderableMessage = emitted.messages.any(
          (message) => message.info.id == "echo-1" && message.parts.any((part) => part.type == MessagePartType.text),
        );
        final queued = emitted.bridgeQueuedPrompts.any((prompt) => prompt.id == "prm_1");
        expect(
          renderableMessage || queued,
          isTrue,
          reason: "no frame may leave the prompt without a renderable source",
        );
      }
      await subscription.cancel();
    });

    test("an accepted send stays visible until the bridge queue lists it", () async {
      final send = Completer<ApiResponse<void>>();
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
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      final emissions = <SessionDetailState>[];
      final subscription = cubit.stream.listen(emissions.add);
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).sendingSubmission?.promptId;
      expect(promptId, isNotNull);

      // The acceptance response lands before the session.queued-prompts
      // event: the submission parks instead of vanishing.
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);
      var state = cubit.state as SessionDetailLoaded;
      expect(state.sendingSubmission, isNull);
      expect(state.awaitingBridgeSubmissions.map((item) => item.promptId), [promptId]);

      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(id: promptId ?? "", text: "steer it", command: null, attachmentCount: 0, createdAt: 1),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      state = cubit.state as SessionDetailLoaded;
      expect(state.awaitingBridgeSubmissions, isEmpty);
      expect(state.bridgeQueuedPrompts.map((prompt) => prompt.id), [promptId]);

      // The no-blank invariant: every emission after the send renders the
      // prompt from at least one surface.
      for (final emitted in emissions.whereType<SessionDetailLoaded>()) {
        final visible =
            emitted.sendingSubmission?.promptId == promptId ||
            emitted.queuedMessages.any((item) => item.promptId == promptId) ||
            emitted.awaitingBridgeSubmissions.any((item) => item.promptId == promptId) ||
            emitted.bridgeQueuedPrompts.any((prompt) => prompt.id == promptId);
        expect(visible, isTrue, reason: "no frame may leave the accepted send without a surface");
      }
      await subscription.cancel();
    });

    test("a send whose entry was consumed before its response settles on its echo", () async {
      final send = Completer<ApiResponse<void>>();
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
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).sendingSubmission!.promptId;

      // An immediately dispatched steering send: the bridge consumed the entry
      // and published the resulting queue before the acceptance response
      // travelled back, so the only statement this client sees omits the
      // prompt entirely.
      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);
      // The dispatched prompt's own message is what accounts for the row.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 300, completed: null),
            promptId: promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(
        state.awaitingBridgeSubmissions,
        isEmpty,
        reason: "the delivered echo replaced the parked copy; leaving it strands a bubble",
      );
      expect(state.sendingSubmission, isNull);
      expect(state.queuedMessages, isEmpty);
    });

    test("a bridge-stamped harness echo settles the parked send", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(
        text: "steer it",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      );
      await Future<void>.delayed(Duration.zero);
      final parked = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single;

      // Codex and OpenCode author no prompt id of their own; the bridge stamps
      // its dispatch onto their echo so the client can still correlate it.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: parked.promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions,
        isEmpty,
        reason: "the stamped echo replaced the copy it belongs to",
      );
    });

    test("a multi-part echo settles exactly one parked send", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "first", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await cubit.sendMessage(text: "second", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      final parked = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions;
      expect(parked, hasLength(2));

      // One echo, several updates: the envelope and each of its parts. Only
      // the first may settle a send.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: parked.first.promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first"));
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first (edited)"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.text),
        ["second"],
        reason: "later updates of one echo must not retire further sends",
      );
    });

    test("another surface's echo leaves this client's parked send alone", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();

      await cubit.sendMessage(text: "mine", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      // Another surface's prompt lands while this client's own copy is parked.
      sessionEvents.add(
        const SesoriMessageUpdated(
          info: Message.user(
            id: "other-1",
            sessionID: _sessionId,
            agent: null,
            time: MessageTime(created: 100, completed: null),
            promptId: null,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "other-1", text: "from another device"));
      await Future<void>.delayed(Duration.zero);

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.text),
        ["mine"],
        reason: "a foreign echo carries different text and must not retire this copy",
      );
    });

    test("an echo that outruns its acceptance response prevents parking", () async {
      final send = Completer<ApiResponse<void>>();
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
      ).thenAnswer((_) => send.future);
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final inFlight = (cubit.state as SessionDetailLoaded).sendingSubmission!.promptId;

      // A queue-less harness echoes at acceptance, so the stamped message can
      // land before the acceptance response completes.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 200, completed: null),
            promptId: inFlight,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "steer it"));
      await Future<void>.delayed(Duration.zero);
      send.complete(ApiResponse.success(null));
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.awaitingBridgeSubmissions, isEmpty, reason: "the echo already renders this prompt");
      expect(state.sendingSubmission, isNull);
      expect(state.messages.single.info.id, "echo-1");
    });

    test("an authoritative refresh settles a parked prompt the bridge no longer owns", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "lost", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      // A refresh whose fetch began after the park returns neither the queue
      // entry nor the message: the prompt is gone bridge-side, so the parked
      // ghost settles instead of rendering forever.
      await cubit.reload();

      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
    });

    test("a snapshot holding only the bare envelope keeps the parked bubble", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "steer", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.single.promptId;

      // The refresh carries the delivered message as a bare envelope: it
      // cannot render, so the parked copy must survive rather than be settled
      // as absent — otherwise the row blanks until the first part lands.
      reloadSnapshotMessages = [
        MessageWithParts(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 500, completed: null),
            promptId: promptId,
          ),
          parts: const <MessagePart>[],
        ),
      ];
      await cubit.reload();

      expect(
        (cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions.map((item) => item.promptId),
        [promptId],
      );
    });

    test("abort clears a parked-only submission", () async {
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
      ).thenAnswer((_) async => ApiResponse.success(null));
      when(() => mockSessionRepository.abortSession(sessionId: _sessionId)).thenAnswer(
        (_) async => ApiResponse.success(null),
      );
      final cubit = await createLoadedCubit();
      await cubit.sendMessage(text: "parked", command: null, inputMode: ComposerInputMode.typed, attachments: const []);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, hasLength(1));

      await cubit.abort();

      expect((cubit.state as SessionDetailLoaded).awaitingBridgeSubmissions, isEmpty);
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
      sessionEvents.add(_textPartFor(messageId: "echo-first", text: "first"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(laterSends, ["second"]);
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("a cancelled prompt does not resurrect from its late transport failure", () async {
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
      when(
        () => mockSessionRepository.cancelQueuedPrompt(
          sessionId: _sessionId,
          promptId: any(named: "promptId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(null));
      final cubit = await createLoadedCubit();
      unawaited(
        cubit.sendMessage(text: "steer it", command: null, inputMode: ComposerInputMode.typed, attachments: const []),
      );
      await Future<void>.delayed(Duration.zero);
      final promptId = (cubit.state as SessionDetailLoaded).sendingSubmission?.promptId;
      expect(promptId, isNotNull);

      // Accepted by the bridge while the response is still in flight...
      sessionEvents.add(
        SesoriSseEvent.sessionQueuedPrompts(
          sessionID: _sessionId,
          prompts: [
            QueuedSessionPrompt(id: promptId ?? "", text: "steer it", command: null, attachmentCount: 0, createdAt: 1),
          ],
        ) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      // ...then cancelled from this client...
      await cubit.cancelBridgeQueuedPrompt(promptId: promptId ?? "");
      sessionEvents.add(
        const SesoriSseEvent.sessionQueuedPrompts(sessionID: _sessionId, prompts: []) as SesoriSessionEvent,
      );
      await Future<void>.delayed(Duration.zero);
      // ...and only then does the original send fail at the transport layer.
      sendCompleter.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = cubit.state as SessionDetailLoaded;
      expect(state.bridgeQueuedPrompts, isEmpty);
      expect(state.queuedMessages, isEmpty, reason: "the cancelled prompt must not requeue locally");
      expect(state.sendingSubmission, isNull);
      verify(
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
      ).called(1);
    });

    test("a snapshot already holding the prompt's message discards the in-flight send and drains on", () async {
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
      final promptId = (cubit.state as SessionDetailLoaded).sendingSubmission?.promptId;
      expect(promptId, isNotNull);

      // The prompt already dispatched: its message arrives (queue no longer
      // lists it), then the acceptance response is lost.
      sessionEvents.add(
        SesoriMessageUpdated(
          info: Message.user(
            id: "echo-1",
            sessionID: _sessionId,
            agent: null,
            time: const MessageTime(created: 400, completed: null),
            promptId: promptId,
          ),
        ),
      );
      sessionEvents.add(_textPartFor(messageId: "echo-1", text: "first"));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as SessionDetailLoaded).sendingSubmission, isNull);
      firstSend.completeError(Exception("response lost"));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(laterSends, ["second"], reason: "the staged send behind the settled one must dispatch");
      final state = cubit.state as SessionDetailLoaded;
      expect(state.queuedMessages, isEmpty);
      expect(state.sendingSubmission, isNull);
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
