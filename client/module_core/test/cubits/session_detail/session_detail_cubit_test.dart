import "dart:async";
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_abort_outcome.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/session_interaction_state.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/models/session_abort_rejected_exception.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/plugin_management_service.dart";
import "package:sesori_dart_core/src/services/project_viewing_service.dart";
import "package:sesori_dart_core/src/services/session_abort_service.dart";
import "package:sesori_dart_core/src/services/session_detail_load_service.dart";
import "package:sesori_dart_core/src/services/session_interaction_calculator.dart";
import "package:sesori_dart_core/src/services/session_viewing_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "../../services/session_interaction_calculator_test.dart" show managementFixture;

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockPluginRepository() extends Mock implements PluginRepository;

void main() {
  const sessionId = "session-1";

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(NotificationCategory.aiInteraction);
    registerFallbackValue(PermissionReply.once);
  });

  group("SessionDetailCubit", () {
    late MockSessionRepository mockSessionService;
    late MockSessionRepository mockSessionRepository;
    late MockPluginRepository mockPluginRepository;
    late MockProjectRepository mockProjectRepository;
    late MockConnectionService mockConnectionService;
    late MockNotificationCanceller mockNotificationCanceller;
    late MockPermissionRepository mockPermissionRepository;
    late MockFailureReporter mockFailureReporter;
    late MockProductAnalyticsService mockProductAnalyticsService;
    late SessionDetailLoadService loadService;
    late SessionRepository promptDispatcher;
    late BehaviorSubject<SesoriSessionEvent> sessionEvents;
    late BehaviorSubject<SseEvent> globalEvents;
    late BehaviorSubject<ConnectionStatus> connectionStatus;

    setUp(() {
      mockSessionService = MockSessionRepository();
      mockSessionRepository = MockSessionRepository();
      mockPluginRepository = MockPluginRepository();
      mockProjectRepository = MockProjectRepository();
      mockConnectionService = MockConnectionService();
      mockNotificationCanceller = MockNotificationCanceller();
      mockPermissionRepository = MockPermissionRepository();
      mockFailureReporter = MockFailureReporter();
      mockProductAnalyticsService = MockProductAnalyticsService();
      stubProductAnalyticsService(service: mockProductAnalyticsService);
      _stubPromptAttachmentCapability(
        repository: mockPluginRepository,
        pluginId: "plugin-1",
        supportsPromptAttachments: false,
      );
      loadService = SessionDetailLoadService(
        repository: mockSessionRepository,
        pluginRepository: mockPluginRepository,
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

      delegateSessionRepository(repository: mockSessionRepository, source: mockSessionService);
      stubSessionRepositoryGetSession(repository: mockSessionRepository, sessionId: sessionId);
      when(() => mockProjectRepository.findSessionContext(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => const ProjectSessionContext(
          projectId: "test-project",
          pluginId: "plugin-1",
          sessionTitle: null,
        ),
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

    /// Builds the cubit under test with the collaborators every case shares.
    ///
    /// Only the viewing services and the lifecycle source differ between cases,
    /// so each test names just the seam it exercises.
    SessionDetailCubit buildCubit({
      bool claimProjectView = true,
      SessionViewingService? sessionViewingService,
      ProjectViewingService? projectViewingService,
      LifecycleSource? lifecycleSource,
      PluginManagementService? pluginManagementService,
    }) => SessionDetailCubit(
      mockConnectionService,
      claimProjectView: claimProjectView,
      pluginManagementService: pluginManagementService ?? stubbedPluginManagementService(),
      interactionCalculator: const SessionInteractionCalculator(),
      loadService: loadService,
      sessionAbortService: SessionAbortService(repository: promptDispatcher),
      promptDispatcher: promptDispatcher,
      permissionRepository: mockPermissionRepository,
      sessionViewingService: sessionViewingService ?? stubbedSessionViewingService(),
      projectViewingService: projectViewingService ?? stubbedProjectViewingService(),
      lifecycleSource: lifecycleSource ?? MockLifecycleSource(),
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: mockProductAnalyticsService,
      sessionId: sessionId,
      projectId: "project-1",
      notificationCanceller: mockNotificationCanceller,
      failureReporter: mockFailureReporter,
    );

    tearDown(() async {
      await sessionEvents.close();
      await globalEvents.close();
      await connectionStatus.close();
    });

    for (final initialBlocked in [true, false]) {
      test("harness gate blocks input and restores interaction (cold: $initialBlocked)", () async {
        PluginManagementLoadResult management({required bool blocked}) => managementFixture(
          pluginId: "plugin-1",
          setup: blocked ? PluginSetupState.authenticationRequired : PluginSetupState.ready,
          runtime: blocked ? PluginRuntimeState.blocked : PluginRuntimeState.dormant,
        );
        final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(management(blocked: initialBlocked));
        addTearDown(snapshots.close);
        final service = MockPluginManagementService();
        when(() => service.snapshots).thenAnswer((_) => snapshots);
        when(service.refresh).thenAnswer((_) async {});
        final cubit = buildCubit(pluginManagementService: service);
        addTearDown(cubit.close);
        await awaitState(
          cubit: cubit,
          predicate: (state) =>
              state is SessionDetailLoaded && state.interaction.canInteract != initialBlocked,
          description: "initial harness state",
        );
        final before = cubit.state;
        if (initialBlocked) {
          // History comes from the bridge database, so a blocked harness still
          // shows the transcript; only interaction is refused.
          verify(
            () => mockSessionService.getMessages(
              sessionId: any(named: "sessionId"),
              limit: any(named: "limit"),
              before: any(named: "before"),
              storedOnly: any(named: "storedOnly"),
            ),
          ).called(greaterThanOrEqualTo(1));
        } else {
          when(
            () => mockSessionService.sendMessage(
              promptId: any(named: "promptId"),
              attachments: const [],
              sessionId: sessionId,
              text: any(named: "text"),
              agent: any(named: "agent"),
              model: any(named: "model"),
              variant: any(named: "variant"),
              command: null,
            ),
          ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
          await cubit.sendMessage(
            text: "cancel locally",
            command: null,
            inputMode: ComposerInputMode.typed,
            attachments: const [],
          );
          expect((cubit.state as SessionDetailLoaded).queuedMessages, hasLength(1));
          final savedMetadata = await mockSessionRepository.getSession(sessionId: sessionId);
          final metadata = Completer<ApiResponse<Session>>();
          when(() => mockSessionRepository.getSession(sessionId: sessionId)).thenAnswer((_) => metadata.future);
          final reloading = cubit.reload();
          expect(cubit.state, isA<SessionDetailLoading>());
          snapshots.add(management(blocked: true));
          sessionEvents.add(const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.busy()));
          metadata.complete(savedMetadata);
          await reloading;
          when(() => mockSessionRepository.getSession(sessionId: sessionId)).thenAnswer((_) async => savedMetadata);
          await awaitState(
            cubit: cubit,
            predicate: (state) => state is SessionDetailLoaded && !state.interaction.canInteract,
            description: "live block",
          );
          expect((cubit.state as SessionDetailLoaded).messages, (before as SessionDetailLoaded).messages);
          expect((cubit.state as SessionDetailLoaded).sessionStatus, const SessionStatus.busy());
          cubit.cancelQueuedMessage(0);
          expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
          await cubit.cancelBridgeQueuedPrompt(promptId: "remote-prompt");
          verifyNever(() => mockSessionRepository.cancelQueuedPrompt(sessionId: sessionId, promptId: "remote-prompt"));
        }
        clearInteractions(mockSessionRepository);
        clearInteractions(mockPermissionRepository);
        clearInteractions(mockProductAnalyticsService);
        final blockedState = cubit.state;
        cubit.selectAgent("coder");
        cubit.selectModel(providerID: "blocked-provider", modelID: "blocked-model");
        cubit.selectVariant(const SessionVariant(id: "blocked-variant"));
        cubit.stageCommand(testCommandInfo());
        cubit.clearStagedCommand();
        await cubit.loadOlderMessages();
        await cubit.sendMessage(
          text: "must not send",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: const [],
        );
        expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop), isA<SessionAbortFailed>());
        verifyNever(
          () => mockSessionRepository.abortSession(sessionId: sessionId, subAgents: SessionAbortSubAgentPolicy.stop),
        );
        expect(await cubit.replyToQuestion(requestId: "question", sessionId: sessionId, answers: const []), isFalse);
        expect(
          await cubit.replyToPermission(requestId: "permission", sessionId: sessionId, reply: PermissionReply.once),
          isFalse,
        );
        verifyNever(
          () => mockPermissionRepository.replyToPermission(
            requestId: any(named: "requestId"),
            sessionId: any(named: "sessionId"),
            reply: any(named: "reply"),
          ),
        );
        expect(await cubit.rejectQuestion("question"), isFalse);
        verifyNever(
          () => mockSessionRepository.rejectQuestion(
            requestId: any(named: "requestId"),
            sessionId: any(named: "sessionId"),
          ),
        );
        verifyNever(
          () => mockSessionRepository.sendMessage(
            promptId: any(named: "promptId"),
            attachments: any(named: "attachments"),
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
          ),
        );
        verifyNever(
          () => mockProductAnalyticsService.logEvent(
            event: any(named: "event"),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        );
        expect(cubit.state, same(blockedState));
        if (cubit.state case SessionDetailLoaded(:final queuedMessages)) expect(queuedMessages, isEmpty);
        if (!initialBlocked) {
          final saved = await mockSessionService.getMessages(
            sessionId: sessionId,
            limit: SessionDetailLoadService.initialPageSize,
            before: null,
            storedOnly: false,
          );
          when(
            () => mockSessionService.getMessages(
              sessionId: sessionId,
              limit: SessionDetailLoadService.initialPageSize,
              before: null,
              storedOnly: false,
            ),
          ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
          snapshots.add(management(blocked: false));
          await awaitState(
            cubit: cubit,
            predicate: (state) =>
                state is SessionDetailLoaded &&
                state.interaction is SessionInteractionBlocked &&
                (state.interaction as SessionInteractionBlocked).reason ==
                    SessionInteractionBlockedReason.contentLoadFailed,
            description: "recovery refresh failure",
          );
          expect((cubit.state as SessionDetailLoaded).messages, (before as SessionDetailLoaded).messages);
          when(
            () => mockSessionService.getMessages(
              sessionId: sessionId,
              limit: SessionDetailLoadService.initialPageSize,
              before: null,
              storedOnly: false,
            ),
          ).thenAnswer((_) async => saved);
          await cubit.recheckHarnessAvailability();
        } else {
          snapshots.add(management(blocked: false));
        }
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.interaction.canInteract && !state.isRefreshing,
          description: "available without reopening",
        );
        expect((cubit.state as SessionDetailLoaded).interaction, isA<SessionInteractionAvailable>());
      });
    }

    test("recovered options replace the placeholder agent the blocked load showed", () async {
      // A blocked open with no options cache has no catalog to select from and
      // falls back to a placeholder name. Carrying that into the enabled
      // composer would arm the next prompt with an agent the plugin never
      // advertised.
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        ),
      );
      addTearDown(snapshots.close);
      final service = MockPluginManagementService();
      when(() => service.snapshots).thenAnswer((_) => snapshots);
      when(service.refresh).thenAnswer((_) async {});
      when(
        () => mockSessionRepository.loadSessionOptions(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          mode: SessionOptionsRequestMode.cacheOnly,
        ),
      ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());

      final cubit = buildCubit(pluginManagementService: service);
      addTearDown(cubit.close);
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && !state.interaction.canInteract,
        description: "blocked transcript",
      );
      expect((cubit.state as SessionDetailLoaded).availableAgents, isEmpty);

      snapshots.add(
        managementFixture(pluginId: "plugin-1", setup: PluginSetupState.ready, runtime: PluginRuntimeState.dormant),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) =>
            state is SessionDetailLoaded && state.interaction.canInteract && state.availableAgents.isNotEmpty,
        description: "recovered catalog",
      );
      final recovered = cubit.state as SessionDetailLoaded;
      expect(recovered.selectedAgent, testAgentInfo().name);
    });

    test("a blocked session the bridge stored nothing for reports the block", () async {
      // The store-only read succeeds but has nothing to serve and says the
      // harness still owes it. An empty chat would claim the session has no
      // history; the truth is that reading it needs the harness enabled.
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        ),
      );
      addTearDown(snapshots.close);
      final service = MockPluginManagementService();
      when(() => service.snapshots).thenAnswer((_) => snapshots);
      when(service.refresh).thenAnswer((_) async {});
      when(
        () => mockSessionService.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const MessageWithPartsResponse(
            messages: <MessageWithParts>[],
            nextCursor: null,
            replayedPromptDefaults: null,
            awaitingHarnessSync: true,
          ),
        ),
      );

      final cubit = buildCubit(pluginManagementService: service);
      addTearDown(cubit.close);
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailHarnessUnavailable,
        description: "unavailable history",
      );
    });

    test("a blocked session serves the stored transcript the harness has not caught up with", () async {
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        ),
      );
      addTearDown(snapshots.close);
      final service = MockPluginManagementService();
      when(() => service.snapshots).thenAnswer((_) => snapshots);
      when(service.refresh).thenAnswer((_) async {});
      final stored = await mockSessionService.getMessages(
        sessionId: sessionId,
        limit: SessionDetailLoadService.initialPageSize,
        before: null,
        storedOnly: false,
      );
      when(
        () => mockSessionService.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: true,
        ),
      ).thenAnswer(
        (_) async => switch (stored) {
          SuccessResponse(:final data) => ApiResponse.success(data.copyWith(awaitingHarnessSync: true)),
          ErrorResponse(:final error) => ApiResponse.error(error),
        },
      );

      final cubit = buildCubit(pluginManagementService: service);
      addTearDown(cubit.close);
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded,
        description: "stored transcript",
      );
      final loaded = cubit.state as SessionDetailLoaded;
      expect(loaded.messages, isNotEmpty, reason: "a stale store still has history worth reading");
      expect(loaded.interaction, isA<SessionInteractionBlocked>());
    });

    test("a blocked session whose stored history cannot be served reports the block", () async {
      // Serving history can still need a harness-backed backfill when the bridge
      // has no complete snapshot, and that backfill is exactly what the block
      // prevents. The user must see the block, not a generic failure.
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        ),
      );
      addTearDown(snapshots.close);
      final service = MockPluginManagementService();
      when(() => service.snapshots).thenAnswer((_) => snapshots);
      when(service.refresh).thenAnswer((_) async {});
      when(
        () => mockSessionService.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = buildCubit(pluginManagementService: service);
      addTearDown(cubit.close);
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailHarnessUnavailable,
        description: "unavailable history",
      );
      final blocked = cubit.state as SessionDetailHarnessUnavailable;
      expect(blocked.interaction, isA<SessionInteractionBlocked>());
      expect(
        (blocked.interaction as SessionInteractionBlocked).reason,
        SessionInteractionBlockedReason.authenticationRequired,
      );
    });

    test("a block racing a reload keeps the rendered transcript instead of the unavailable shell", () async {
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(pluginId: "plugin-1", setup: PluginSetupState.ready, runtime: PluginRuntimeState.dormant),
      );
      addTearDown(snapshots.close);
      final management = MockPluginManagementService();
      when(() => management.snapshots).thenAnswer((_) => snapshots);
      when(management.refresh).thenAnswer((_) async {});
      final cubit = buildCubit(pluginManagementService: management);
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      final before = cubit.state as SessionDetailLoaded;

      // The block lands after metadata resolves, and the content request then
      // fails because serving it would need the backfill the block prevents.
      final metadata = Completer<ApiResponse<Session>>();
      final saved = await mockSessionRepository.getSession(sessionId: sessionId);
      when(() => mockSessionRepository.getSession(sessionId: sessionId)).thenAnswer((_) => metadata.future);
      when(
        () => mockSessionService.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      final reloading = cubit.reload();
      snapshots.add(
        managementFixture(
          pluginId: "plugin-1",
          setup: PluginSetupState.authenticationRequired,
          runtime: PluginRuntimeState.blocked,
        ),
      );
      metadata.complete(saved);
      await reloading;

      final after = cubit.state;
      expect(after, isA<SessionDetailLoaded>());
      expect((after as SessionDetailLoaded).messages, before.messages);
      expect(after.interaction.canInteract, isFalse);
    });

    test("reconnect keeps a loaded chat interactive until a confirmed harness block", () async {
      final connected = mockConnectionService.currentStatus;
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        managementFixture(setup: PluginSetupState.ready, runtime: PluginRuntimeState.active, pluginId: "plugin-1"),
      );
      addTearDown(snapshots.close);
      final managementService = MockPluginManagementService();
      when(() => managementService.snapshots).thenAnswer((_) => snapshots);
      when(managementService.refresh).thenAnswer((_) async {});
      final cubit = buildCubit(pluginManagementService: managementService);
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      final states = <SessionDetailState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      for (final status in [
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        ),
        const ConnectionStatus.reconnecting(
          config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        ),
        connected,
      ]) {
        when(() => mockConnectionService.currentStatus).thenReturn(status);
        connectionStatus.add(status);
        snapshots.add(const PluginManagementLoadResult.loading());
        await Future<void>.delayed(Duration.zero);
        await _awaitNotRefreshing(cubit);
        expect((cubit.state as SessionDetailLoaded).interaction.canInteract, isTrue);
      }
      expect(states, isNotEmpty);
      expect(
        states,
        everyElement(
          isA<SessionDetailLoaded>().having((state) => state.interaction.canInteract, "interactive", isTrue),
        ),
      );

      snapshots.add(
        managementFixture(setup: PluginSetupState.ready, runtime: PluginRuntimeState.disabled, pluginId: "plugin-1"),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && !state.interaction.canInteract,
        description: "confirmed disable after reconnect",
      );
      expect(
        (cubit.state as SessionDetailLoaded).interaction,
        isA<SessionInteractionBlocked>().having(
          (state) => state.reason,
          "reason",
          SessionInteractionBlockedReason.disabled,
        ),
      );
    });

    test("metadata refresh failure preserves the loaded transcript and buffered events", () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      final before = cubit.state as SessionDetailLoaded;
      final metadata = Completer<ApiResponse<Session>>();
      when(() => mockSessionRepository.getSession(sessionId: sessionId)).thenAnswer((_) => metadata.future);
      final reloading = cubit.reload();
      expect(cubit.state, isA<SessionDetailLoading>());
      sessionEvents.add(const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.busy()));
      metadata.complete(ApiResponse.error(ApiError.generic()));
      await reloading;
      final after = cubit.state as SessionDetailLoaded;
      expect(after.messages, before.messages);
      expect(after.interaction.canInteract, isTrue);
      expect(after.sessionStatus, const SessionStatus.busy());
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "initial load success emits SessionDetailLoaded",
      build: buildCubit,
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
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
        verify(() => mockSessionService.listCommands(projectId: "project-1", pluginId: "plugin-1")).called(1);
        verify(() => mockSessionRepository.getSession(sessionId: sessionId)).called(1);
        verify(() => mockConnectionService.sessionEvents(sessionId)).called(1);
        verify(() => mockConnectionService.events).called(1);
      },
    );

    test("does not declare a covered route when its initial load completes", () async {
      final sessionViewingService = stubbedSessionViewingService();
      final cubit = buildCubit(sessionViewingService: sessionViewingService);
      cubit.setRouteVisible(isVisible: false);

      await _awaitLoaded(cubit);
      verifyNever(() => sessionViewingService.setViewingSession(any()));

      cubit.setRouteVisible(isVisible: true);
      verify(() => sessionViewingService.setViewingSession(sessionId)).called(1);
      await cubit.close();
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "initial load failure emits SessionDetailFailed",
      build: () {
        when(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return buildCubit();
      },
      expect: () => [
        isA<SessionDetailFailed>(),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "reload re-fetches all initial data",
      build: buildCubit,
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
        verify(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        ).called(2);
        verify(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).called(2);
        verify(() => mockSessionService.getChildren(sessionId: sessionId)).called(2);
        verify(() => mockSessionService.getSessionStatuses()).called(2);
        verify(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: "plugin-1",
          ),
        ).called(2);
        verify(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: "plugin-1",
          ),
        ).called(2);
        verify(() => mockSessionService.listCommands(projectId: "project-1", pluginId: "plugin-1")).called(2);
        verify(() => mockSessionRepository.getSession(sessionId: sessionId)).called(2);
        verify(mockPluginRepository.listPlugins).called(2);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage when connected delegates to service with trimmed text",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          attachments: const [],
          text: "  hi  ",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        _queuedSubmission("hi"),
        _sendingSubmission("hi"),
        _noPendingSubmission,
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: "prompt-1",
            attachments: const [],
            sessionId: sessionId,
            text: "hi",
            agent: "coder",
            model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
            variant: const SessionVariant(id: "xhigh"),
            command: null,
          ),
        ).called(1);
        verify(
          () => mockProductAnalyticsService.logEvent(
            event: const ProductAnalyticsEvent.sessionMessageSent(
              submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
            ),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage forwards attachments when the plugin declares support",
      build: () {
        _stubPromptAttachmentCapability(
          repository: mockPluginRepository,
          pluginId: "codex",
          supportsPromptAttachments: true,
        );
        stubSessionRepositoryGetSession(
          repository: mockSessionRepository,
          sessionId: sessionId,
          session: testSession(id: sessionId, pluginId: "codex"),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          text: "look at this",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        _queuedSubmission("look at this"),
        _sendingSubmission("look at this"),
        _noPendingSubmission,
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: any(named: "promptId"),
            sessionId: sessionId,
            text: "look at this",
            attachments: any(named: "attachments", that: hasLength(1)),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage refuses attachments when the plugin declares no support",
      build: () {
        _stubPromptAttachmentCapability(
          repository: mockPluginRepository,
          pluginId: "opencode",
          supportsPromptAttachments: false,
        );
        stubSessionRepositoryGetSession(
          repository: mockSessionRepository,
          sessionId: sessionId,
          session: testSession(id: sessionId, pluginId: "opencode"),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          text: "look at this",
          command: null,
          inputMode: ComposerInputMode.typed,
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
        );
      },
      // Refused outright rather than sent with the images stripped: nothing
      // reaches the service and nothing is queued.
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.queuedMessages, "queuedMessages", isEmpty),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
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
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage refuses a command carrying attachments instead of dropping them",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          text: "look at this",
          command: "review",
          inputMode: ComposerInputMode.typed,
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
        );
      },
      // The bridge's command paths carry only text, so the send is refused
      // outright rather than reaching the service with the images stripped.
      // Only the load state is emitted; nothing is sent and nothing is queued.
      expect: () => [
        isA<SessionDetailLoaded>().having((state) => state.queuedMessages, "queuedMessages", isEmpty),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
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
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage with command when connected delegates to service",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          attachments: const [],
          text: "lib/main.dart",
          command: "review",
          inputMode: ComposerInputMode.voiceAssisted,
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        _queuedSubmission("/review lib/main.dart"),
        _sendingSubmission("/review lib/main.dart"),
        _noPendingSubmission,
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: "prompt-1",
            attachments: const [],
            sessionId: sessionId,
            text: "lib/main.dart",
            agent: "coder",
            model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
            variant: const SessionVariant(id: "xhigh"),
            command: "review",
          ),
        ).called(1);
        verify(
          () => mockProductAnalyticsService.logEvent(
            event: const ProductAnalyticsEvent.sessionMessageSent(
              submission: AnalyticsSubmission.command(),
            ),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).called(1);
      },
    );

    test("voice completion reports a content-free outcome", () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.reportVoiceTranscriptionCompleted();

      verify(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.voiceTranscriptionCompleted(),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(1);
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage sends immediately when session is busy but connected",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Session becomes busy.
        sessionEvents.add(
          const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.busy()),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.sessionStatus == const SessionStatus.busy(),
          description: "busy session",
        );

        // Send message while busy — should send immediately (not queue).
        await cubit.sendMessage(
          attachments: const [],
          text: "hello",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        // Session busy.
        isA<SessionDetailLoaded>().having(
          (state) => state.sessionStatus,
          "sessionStatus",
          const SessionStatus.busy(),
        ),
        _queuedSubmission("hello"),
        _sendingSubmission("hello"),
        _noPendingSubmission,
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: "prompt-1",
            attachments: const [],
            sessionId: sessionId,
            text: "hello",
            agent: "coder",
            model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
            variant: const SessionVariant(id: "xhigh"),
            command: null,
          ),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectAgent applies an agent's declared model when the catalog offers it",
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            Agents(
              agents: [
                testAgentInfo(),
                testAgentInfo().copyWith(
                  name: "reviewer",
                  description: "Reviews code",
                  model: const AgentModel(
                    providerID: "anthropic",
                    modelID: "claude-3-5-sonnet",
                    variant: null,
                  ),
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectAgent("reviewer");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>()
            .having(
              (state) => state.selectedAgent,
              "selectedAgent",
              "reviewer",
            )
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              // The declared model carries no variant, so the catalog's own
              // first variant is resolved onto it.
              const AgentModel(
                providerID: "anthropic",
                modelID: "claude-3-5-sonnet",
                variant: "xhigh",
              ),
            ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectAgent keeps the current model when the agent declares one the catalog omits",
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            Agents(
              agents: [
                testAgentInfo(),
                testAgentInfo().copyWith(
                  name: "reviewer",
                  description: "Reviews code",
                  model: const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectAgent("reviewer");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>()
            .having((state) => state.selectedAgent, "selectedAgent", "reviewer")
            // An agent may name a model from a provider this catalog does not
            // carry. Selecting it would put an unusable model in the composer,
            // so the one already on screen stays.
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              const AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: "xhigh"),
            ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectModel updates selected provider and model",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectModel(providerID: "openai", modelID: "gpt-4.1");
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "selectVariant updates selectedAgentModel variant",
      build: () {
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const ProviderListResponse(
              connectedOnly: false,
              items: [
                ProviderInfo(
                  id: "openai",
                  name: "OpenAI",
                  defaultModelID: "gpt-4",
                  models: {
                    "gpt-4": ProviderModel(
                      id: "gpt-4",
                      providerID: "openai",
                      name: "GPT-4",
                      variants: ["fast", "slow"],
                      defaultVariant: null,
                      family: null,
                      releaseDate: null,
                    ),
                  },
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.selectVariant(const SessionVariant(id: "slow"));
      },
      expect: () => [
        isA<SessionDetailLoaded>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial variant",
          "fast",
        ),
        isA<SessionDetailLoaded>().having(
          (state) => state.selectedAgentModel?.variant,
          "variant",
          "slow",
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "abort delegates to service.abortSession",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.abortSession(
            sessionId: sessionId,
            subAgents: any(named: "subAgents"),
          ),
        ).called(1);
      },
    );

    test("abort refuses every scope after archiving while stop confirmation is pending", () async {
      const rejection = SessionAbortRejection(runningSubAgentCount: 2, mainAgentRunning: true);
      when(
        () => mockSessionRepository.abortSession(sessionId: sessionId, subAgents: SessionAbortSubAgentPolicy.confirm),
      ).thenThrow(SessionAbortRejectedException(rejection: rejection, innerError: StateError("409")));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      expect(await cubit.abort(subAgents: SessionAbortSubAgentPolicy.confirm), isA<SessionAbortRejected>());
      clearInteractions(mockSessionRepository);
      clearInteractions(mockProductAnalyticsService);

      // Another surface archives the session while the scope dialog is open.
      sessionEvents.add(
        SesoriSessionUpdated(
          info: testSession(id: sessionId, archivedAt: DateTime.utc(2026)),
        ),
      );
      await awaitState(
        cubit: cubit,
        predicate: (state) => state is SessionDetailLoaded && state.isArchived,
        description: "session archived during stop confirmation",
      );
      final archivedState = cubit.state;
      expect((archivedState as SessionDetailLoaded).interaction.canInteract, isTrue);

      for (final policy in SessionAbortSubAgentPolicy.values) {
        expect(await cubit.abort(subAgents: policy), isA<SessionAbortFailed>());
      }

      expect(cubit.state, same(archivedState));
      verifyNever(
        () => mockSessionRepository.abortSession(
          sessionId: any(named: "sessionId"),
          subAgents: any(named: "subAgents"),
        ),
      );
      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionAbortSucceeded(),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    test("abort skips legacy descendant fanout after bridge acknowledgment", () async {
      const childId = "child-1";
      when(() => mockSessionService.getChildren(sessionId: sessionId)).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [testSession(id: childId, parentID: sessionId)],
          ),
        ),
      );
      when(() => mockSessionService.getSessionStatuses()).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionStatusResponse(statuses: {childId: SessionStatus.busy()}),
        ),
      );
      when(
        () => mockSessionService.abortSession(
          sessionId: sessionId,
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer((_) async => ApiResponse.success(true));
      final cubit = buildCubit();
      await _awaitLoaded(cubit);

      final outcome = await cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);

      expect(outcome, isA<SessionAbortAccepted>());
      verifyNever(
        () => mockSessionService.abortSession(
          sessionId: childId,
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      );
      await cubit.close();
    });

    test("fallback reads fresh repository state while detail reloads", () async {
      const childId = "child-1";
      when(() => mockSessionService.getChildren(sessionId: sessionId)).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [testSession(id: childId, parentID: sessionId)],
          ),
        ),
      );
      when(() => mockSessionService.getSessionStatuses()).thenAnswer(
        (_) async => ApiResponse.success(
          const SessionStatusResponse(statuses: {childId: SessionStatus.busy()}),
        ),
      );
      final rootAbort = Completer<ApiResponse<bool>>();
      when(
        () => mockSessionService.abortSession(
          sessionId: sessionId,
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).thenAnswer((_) => rootAbort.future);
      final cubit = buildCubit();
      await _awaitLoaded(cubit);
      final aborting = cubit.abort(subAgents: SessionAbortSubAgentPolicy.stop);
      await Future<void>.delayed(Duration.zero);

      final reloadMessages = Completer<ApiResponse<MessageWithPartsResponse>>();
      when(
        () => mockSessionService.getMessages(
          sessionId: sessionId,
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) => reloadMessages.future);
      final reloading = cubit.reload();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<SessionDetailLoading>());

      rootAbort.complete(ApiResponse.success(false));
      expect(await aborting, isA<SessionAbortAccepted>());
      verify(
        () => mockSessionService.abortSession(
          sessionId: childId,
          subAgents: SessionAbortSubAgentPolicy.stop,
        ),
      ).called(1);

      reloadMessages.complete(
        ApiResponse.success(
          MessageWithPartsResponse(
            messages: [testMessageWithParts()],
            nextCursor: null,
            replayedPromptDefaults: null,
          ),
        ),
      );
      await reloading;
      await cubit.close();
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "replyToQuestion optimistically removes pending question and calls API",
      build: () {
        when(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).thenAnswer(
          (_) async => ApiResponse.success(PendingQuestionResponse(data: [testPendingQuestion()])),
        );

        return buildCubit();
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
          () => mockNotificationCanceller.cancelForSession(sessionId: sessionId),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "rejectQuestion optimistically removes pending question and calls API",
      build: () {
        when(() => mockSessionService.getPendingQuestions(sessionId: sessionId)).thenAnswer(
          (_) async => ApiResponse.success(PendingQuestionResponse(data: [testPendingQuestion()])),
        );

        return buildCubit();
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
        verify(() => mockSessionService.rejectQuestion(requestId: "question-1", sessionId: sessionId)).called(1);
        verify(
          () => mockNotificationCanceller.cancelForSession(sessionId: sessionId),
        ).called(1);
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "clearNotifications dismisses all notifications for the session",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        cubit.clearNotifications();
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockNotificationCanceller.cancelForSession(sessionId: sessionId),
        ).called(1);
      },
    );

    test("clearNotifications is a no-op when the shell has no notification integration", () async {
      final cubit = SessionDetailCubit(
        mockConnectionService,
        claimProjectView: true,
        pluginManagementService: stubbedPluginManagementService(),
        interactionCalculator: const SessionInteractionCalculator(),
        loadService: loadService,
        sessionAbortService: SessionAbortService(repository: promptDispatcher),
        promptDispatcher: promptDispatcher,
        permissionRepository: mockPermissionRepository,
        sessionViewingService: stubbedSessionViewingService(),
        projectViewingService: stubbedProjectViewingService(),
        lifecycleSource: MockLifecycleSource(),
        composerDraftRepository: inMemoryComposerDraftRepository(),
        productAnalyticsService: mockProductAnalyticsService,
        sessionId: sessionId,
        projectId: "project-1",
        notificationCanceller: null,
        failureReporter: mockFailureReporter,
      );
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      expect(cubit.clearNotifications, returnsNormally);
    });

    test("reassertViewingSession restores a loaded parent after child navigation", () async {
      final sessionViewingService = stubbedSessionViewingService();
      final cubit = buildCubit(sessionViewingService: sessionViewingService);
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);
      clearInteractions(sessionViewingService);

      cubit.reassertViewingSession();

      verify(() => sessionViewingService.setViewingSession(sessionId)).called(1);
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "SSE message.updated adds message to state",
      build: () {
        when(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const MessageWithPartsResponse(
              messages: <MessageWithParts>[],
              nextCursor: null,
              replayedPromptDefaults: null,
            ),
          ),
        );

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        const message = Message.user(
          promptId: null,
          id: "msg-new",
          sessionID: sessionId,
          agent: null,
          time: null,
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
      build: buildCubit,
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
      build: buildCubit,
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

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        sessionEvents.add(
          const SesoriQuestionReplied(
            requestID: "question-1",
            sessionID: sessionId,
            displaySessionId: null,
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
      build: buildCubit,
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

        return buildCubit();
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

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // A newer child session arrives via global SSE event.
        final newerChild = testSession(id: "child-2", parentID: sessionId, updatedAt: 5000);
        globalEvents.add(SseEvent(data: SesoriSessionCreated(info: newerChild)));
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.children.first.id == "child-2",
          description: "new child inserted first",
        );
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
      "silent refresh re-sorts children by updated descending",
      build: () {
        final oldChild = testSession(id: "child-old", parentID: sessionId, updatedAt: 1000);
        final newChild = testSession(id: "child-new", parentID: sessionId, updatedAt: 3000);

        // Initial load returns sorted newest-first.
        when(
          () => mockSessionService.getChildren(sessionId: sessionId),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [newChild, oldChild])),
        );

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Silent refresh returns children in oldest-first API order.
        final oldChild = testSession(id: "child-old", parentID: sessionId, updatedAt: 1000);
        final newChild = testSession(id: "child-new", parentID: sessionId, updatedAt: 3000);
        when(
          () => mockSessionService.getChildren(sessionId: sessionId),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [oldChild, newChild])),
        );

        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        sessionEvents.add(
          const SesoriCommandExecuted(
            name: "refresh",
            sessionID: sessionId,
            arguments: "",
            messageID: "refresh-message",
          ),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.isRefreshing,
          description: "silent refresh started",
        );
        await _awaitNotRefreshing(cubit);
      },
      expect: () => [
        // Initial load: newest first.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids (DESC)",
          ["child-new", "child-old"],
        ),
        // Refresh in progress.
        isA<SessionDetailLoaded>().having(
          (state) => state.isRefreshing,
          "isRefreshing",
          isTrue,
        ),
        // After silent refresh: still newest first.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids after refresh (DESC)",
          ["child-new", "child-old"],
        ),
      ],
    );

    test("slow silent refresh preserves model selection changed while refresh is in flight", () async {
      var getMessagesCallCount = 0;
      final slowRefreshStarted = Completer<void>();
      final completeSlowRefresh = Completer<void>();

      when(
        () => mockSessionRepository.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) {
        getMessagesCallCount += 1;
        if (getMessagesCallCount == 2) {
          slowRefreshStarted.complete();
          return completeSlowRefresh.future.then(
            (_) => ApiResponse.success(
              MessageWithPartsResponse(
                messages: [testMessageWithParts()],
                nextCursor: null,
                replayedPromptDefaults: null,
              ),
            ),
          );
        }

        return Future<ApiResponse<MessageWithPartsResponse>>.value(
          ApiResponse.success(
            MessageWithPartsResponse(
              messages: [testMessageWithParts()],
              nextCursor: null,
              replayedPromptDefaults: null,
            ),
          ),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      connectionStatus.add(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          health: testHealthResponse(),
        ),
      );
      sessionEvents.add(
        const SesoriCommandExecuted(
          name: "refresh",
          sessionID: sessionId,
          arguments: "",
          messageID: "refresh-message",
        ),
      );
      await slowRefreshStarted.future;

      cubit.selectModel(providerID: "openai", modelID: "gpt-4.1");
      expect(
        (cubit.state as SessionDetailLoaded).selectedAgentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
      );

      completeSlowRefresh.complete();
      await _awaitNotRefreshing(cubit);

      expect(
        (cubit.state as SessionDetailLoaded).selectedAgentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: null),
      );
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "session.updated SSE re-sorts children by updated descending",
      build: () {
        final oldChild = testSession(id: "child-old", parentID: sessionId, updatedAt: 1000);
        final newChild = testSession(id: "child-new", parentID: sessionId, updatedAt: 3000);

        when(
          () => mockSessionService.getChildren(sessionId: sessionId),
        ).thenAnswer(
          (_) async => ApiResponse.success(SessionListResponse(items: [newChild, oldChild])),
        );

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Old child gets a newer updated timestamp.
        final updatedOldChild = testSession(id: "child-old", parentID: sessionId, updatedAt: 5000);
        globalEvents.add(SseEvent(data: SesoriSessionUpdated(info: updatedOldChild)));
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.children.first.id == "child-old",
          description: "updated child re-sorted first",
        );
      },
      expect: () => [
        // Initial load: newest first.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids (DESC)",
          ["child-new", "child-old"],
        ),
        // After update: re-sorted so child-old (now 5000) comes first.
        isA<SessionDetailLoaded>().having(
          (state) => state.children.map((c) => c.id).toList(),
          "children ids after update (DESC)",
          ["child-old", "child-new"],
        ),
      ],
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "close disposes event subscriptions",
      build: buildCubit,
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
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );
        await cubit.sendMessage(
          attachments: const [],
          text: "hello",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
      },

      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "sendMessage queues when reconnecting",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.reconnecting(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );
        await cubit.sendMessage(
          attachments: const [],
          text: "hello",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
      },

      expect: () => [
        isA<SessionDetailLoaded>(),
        isA<SessionDetailLoaded>().having(
          (state) => state.queuedMessages.map((message) => message.displayText).toList(),
          "queuedMessages",
          ["hello"],
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockSessionService.sendMessage(
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
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
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);
        await cubit.sendMessage(
          attachments: const [],
          text: "hello",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
      },
      expect: () => [
        isA<SessionDetailLoaded>(),
        _queuedSubmission("hello"),
        _sendingSubmission("hello"),
        // Message re-queued after failed send.
        _queuedSubmission("hello"),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: "prompt-1",
            attachments: const [],
            sessionId: sessionId,
            text: "hello",
            agent: "coder",
            model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
            variant: const SessionVariant(id: "xhigh"),
            command: null,
          ),
        ).called(1);
        verifyNever(
          () => mockProductAnalyticsService.logEvent(
            event: any(named: "event"),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        );
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
        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Connection drops.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );

        // Send message while disconnected — queued.
        await cubit.sendMessage(
          attachments: const [],
          text: "queued msg",
          command: null,
          inputMode: ComposerInputMode.typed,
        );

        // Session becomes idle — but connection is lost, so queue stays.
        sessionEvents.add(
          const SesoriSessionStatus(sessionID: sessionId, status: SessionStatus.idle()),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.sessionStatus == const SessionStatus.idle(),
          description: "idle session",
        );
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
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        );
      },
    );

    blocTest<SessionDetailCubit, SessionDetailState>(
      "connection restored drains queued messages",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );

        // Send message — queued because disconnected.
        await cubit.sendMessage(
          attachments: const [],
          text: "retry me",
          command: null,
          inputMode: ComposerInputMode.voiceAssisted,
        );

        // Simulate reconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        await _awaitQueuedMessages(cubit, isEmpty);
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
        _sendingSubmission("retry me"),
        _noPendingSubmission,
      ],
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: "prompt-1",
            attachments: const [],
            sessionId: sessionId,
            text: "retry me",
            agent: "coder",
            model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
            variant: const SessionVariant(id: "xhigh"),
            command: null,
          ),
        ).called(1);
        verify(
          () => mockProductAnalyticsService.logEvent(
            event: const ProductAnalyticsEvent.sessionMessageSent(
              submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.voiceAssisted),
            ),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).called(1);
      },
    );

    test("whitespace-only command is queued and drained as a normal prompt", () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        ),
      );

      await cubit.sendMessage(
        attachments: const [],
        text: "hello",
        command: "   ",
        inputMode: ComposerInputMode.typed,
      );

      expect(
        (cubit.state as SessionDetailLoaded).queuedMessages.map((message) => message.displayText).toList(),
        equals(["hello"]),
      );

      when(() => mockConnectionService.currentStatus).thenReturn(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          health: testHealthResponse(),
        ),
      );
      connectionStatus.add(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          health: testHealthResponse(),
        ),
      );
      await _awaitQueuedMessages(cubit, isEmpty);

      verify(
        () => mockSessionService.sendMessage(
          promptId: "prompt-1",
          attachments: const [],
          sessionId: sessionId,
          text: "hello",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "xhigh"),
          command: null,
        ),
      ).called(1);
    });

    test("slow silent refresh does not restore a queued command after it drains", () async {
      var getMessagesCallCount = 0;
      final slowRefreshStarted = Completer<void>();
      final completeSlowRefresh = Completer<void>();

      when(
        () => mockSessionRepository.getMessages(
          sessionId: any(named: "sessionId"),
          limit: any(named: "limit"),
          before: any(named: "before"),
          storedOnly: any(named: "storedOnly"),
        ),
      ).thenAnswer((_) {
        getMessagesCallCount += 1;
        if (getMessagesCallCount == 2) {
          slowRefreshStarted.complete();
          return completeSlowRefresh.future.then(
            (_) => ApiResponse.success(
              MessageWithPartsResponse(
                messages: [testMessageWithParts()],
                nextCursor: null,
                replayedPromptDefaults: null,
              ),
            ),
          );
        }

        return Future<ApiResponse<MessageWithPartsResponse>>.value(
          ApiResponse.success(
            MessageWithPartsResponse(
              messages: [testMessageWithParts()],
              nextCursor: null,
              replayedPromptDefaults: null,
            ),
          ),
        );
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      final connected = ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        health: testHealthResponse(),
      );
      connectionStatus.add(connected);
      await Future<void>.delayed(Duration.zero);

      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        ),
      );
      await cubit.sendMessage(
        attachments: const [],
        text: "lib/main.dart",
        command: "review",
        inputMode: ComposerInputMode.typed,
      );
      expect(
        (cubit.state as SessionDetailLoaded).queuedMessages.map((message) => message.displayText).toList(),
        equals(["/review lib/main.dart"]),
      );

      when(() => mockConnectionService.currentStatus).thenReturn(connected);
      sessionEvents.add(
        const SesoriCommandExecuted(
          name: "refresh",
          sessionID: sessionId,
          arguments: "",
          messageID: "refresh-message",
        ),
      );
      await slowRefreshStarted.future;

      connectionStatus.add(connected);
      await _awaitQueuedMessages(cubit, isEmpty);

      completeSlowRefresh.complete();
      await _awaitNotRefreshing(cubit);

      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
      verify(
        () => mockSessionService.sendMessage(
          promptId: "prompt-1",
          attachments: const [],
          sessionId: sessionId,
          text: "lib/main.dart",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "xhigh"),
          command: "review",
        ),
      ).called(1);
    });

    test("connected send while queued drain is in flight stays queued until earlier work finishes", () async {
      final firstSendStarted = Completer<void>();
      final allowFirstSendToComplete = Completer<void>();
      final sentTexts = <String>[];

      when(
        () => mockSessionService.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
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

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      when(() => mockConnectionService.currentStatus).thenReturn(
        const ConnectionStatus.connectionLost(
          config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
        ),
      );
      await cubit.sendMessage(
        attachments: const [],
        text: "first",
        command: null,
        inputMode: ComposerInputMode.typed,
      );

      when(() => mockConnectionService.currentStatus).thenReturn(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          health: testHealthResponse(),
        ),
      );
      connectionStatus.add(
        ConnectionStatus.connected(
          config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          health: testHealthResponse(),
        ),
      );

      await firstSendStarted.future;
      await cubit.sendMessage(
        attachments: const [],
        text: "second",
        command: null,
        inputMode: ComposerInputMode.typed,
      );

      expect(sentTexts, equals(["first"]));
      expect(
        (cubit.state as SessionDetailLoaded).queuedMessages.map((message) => message.displayText).toList(),
        equals(["second"]),
      );

      allowFirstSendToComplete.complete();
      await _awaitQueuedMessages(cubit, isEmpty);

      expect(sentTexts, equals(["first", "second"]));
      expect((cubit.state as SessionDetailLoaded).queuedMessages, isEmpty);
    });

    test("a queued prompt keeps the agent and model selected when it was submitted", () async {
      final firstSendStarted = Completer<void>();
      final allowFirstSendToComplete = Completer<void>();

      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          Agents(
            agents: [
              testAgentInfo(),
              testAgentInfo().copyWith(
                name: "reviewer",
                model: const AgentModel(providerID: "openai", modelID: "gpt-4.1", variant: "fast"),
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.sendMessage(
          promptId: any(named: "promptId"),
          attachments: const [],
          sessionId: any(named: "sessionId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[#text] == "first") {
          firstSendStarted.complete();
          await allowFirstSendToComplete.future;
        }
        return ApiResponse<void>.success(null);
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);
      await _awaitLoaded(cubit);

      unawaited(
        cubit.sendMessage(
          attachments: const [],
          text: "first",
          command: null,
          inputMode: ComposerInputMode.typed,
        ),
      );
      await firstSendStarted.future;
      await cubit.sendMessage(
        attachments: const [],
        text: "second",
        command: null,
        inputMode: ComposerInputMode.typed,
      );
      cubit.selectAgent("reviewer");

      allowFirstSendToComplete.complete();
      await _awaitQueuedMessages(cubit, isEmpty);

      verify(
        () => mockSessionService.sendMessage(
          promptId: "prompt-1",
          attachments: const [],
          sessionId: sessionId,
          text: "second",
          agent: "coder",
          model: const PromptModel(providerID: "anthropic", modelID: "claude-3-5-sonnet"),
          variant: const SessionVariant(id: "xhigh"),
          command: null,
        ),
      ).called(1);
    });

    blocTest<SessionDetailCubit, SessionDetailState>(
      "multiple queued messages drain sequentially on reconnection",
      build: buildCubit,
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );

        // Queue two messages while disconnected.
        await cubit.sendMessage(
          attachments: const [],
          text: "first",
          command: null,
          inputMode: ComposerInputMode.typed,
        );
        await cubit.sendMessage(
          attachments: const [],
          text: "second",
          command: null,
          inputMode: ComposerInputMode.typed,
        );

        // Simulate reconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );

        // Wait for both messages to drain via self-chaining.
        await _awaitQueuedMessages(cubit, isEmpty);
      },
      verify: (_) {
        verify(
          () => mockSessionService.sendMessage(
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: sessionId,
            text: "first",
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
        verify(
          () => mockSessionService.sendMessage(
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: sessionId,
            text: "second",
            agent: any(named: "agent"),
            model: any(named: "model"),
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
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: any(named: "sessionId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

        return buildCubit();
      },
      act: (cubit) async {
        await _awaitLoaded(cubit);

        // Simulate disconnection.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );

        // Queue a message.
        await cubit.sendMessage(
          attachments: const [],
          text: "will fail",
          command: null,
          inputMode: ComposerInputMode.typed,
        );

        // Simulate reconnection — triggers drain, but send will fail.
        when(() => mockConnectionService.currentStatus).thenReturn(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) =>
              state is SessionDetailLoaded &&
              state.queuedMessages.map((message) => message.displayText).contains("will fail") &&
              state.sendingSubmission == null,
          description: "failed queued message re-queued",
        );
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
        _sendingSubmission("will fail"),
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
            promptId: any(named: "promptId"),
            attachments: const [],
            sessionId: sessionId,
            text: "will fail",
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
          ),
        ).called(1);
      },
    );

    group("viewing declaration", () {
      test("audit detail loads without acquiring, readying or releasing a live project claim", () async {
        final projectViewing = stubbedProjectViewingService();
        final cubit = buildCubit(projectViewingService: projectViewing, claimProjectView: false);
        await _awaitLoaded(cubit);
        await cubit.close();
        verifyNever(() => projectViewing.beginDetailClaim(projectId: any(named: "projectId")));
        verifyNever(
          () => projectViewing.markClaimReady(
            claim: any(named: "claim"),
            projectId: any(named: "projectId"),
          ),
        );
        verifyNever(() => projectViewing.releaseClaim(claim: any(named: "claim")));
      });
      test("declares the view once the transcript loads and clears it on close", () async {
        final viewingService = stubbedSessionViewingService();
        final projectViewingService = stubbedProjectViewingService();
        final projectClaim = ProjectViewClaim();
        when(
          () => projectViewingService.beginDetailClaim(projectId: "project-1"),
        ).thenReturn(projectClaim);
        final cubit = buildCubit(sessionViewingService: viewingService, projectViewingService: projectViewingService);
        await _awaitLoaded(cubit);

        verify(() => viewingService.setViewingSession(sessionId)).called(1);
        verify(
          () => projectViewingService.beginDetailClaim(projectId: "project-1"),
        ).called(1);
        verify(
          () => projectViewingService.markClaimReady(
            claim: projectClaim,
            projectId: "project-1",
          ),
        ).called(1);

        await cubit.close();
        verify(() => viewingService.clearViewingSession(sessionId)).called(1);
        verify(() => projectViewingService.releaseClaim(claim: projectClaim)).called(1);
      });

      test("a failed load never declares the view", () async {
        when(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        final viewingService = stubbedSessionViewingService();
        final projectViewingService = stubbedProjectViewingService();
        final projectClaim = ProjectViewClaim();
        when(
          () => projectViewingService.beginDetailClaim(projectId: "project-1"),
        ).thenReturn(projectClaim);
        final cubit = buildCubit(sessionViewingService: viewingService, projectViewingService: projectViewingService);
        addTearDown(cubit.close);
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailFailed,
          description: "failed session load",
        );

        verifyNever(() => viewingService.setViewingSession(any()));
        verify(
          () => projectViewingService.beginDetailClaim(projectId: "project-1"),
        ).called(1);
        verify(() => projectViewingService.markClaimFailed(claim: projectClaim)).called(1);
      });

      test("a stale reconnect refreshes AND re-asserts the view", () async {
        final viewingService = stubbedSessionViewingService();
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
          ),
        );
        final cubit = buildCubit(sessionViewingService: viewingService);
        addTearDown(cubit.close);
        await Future<void>.delayed(Duration.zero);
        clearInteractions(viewingService);
        final viewReasserted = Completer<void>();
        when(() => viewingService.setViewingSession(sessionId)).thenAnswer((_) {
          viewReasserted.complete();
        });

        // Stale signal arrives while disconnected — the refresh is deferred.
        mockConnectionService.emitDataMayBeStale();
        final staleSignalDelivered = Future<void>.delayed(Duration.zero);
        await staleSignalDelivered;
        verifyNever(() => viewingService.setViewingSession(any()));

        // Reconnect: the bridge released this connection's view on the drop,
        // so the deferred refresh must re-declare it once it renders.
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false),
          ),
        );
        connectionStatus.add(
          ConnectionStatus.connected(
            config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: testHealthResponse(),
          ),
        );
        await viewReasserted.future;

        verify(() => viewingService.setViewingSession(sessionId)).called(1);
      });

      test("a blocked chat still re-asserts the view its resume released", () async {
        // The blocked transcript stays on screen, so its refresh being a no-op
        // must not leave the chat undeclared and marking its own updates unread.
        final viewingService = stubbedSessionViewingService();
        final lifecycle = MockLifecycleSource();
        final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
          managementFixture(pluginId: "plugin-1", setup: PluginSetupState.ready, runtime: PluginRuntimeState.dormant),
        );
        addTearDown(snapshots.close);
        final management = MockPluginManagementService();
        when(() => management.snapshots).thenAnswer((_) => snapshots);
        when(management.refresh).thenAnswer((_) async {});
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false),
          ),
        );
        final cubit = buildCubit(
          sessionViewingService: viewingService,
          lifecycleSource: lifecycle,
          pluginManagementService: management,
        );
        addTearDown(cubit.close);
        await _awaitLoaded(cubit);

        snapshots.add(
          managementFixture(
            pluginId: "plugin-1",
            setup: PluginSetupState.authenticationRequired,
            runtime: PluginRuntimeState.blocked,
          ),
        );
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && !state.interaction.canInteract,
          description: "blocked while loaded",
        );
        clearInteractions(viewingService);

        // Backgrounding released the bridge-side view; the resume refresh has
        // nothing to fetch while blocked, but must still re-declare it.
        lifecycle.emitState(LifecycleState.paused);
        lifecycle.emitState(LifecycleState.resumed);
        // The blocked refresh never sets isRefreshing, so let it settle instead.
        for (var turn = 0; turn < 5; turn++) {
          await Future<void>.delayed(Duration.zero);
        }

        verify(() => viewingService.setViewingSession(sessionId)).called(1);
      });

      test("resume refreshes and re-asserts the view only after the refresh renders", () async {
        final viewingService = stubbedSessionViewingService();
        final lifecycle = MockLifecycleSource();
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
            health: HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false),
          ),
        );
        final cubit = buildCubit(sessionViewingService: viewingService, lifecycleSource: lifecycle);
        addTearDown(cubit.close);
        await _awaitLoaded(cubit);
        clearInteractions(viewingService);

        lifecycle.emitState(LifecycleState.paused);
        lifecycle.emitState(LifecycleState.resumed);
        await awaitState(
          cubit: cubit,
          predicate: (state) => state is SessionDetailLoaded && state.isRefreshing,
          description: "resume refresh started",
        );
        await _awaitNotRefreshing(cubit);

        // The post-resume silent refresh completed and re-declared the view.
        verify(() => viewingService.setViewingSession(sessionId)).called(1);
        verify(
          () => mockSessionService.getMessages(
            sessionId: sessionId,
            limit: any(named: "limit"),
            before: any(named: "before"),
            storedOnly: any(named: "storedOnly"),
          ),
        ).called(greaterThanOrEqualTo(1));
      });
    });
  });
}

Matcher _queuedSubmission(String text) => isA<SessionDetailLoaded>()
    .having(
      (state) => state.queuedMessages.map((message) => message.displayText).toList(),
      "queuedMessages",
      [text],
    )
    .having((state) => state.sendingSubmission, "sendingSubmission", isNull);

Matcher _sendingSubmission(String text) => isA<SessionDetailLoaded>()
    .having((state) => state.queuedMessages, "queuedMessages", isEmpty)
    .having((state) => state.sendingSubmission?.displayText, "sendingSubmission", text);

final Matcher _noPendingSubmission = isA<SessionDetailLoaded>()
    .having((state) => state.queuedMessages, "queuedMessages", isEmpty)
    .having((state) => state.sendingSubmission, "sendingSubmission", isNull);

void _stubPromptAttachmentCapability({
  required MockPluginRepository repository,
  required String pluginId,
  required bool supportsPromptAttachments,
}) {
  when(() => repository.listPlugins()).thenAnswer(
    (_) async => ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-test",
        supportsSessionOptions: true,
        plugins: [
          PluginMetadata(
            id: pluginId,
            displayName: "Test Plugin",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
            supportsPromptAttachments: supportsPromptAttachments,
          ),
        ],
      ),
    ),
  );
}

Future<void> _awaitLoaded(SessionDetailCubit cubit) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded,
    description: "SessionDetailLoaded",
  );
}

Future<void> _awaitQueuedMessages(SessionDetailCubit cubit, Matcher matcher) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded && matcher.matches(state.queuedMessages, <Object, Object>{}),
    description: "queued messages matching $matcher",
  );
}

Future<void> _awaitNotRefreshing(SessionDetailCubit cubit) async {
  await awaitState(
    cubit: cubit,
    predicate: (state) => state is SessionDetailLoaded && !state.isRefreshing,
    description: "non-refreshing SessionDetailLoaded",
  );
}

void _stubAllDefaults(
  MockSessionRepository service,
  MockSessionRepository sessionService,
  MockConnectionService connectionService, {
  required String sessionId,
  required MockNotificationCanceller notificationCanceller,
  required BehaviorSubject<SesoriSessionEvent> sessionEvents,
  required BehaviorSubject<SseEvent> globalEvents,
  required BehaviorSubject<ConnectionStatus> connectionStatus,
}) {
  when(
    () => service.getMessages(
      sessionId: any(named: "sessionId"),
      limit: any(named: "limit"),
      before: any(named: "before"),
      storedOnly: any(named: "storedOnly"),
    ),
  ).thenAnswer(
    (_) => Future<ApiResponse<MessageWithPartsResponse>>.value(
      ApiResponse.success(
        MessageWithPartsResponse(
          messages: [testMessageWithParts()],
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
    (_) => Future<ApiResponse<Agents>>.value(
      ApiResponse.success(Agents(agents: [testAgentInfo()])),
    ),
  );
  when(
    () => service.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (_) => Future<ApiResponse<ProviderListResponse>>.value(
      ApiResponse.success(testProviderListResponse()),
    ),
  );
  when(
    () => sessionService.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
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
      config: const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null),
      health: testHealthResponse(),
    ),
  );
  when(
    () => connectionService.status,
  ).thenAnswer((_) => connectionStatus);

  when(
    () => notificationCanceller.cancelForSession(
      sessionId: any(named: "sessionId"),
    ),
  ).thenAnswer((_) async {});

  when(
    () => sessionService.sendMessage(
      promptId: any(named: "promptId"),
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      attachments: any(named: "attachments"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
  when(
    () => service.abortSession(
      sessionId: any(named: "sessionId"),
      subAgents: any(named: "subAgents"),
    ),
  ).thenAnswer((_) async => ApiResponse.success(false));
  when(
    () => service.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
  when(
    () => service.rejectQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));
}
