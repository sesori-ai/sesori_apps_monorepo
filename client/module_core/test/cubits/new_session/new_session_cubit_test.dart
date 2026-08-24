import "dart:async";
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_submission_snapshot.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/services/models/new_session_backend_scope.dart";
import "package:sesori_dart_core/src/services/models/new_session_options_source.dart";
import "package:sesori_dart_core/src/services/models/new_session_selection_intent.dart";
import "package:sesori_dart_core/src/services/new_session_options_service.dart";
import "package:sesori_dart_core/src/services/new_session_plugin_service.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_dart_core/src/utils/model_filter/default_model_selector.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "new_session_state_matchers.dart";

void main() {
  group("NewSessionCubit", () {
    late MockSessionRepository mockSessionService;
    late MockSessionRepository mockSessionRepository;
    late MockPluginRepository mockPluginRepository;
    late MockPluginPreferenceRepository mockPluginPreferenceRepository;
    late MockConnectionService mockConnectionService;
    late BehaviorSubject<ConnectionStatus> connectionStatus;
    late MockProjectRepository mockProjectRepository;
    late NewSessionSelectionTracker selectionTracker;
    late MockProductAnalyticsService mockProductAnalyticsService;

    const defaultPlugin = PluginMetadata(
      id: "plugin-1",
      displayName: "Plugin One",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );

    setUpAll(registerAllFallbackValues);

    setUp(() {
      mockSessionService = MockSessionRepository();
      mockSessionRepository = MockSessionRepository();
      mockPluginRepository = MockPluginRepository();
      mockPluginPreferenceRepository = MockPluginPreferenceRepository();
      mockConnectionService = MockConnectionService();
      connectionStatus = BehaviorSubject.seeded(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
          health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
        ),
      );
      mockProjectRepository = MockProjectRepository();
      selectionTracker = NewSessionSelectionTracker();
      selectionTracker.applyBackendScopeTransition(
        transition: selectionTracker.backendScope.transitionToDiscovered(bridgeId: "bridge-1"),
      );
      mockProductAnalyticsService = stubbedProductAnalyticsService();

      when(() => mockConnectionService.status).thenAnswer((_) => connectionStatus.stream);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => connectionStatus.value);

      when(mockPluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-1",
            supportsSessionOptions: true,
            plugins: [defaultPlugin],
          ),
        ),
      );
      when(
        () => mockPluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
      ).thenAnswer((_) async => null);
      when(
        () => mockPluginPreferenceRepository.writePluginId(
          bridgeId: any(named: "bridgeId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse<Agents>.success(const Agents(agents: <AgentInfo>[])));
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse<ProviderListResponse>.success(
          const ProviderListResponse(items: [], connectedOnly: false),
        ),
      );
      delegateSessionOptionsRepository(
        repository: mockSessionRepository,
        source: mockSessionService,
      );
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse<CommandListResponse>.success(const CommandListResponse(items: <CommandInfo>[])),
      );
      when(
        () => mockProjectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Project(
            id: "project-1",
            name: "Project",
            path: "/project",
            time: null,
            supportsDedicatedWorktrees: true,
          ),
        ),
      );
    });

    tearDown(() => connectionStatus.close());

    NewSessionCubit buildCubit({ComposerDraftRepository? composerDraftRepository}) => NewSessionCubit(
      connectionService: mockConnectionService,
      sessionRepository: mockSessionService,
      newSessionPluginService: NewSessionPluginService(
        pluginRepository: mockPluginRepository,
        pluginPreferenceRepository: mockPluginPreferenceRepository,
      ),
      newSessionOptionsService: NewSessionOptionsService(
        sessionRepository: mockSessionRepository,
        defaultModelSelector: const DefaultModelSelector(),
      ),
      projectRepository: mockProjectRepository,
      selectionTracker: selectionTracker,
      composerDraftRepository: composerDraftRepository ?? inMemoryComposerDraftRepository(),
      productAnalyticsService: mockProductAnalyticsService,
      projectId: "project-1",
    );

    Future<void> waitForComposer(NewSessionCubit cubit) async {
      while (cubit.state.agentModelData?.isLoading ?? true) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test("defaults selectedAgentModel to null", () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(
        cubit.state,
        composingWith<NewSessionPhaseIdle>().having((state) => state.selectedAgentModel, "selectedAgentModel", isNull),
      );
    });

    test("option payloads participate in structural NewSessionState equality", () {
      NewSessionState buildState() => const NewSessionState.composing(
        config: NewSessionComposeConfig(
          availablePlugins: [defaultPlugin],
          selectedPlugin: defaultPlugin,
          options: NewSessionOptionsAvailableState(
            options: NewSessionOptionsData(
              agents: [],
              providers: [],
              commands: [],
              selectedAgent: null,
              selectedAgentModel: null,
              stagedCommand: null,
              availableVariants: [],
            ),
            source: NewSessionOptionsSource.aggregate,
          ),
          backendScope: NewSessionBackendScope.verified(bridgeId: "bridge-1"),
          isPluginDiscoveryInFlight: false,
          projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
        ),
        phase: NewSessionPhase.idle(),
      );

      final first = buildState();
      final second = buildState();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test("project capability starts loading and gates creation", () async {
      final projectResponse = Completer<ApiResponse<Project>>();
      when(
        () => mockProjectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer((_) => projectResponse.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.loading,
      );
      expect(cubit.canCreateSession, isFalse);
      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );
      verifyNever(
        () => mockSessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      );
      projectResponse.complete(ApiResponse.success(testProject()));
      await waitForComposer(cubit);
      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.supported,
      );
      expect(cubit.canCreateSession, isTrue);
    });

    test("project capability failure blocks creation until retry succeeds", () async {
      var attempts = 0;
      when(
        () => mockProjectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer((_) async {
        attempts++;
        return attempts == 1 ? ApiResponse.error(ApiError.generic()) : ApiResponse.success(testProject());
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.unavailable,
      );
      expect(cubit.canCreateSession, isFalse);
      expect(cubit.canRefreshOptions, isTrue);

      await cubit.refreshOptions();

      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.supported,
      );
      expect(cubit.canCreateSession, isTrue);
    });

    blocTest<NewSessionCubit, NewSessionState>(
      "loads available commands into idle state",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listCommands(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const CommandListResponse(
              items: <CommandInfo>[
                CommandInfo(
                  name: "review",
                  template: "/review",
                  hints: <String>["file.dart"],
                  description: null,
                  agent: null,
                  model: null,
                  provider: null,
                  source: CommandSource.command,
                  subtask: false,
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.availableCommands.map((c) => c.name).toList(),
          "commands",
          [
            "review",
          ],
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession refuses a command carrying attachments instead of dropping them",
      skip: 2,
      build: buildCubit,
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          draft: ComposerDraft.typed(text: "look at this"),
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
          dedicatedWorktree: false,
          command: "review",
        );
      },
      // The bridge's command paths carry only text, so the send is refused
      // outright rather than reaching the service with the images stripped.
      expect: () => [composingWith<NewSessionPhaseIdle>()],
      verify: (_) {
        verifyNever(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        );
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession forwards attachments when the plugin declares support",
      skip: 2,
      build: () {
        when(mockPluginRepository.listPlugins).thenAnswer(
          (_) async => ApiResponse.success(
            PluginDiscoverySnapshot(
              bridgeId: "bridge-1",
              supportsSessionOptions: true,
              plugins: const [
                PluginMetadata(
                  id: "codex",
                  displayName: "Codex",
                  isDefault: true,
                  state: PluginLifecycleState.ready,
                  actionHint: null,
                  supportsPromptAttachments: true,
                ),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));
        return buildCubit();
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          draft: ComposerDraft.typed(text: "look at this"),
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
          dedicatedWorktree: false,
          command: null,
        );
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>(),
        composingWith<NewSessionPhaseSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
            pluginId: "codex",
            text: "look at this",
            attachments: any(named: "attachments", that: hasLength(1)),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: null,
            dedicatedWorktree: false,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession refuses attachments when the plugin declares no support",
      skip: 2,
      build: buildCubit,
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          draft: ComposerDraft.typed(text: "look at this"),
          attachments: [ComposerAttachment(mime: "image/png", bytes: Uint8List(4), filename: "shot.png")],
          dedicatedWorktree: false,
          command: null,
        );
      },
      // Refused before the send even starts: the composer settles into idle
      // and no sending state follows it.
      expect: () => [composingWith<NewSessionPhaseIdle>()],
      verify: (_) {
        verifyNever(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            attachments: any(named: "attachments"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        );
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession forwards dedicatedWorktree to service",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));
        return buildCubit();
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          attachments: const [],
          draft: ComposerDraft(text: "hello", voiceSpans: [VoiceOriginSpan(start: 0, end: 5)]),
          dedicatedWorktree: false,
          command: null,
        );
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>(),
        composingWith<NewSessionPhaseSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "hello",
            agent: null,
            model: null,
            variant: null,
            command: null,
            dedicatedWorktree: false,
          ),
        ).called(1);
        verify(
          () => mockProductAnalyticsService.logEvent(
            event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
              submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.voiceAssisted),
              workspaceKind: AnalyticsWorkspaceKind.project,
            ),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession with command passes command name to service",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-command")));
        return NewSessionCubit(
          connectionService: mockConnectionService,
          sessionRepository: mockSessionService,
          newSessionPluginService: NewSessionPluginService(
            pluginRepository: mockPluginRepository,
            pluginPreferenceRepository: mockPluginPreferenceRepository,
          ),
          newSessionOptionsService: NewSessionOptionsService(
            sessionRepository: mockSessionRepository,
            defaultModelSelector: const DefaultModelSelector(),
          ),
          projectRepository: mockProjectRepository,
          selectionTracker: selectionTracker,
          composerDraftRepository: inMemoryComposerDraftRepository(),
          productAnalyticsService: stubbedProductAnalyticsService(),
          projectId: "project-1",
        );
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          attachments: const [],
          draft: ComposerDraft.typed(text: ""),
          command: "review",
          dedicatedWorktree: true,
        );
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>(),
        composingWith<NewSessionPhaseSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "",
            agent: null,
            model: null,
            variant: null,
            command: "review",
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );

    test("successful creation reports the workspace returned by the bridge", () async {
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          testSession(id: "s-fallback").copyWith(hasWorktree: false),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verify(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
            submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
            workspaceKind: AnalyticsWorkspaceKind.project,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(1);
    });

    test("failed creation reports only a bounded failure outcome", () async {
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.dartHttpClient(Exception("private transport detail")),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft(text: "sensitive prompt", voiceSpans: [VoiceOriginSpan(start: 0, end: 9)]),
        dedicatedWorktree: false,
        command: null,
      );

      verify(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionCreationFailed(
            failureReason: AnalyticsSessionCreationFailureReason.networkDown,
            workspaceKind: AnalyticsWorkspaceKind.project,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(1);
      verifyNever(
        () => mockProductAnalyticsService.logEvent(
          event: any(named: "event", that: isA<SessionCreatedWithMessageEvent>()),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });

    test("failed text submission restores exact voice draft and attachment identities until acknowledged", () async {
      final response = Completer<ApiResponse<Session>>();
      final repository = inMemoryComposerDraftRepository();
      final attachment = ComposerAttachment(
        mime: "image/png",
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: "shot.png",
      );
      final attachments = [attachment];
      final draft = ComposerDraft(
        text: "typed voice",
        voiceSpans: [VoiceOriginSpan(start: 6, end: 11)],
      );
      when(mockPluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-1",
            supportsSessionOptions: true,
            plugins: const [
              PluginMetadata(
                id: "plugin-1",
                displayName: "Plugin One",
                isDefault: true,
                state: PluginLifecycleState.ready,
                actionHint: null,
                supportsPromptAttachments: true,
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          attachments: any(named: "attachments"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => response.future);
      final cubit = buildCubit(composerDraftRepository: repository);
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      final pending = cubit.createSession(
        draft: draft,
        dedicatedWorktree: false,
        command: null,
        attachments: attachments,
      );
      attachments.clear();
      cubit.clearComposerDraft();

      final sending = (cubit.state as NewSessionComposing).phase as NewSessionPhaseSending;
      final snapshot = sending.submission as NewSessionTextSubmissionSnapshot;
      expect(snapshot.draft, same(draft));
      expect(snapshot.attachments.single, same(attachment));
      expect(() => snapshot.attachments.add(attachment), throwsUnsupportedError);

      response.complete(ApiResponse.error(ApiError.generic()));
      await pending;

      final restoring = (cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission;
      expect(restoring.submission, same(snapshot));
      expect(cubit.composerDraft, same(draft));
      expect(repository.readForNewSession(projectId: "project-1"), same(draft));
      expect(restoring.submission.draft.voiceSpans, draft.voiceSpans);

      cubit.acknowledgeRestoredSubmission(submission: snapshot);
      expect(cubit.state, composingWith<NewSessionPhaseCreationError>());
    });

    test("failed command submission restores staged command and next submit clears warning", () async {
      final firstResponse = Completer<ApiResponse<Session>>();
      final secondResponse = Completer<ApiResponse<Session>>();
      var calls = 0;
      final command = testCommandInfo();
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => calls++ == 0 ? firstResponse.future : secondResponse.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);
      cubit.stageCommand(command);

      final first = cubit.createSession(
        draft: ComposerDraft.typed(text: ""),
        dedicatedWorktree: false,
        command: command.name,
        attachments: const [],
      );
      cubit.clearStagedCommand();
      firstResponse.complete(ApiResponse.error(ApiError.generic()));
      await first;

      final restoring = (cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission;
      expect(restoring.submission, isA<NewSessionCommandSubmissionSnapshot>());
      expect(cubit.state.stagedCommand, command);
      cubit.acknowledgeRestoredSubmission(submission: restoring.submission);
      expect(cubit.state, composingWith<NewSessionPhaseCreationError>());

      final second = cubit.createSession(
        draft: ComposerDraft.typed(text: "next"),
        dedicatedWorktree: false,
        command: null,
        attachments: const [],
      );
      expect(cubit.state, composingWith<NewSessionPhaseSending>());
      secondResponse.complete(ApiResponse.success(testSession(id: "next")));
      await second;
      expect(cubit.state, isA<NewSessionCreated>());
    });

    test("failed background submission does not restore shared draft or command after close", () async {
      final response = Completer<ApiResponse<Session>>();
      final repository = inMemoryComposerDraftRepository();
      final command = testCommandInfo();
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => response.future);
      final cubit = buildCubit(composerDraftRepository: repository);
      await waitForComposer(cubit);
      cubit.stageCommand(command);

      final pending = cubit.createSession(
        draft: ComposerDraft.typed(text: "abandoned"),
        dedicatedWorktree: false,
        command: command.name,
        attachments: const [],
      );
      cubit
        ..clearComposerDraft()
        ..clearStagedCommand();
      await cubit.close();
      response.complete(ApiResponse.error(ApiError.generic()));
      await pending;

      expect(repository.readForNewSession(projectId: "project-1").text, isEmpty);
      expect(cubit.state.stagedCommand, isNull);
    });

    test("options and discovery refreshes preserve restoring submission and creation error variants", () async {
      final response = Completer<ApiResponse<Session>>();
      var discoveryCalls = 0;
      when(mockPluginRepository.listPlugins).thenAnswer((_) async {
        discoveryCalls++;
        return ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: "bridge-1",
            supportsSessionOptions: true,
            plugins: const [defaultPlugin],
          ),
        );
      });
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => response.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      final pending = cubit.createSession(
        draft: ComposerDraft.typed(text: "restore"),
        dedicatedWorktree: false,
        command: null,
        attachments: const [],
      );
      response.complete(ApiResponse.error(ApiError.generic()));
      await pending;
      final restoring = (cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission;

      await cubit.refreshOptions();
      expect(cubit.state, composingWith<NewSessionPhaseRestoringSubmission>());
      expect(
        ((cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission).submission,
        same(restoring.submission),
      );

      connectionStatus
        ..add(const ConnectionStatus.disconnected())
        ..add(
          const ConnectionStatus.connected(
            config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
            health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
          ),
        );
      while (discoveryCalls < 2 || (cubit.state.agentModelData?.isLoading ?? true)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(cubit.state, composingWith<NewSessionPhaseRestoringSubmission>());
      expect(
        ((cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission).submission,
        same(restoring.submission),
      );

      cubit.acknowledgeRestoredSubmission(submission: restoring.submission);
      await cubit.refreshOptions();
      expect(cubit.state, composingWith<NewSessionPhaseCreationError>());
    });

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

    test("send-owned command clear survives an error and retry", () async {
      final firstCreate = Completer<ApiResponse<Session>>();
      var createCalls = 0;
      final command = testCommandInfo();
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [command])));
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) {
        createCalls++;
        if (createCalls == 1) return firstCreate.future;
        return Future.value(ApiResponse.success(testSession(id: "s-command-retry")));
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);
      cubit.stageCommand(command);
      final modelBeforeSend = cubit.state.agentModelData?.agentModel;

      final pendingCreate = cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: ""),
        command: command.name,
        dedicatedWorktree: true,
      );
      expect(cubit.state, composingWith<NewSessionPhaseSending>());

      cubit.clearStagedCommand();
      cubit.stageCommand(command);
      cubit.selectModel(providerID: "other-provider", modelID: "other-model");

      expect(cubit.state.agentModelData?.stagedCommand, isNull);
      expect(cubit.state.agentModelData?.agentModel, modelBeforeSend);

      firstCreate.complete(ApiResponse.error(ApiError.generic()));
      await pendingCreate;

      expect(cubit.state, composingWith<NewSessionPhaseRestoringSubmission>());
      expect(cubit.state.agentModelData?.stagedCommand, command);

      final restored = (cubit.state as NewSessionComposing).phase as NewSessionPhaseRestoringSubmission;
      cubit.acknowledgeRestoredSubmission(submission: restored.submission);
      expect(cubit.state, composingWith<NewSessionPhaseCreationError>());

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "retry"),
        command: cubit.state.agentModelData?.stagedCommand?.name,
        dedicatedWorktree: true,
      );

      verify(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: "",
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: command.name,
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).called(1);
      verify(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: "retry",
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: command.name,
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).called(1);
    });

    test("createSession disables a requested worktree when the project does not support it", () async {
      when(
        () => mockProjectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Project(
            id: "project-1",
            name: "Plain folder",
            path: "/plain-folder",
            time: null,
            supportsDedicatedWorktrees: false,
          ),
        ),
      );
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-no-worktree")));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);
      expect(
        cubit.state.agentModelData?.projectWorktreeCapability,
        NewSessionProjectWorktreeCapability.unsupported,
      );

      await cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );

      verify(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: "project-1",
          pluginId: "plugin-1",
          text: "hello",
          agent: null,
          model: null,
          variant: null,
          command: null,
          dedicatedWorktree: false,
        ),
      ).called(1);
    });

    blocTest<NewSessionCubit, NewSessionState>(
      "selectVariant updates state and createSession forwards variant",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_providerResponseWithVariants(["high", "xhigh"])));
        when(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-effort")));
        return buildCubit();
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        cubit.selectVariant(const SessionVariant(id: "xhigh"));
        await cubit.createSession(
          attachments: const [],
          draft: ComposerDraft.typed(text: "hello"),
          dedicatedWorktree: true,
          command: null,
        );
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "high",
        ),
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        composingWith<NewSessionPhaseSending>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "hello",
            agent: "build",
            model: const PromptModel(providerID: "openai", modelID: "gpt-4"),
            variant: const SessionVariant(id: "xhigh"),
            command: null,
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectAgent preserves the model variant when the agent has no model preference",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_providerResponseWithVariants(["high", "xhigh"])));
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
                AgentInfo(
                  name: "Plan",
                  description: "Plans before editing",
                  model: null,
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectVariant(const SessionVariant(id: "xhigh"));
        cubit.selectAgent("Plan");
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial selectedAgentModel.variant",
          "high",
        ),
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        composingWith<NewSessionPhaseIdle>()
            .having((state) => state.selectedAgent, "selectedAgent", "Plan")
            .having((state) => state.selectedAgentModel?.variant, "selectedAgentModel.variant preserved", "xhigh"),
      ],
    );

    for (final invalidSelection in [
      (name: "a provider from a stale picker", providerID: "stale-provider", modelID: "stale-model"),
      (name: "a model absent from the current provider", providerID: "active", modelID: "missing"),
      (name: "an unavailable model", providerID: "active", modelID: "offline"),
    ]) {
      test("selectModel ignores ${invalidSelection.name}", () async {
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
                  id: "active",
                  name: "Active",
                  defaultModelID: "current",
                  models: {
                    "current": ProviderModel(
                      id: "current",
                      providerID: "active",
                      name: "Current",
                      variants: [],
                      family: null,
                      releaseDate: null,
                    ),
                    "offline": ProviderModel(
                      id: "offline",
                      providerID: "active",
                      name: "Offline",
                      variants: [],
                      family: null,
                      isAvailable: false,
                      releaseDate: null,
                    ),
                  },
                ),
              ],
            ),
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await waitForComposer(cubit);
        final selectionBefore = cubit.state.agentModelData?.agentModel;

        cubit.selectModel(
          providerID: invalidSelection.providerID,
          modelID: invalidSelection.modelID,
        );

        expect(cubit.state.agentModelData?.agentModel, selectionBefore);
        expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
      });
    }

    blocTest<NewSessionCubit, NewSessionState>(
      "selectModel updates selectedAgentModel to the chosen model variant",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
                  mode: AgentMode.primary,
                ),
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectModel(providerID: "anthropic", modelID: "claude-3");
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "initial selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
        ),
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
        ),
      ],
    );

    test("selectModel resolves the new model's first variant when the previous one is unavailable", () async {
      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Agents(
            agents: [
              AgentInfo(
                name: "build",
                description: "Build",
                model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
                mode: AgentMode.primary,
              ),
              AgentInfo(
                name: "build",
                description: "Build",
                model: AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
                mode: AgentMode.primary,
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      cubit.selectModel(providerID: "anthropic", modelID: "claude-3");

      expect(
        cubit.state.agentModelData?.agentModel,
        const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
      );
    });

    test("selectAgent preserves an independent explicit model intent", () async {
      selectionTracker.recordModel(
        projectId: "project-1",
        pluginId: "plugin-1",
        providerId: "openai",
        modelId: "gpt-4",
      );
      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Agents(
            agents: [
              AgentInfo(
                name: "build",
                description: "Build",
                model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
                mode: AgentMode.primary,
              ),
              AgentInfo(
                name: "plan",
                description: "Plan",
                model: AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
                mode: AgentMode.primary,
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      cubit.selectAgent("plan");

      expect(cubit.state.agentModelData?.agent, "plan");
      expect(
        cubit.state.agentModelData?.agentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
      );
      expect(
        selectionTracker.read(projectId: "project-1", pluginId: "plugin-1")?.model,
        isA<NewSessionModelIntent>()
            .having((intent) => intent.providerId, "providerId", "openai")
            .having((intent) => intent.modelId, "modelId", "gpt-4"),
      );
    });

    blocTest<NewSessionCubit, NewSessionState>(
      "selectModel resolves a provider-only model to its first variant",
      skip: 2,
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
                      variants: [],
                      family: null,
                      releaseDate: null,
                    ),
                    "gpt-5": ProviderModel(
                      id: "gpt-5",
                      providerID: "openai",
                      name: "GPT-5",
                      variants: ["provisional-effort", "high"],
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
        await Future<void>.delayed(Duration.zero);
        cubit.selectModel(providerID: "openai", modelID: "gpt-5");
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "initial selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
        ),
        composingWith<NewSessionPhaseIdle>()
            .having(
              (state) => state.availableVariants.map((variant) => variant.id),
              "availableVariants",
              ["provisional-effort", "high"],
            )
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              const AgentModel(providerID: "openai", modelID: "gpt-5", variant: "provisional-effort"),
            ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectVariant switches selectedAgentModel to another available variant",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
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
        await Future<void>.delayed(Duration.zero);
        cubit.selectVariant(const SessionVariant(id: "slow"));
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial variant",
          "fast",
        ),
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "variant",
          "slow",
        ),
      ],
    );

    test("selectVariant ignores a variant absent from the current catalog", () async {
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_providerResponseWithVariants(["fast"])));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);
      final selectionBefore = cubit.state.agentModelData?.agentModel;

      cubit.selectVariant(const SessionVariant(id: "stale"));

      expect(cubit.state.agentModelData?.agentModel, selectionBefore);
      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    });

    test("stageCommand accepts an equivalent current command and rejects a stale one", () async {
      final availableCommand = testCommandInfo();
      final equivalentCommand = testCommandInfo();
      final staleCommand = testCommandInfo(template: "/review {{stalePath}}");
      expect(identical(availableCommand, equivalentCommand), isFalse);
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(CommandListResponse(items: [availableCommand])));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      cubit.stageCommand(equivalentCommand);
      expect(cubit.state.agentModelData?.stagedCommand, equivalentCommand);

      cubit.stageCommand(staleCommand);
      expect(cubit.state.agentModelData?.stagedCommand, equivalentCommand);
    });

    // --- Selection persistence across navigation (NewSessionSelectionTracker) ---

    test("selectAgent persists only the deliberate agent dimension", () async {
      when(
        () => mockSessionService.listAgents(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const Agents(
            agents: [
              AgentInfo(
                name: "build",
                description: "Build",
                model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
                mode: AgentMode.primary,
              ),
              AgentInfo(
                name: "plan",
                description: "Plan",
                model: AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
                mode: AgentMode.primary,
              ),
            ],
          ),
        ),
      );
      when(
        () => mockSessionService.listProviders(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await waitForComposer(cubit);

      cubit.selectAgent("plan");

      final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "plan");
      expect(saved?.model, isNull);
      expect(saved?.variant, isNull);
    });

    blocTest<NewSessionCubit, NewSessionState>(
      "persists only the deliberate variant dimension",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_providerResponseWithVariants(["xhigh"])));
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectVariant(const SessionVariant(id: "xhigh"));
      },
      verify: (_) {
        final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
        expect(saved?.agentName, isNull);
        expect(saved?.model, isNull);
        expect(
          saved?.variant,
          isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "xhigh"),
        );
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "persists only the deliberate model dimension",
      skip: 2,
      build: () {
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectModel(providerID: "anthropic", modelID: "claude-3");
      },
      verify: (_) {
        final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
        expect(saved?.agentName, isNull);
        expect(saved?.model?.providerId, "anthropic");
        expect(saved?.model?.modelId, "claude-3");
        expect(saved?.variant, isNull);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "restores a persisted model + variant on load, overriding the default",
      skip: 2,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(
            agentName: null,
            agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
          ),
        );
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
                      variants: [],
                      family: null,
                      releaseDate: null,
                    ),
                  },
                ),
                ProviderInfo(
                  id: "anthropic",
                  name: "Anthropic",
                  defaultModelID: "claude-3",
                  models: {
                    "claude-3": ProviderModel(
                      id: "claude-3",
                      providerID: "anthropic",
                      name: "Claude 3",
                      variants: ["deep"],
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
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "replaces a persisted variant the restored model no longer offers",
      skip: 2,
      build: () {
        // Seed a model from a DIFFERENT provider than the computed default
        // (openai/gpt-4, the first provider) so a regression that discarded the
        // saved model entirely would surface openai/gpt-4 and fail this test —
        // i.e. it genuinely exercises variant-dropping, not full fallback.
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(
            agentName: null,
            agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "legacy"),
          ),
        );
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
                      variants: [],
                      family: null,
                      releaseDate: null,
                    ),
                  },
                ),
                ProviderInfo(
                  id: "anthropic",
                  name: "Anthropic",
                  defaultModelID: "claude-3",
                  models: {
                    "claude-3": ProviderModel(
                      id: "claude-3",
                      providerID: "anthropic",
                      name: "Claude 3",
                      variants: ["fast"],
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
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          // Saved model restored; the no-longer-offered "legacy" variant falls
          // back to the model's first available one.
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "fast"),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "restores a persisted non-default agent on load",
      skip: 2,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(agentName: "plan", agentModel: null),
        );
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
                AgentInfo(
                  name: "plan",
                  description: "Plan",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgent,
          "selectedAgent",
          "plan",
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "falls back to the default agent when the persisted agent is gone",
      skip: 2,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(agentName: "ghost", agentModel: null),
        );
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgent,
          "selectedAgent",
          "build",
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "falls back to the default when the persisted model is no longer available",
      skip: 2,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(
            agentName: null,
            agentModel: const AgentModel(providerID: "ghost", modelID: "gone", variant: null),
          ),
        );
        when(
          () => mockSessionService.listAgents(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Agents(
              agents: [
                AgentInfo(
                  name: "build",
                  description: "Build",
                  model: AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
                  mode: AgentMode.primary,
                ),
              ],
            ),
          ),
        );
        when(
          () => mockSessionService.listProviders(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(_modelSelectionProviders));
        return buildCubit();
      },
      expect: () => [
        composingWith<NewSessionPhaseIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "clears the persisted selection once the session is created",
      skip: 2,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          selection: _selectionIntentFromSnapshot(
            agentName: "build",
            agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
          ),
        );
        when(
          () => mockSessionService.createSessionWithMessage(
            attachments: const [],
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-clear")));
        return buildCubit();
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          attachments: const [],
          draft: ComposerDraft.typed(text: "hello"),
          dedicatedWorktree: true,
          command: null,
        );
      },
      verify: (_) {
        expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
      },
    );

    test("clears the persisted selection on success even when the cubit was closed mid-send", () async {
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: _selectionIntentFromSnapshot(
          agentName: "build",
          agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
        ),
      );
      final completer = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      await waitForComposer(cubit);
      // Kick off creation but don't await — the request is now in flight.
      final pending = cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hello"),
        dedicatedWorktree: true,
        command: null,
      );
      // The user backs out while sending; the screen disposes the cubit.
      await cubit.close();
      // The launch still succeeds in the background after the cubit is gone.
      completer.complete(ApiResponse.success(testSession(id: "s-bg")));
      await pending;

      expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
    });

    test("a late background success only clears the snapshot it was sent with, not a newer one", () async {
      final completer = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => completer.future);

      // The in-flight request was sent with selection V1.
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: _selectionIntentFromSnapshot(
          agentName: "build",
          agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "low"),
        ),
      );
      final cubit = buildCubit();
      await waitForComposer(cubit);
      final pending = cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hi"),
        dedicatedWorktree: true,
        command: null,
      );
      // User backs out; the screen disposes this cubit.
      await cubit.close();
      // A reopened composer writes a newer selection V2 for the same project
      // while the first request is still in flight.
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: _selectionIntentFromSnapshot(
          agentName: "build",
          agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "high"),
        ),
      );
      // The first launch now succeeds in the background.
      completer.complete(ApiResponse.success(testSession(id: "s-late")));
      await pending;

      // V2 must survive — the late success only owned V1.
      final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "build");
      expect(saved?.model?.providerId, "openai");
      expect(saved?.model?.modelId, "gpt-4");
      expect(
        saved?.variant,
        isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", "high"),
      );
    });

    test("a late background success preserves an equal selection from a newer write", () async {
      final completer = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => completer.future);

      const model = AgentModel(providerID: "openai", modelID: "gpt-4", variant: "low");
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: _selectionIntentFromSnapshot(agentName: "build", agentModel: model),
      );
      final cubit = buildCubit();
      await waitForComposer(cubit);
      final pending = cubit.createSession(
        attachments: const [],
        draft: ComposerDraft.typed(text: "hi"),
        dedicatedWorktree: true,
        command: null,
      );
      await cubit.close();

      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        selection: _selectionIntentFromSnapshot(agentName: "build", agentModel: model),
      );
      completer.complete(ApiResponse.success(testSession(id: "s-late-equal")));
      await pending;

      final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
      expect(saved?.agentName, "build");
      expect(saved?.model?.providerId, model.providerID);
      expect(saved?.model?.modelId, model.modelID);
      expect(
        saved?.variant,
        isA<NewSessionVariantIntent>().having((variant) => variant.id, "id", model.variant),
      );
    });
  });
}

NewSessionSelectionIntent _selectionIntentFromSnapshot({
  required String? agentName,
  required AgentModel? agentModel,
}) {
  final variant = agentModel?.variant;
  return NewSessionSelectionIntent(
    agentName: agentName,
    model: agentModel == null
        ? null
        : NewSessionModelIntent(
            providerId: agentModel.providerID,
            modelId: agentModel.modelID,
          ),
    variant: variant == null ? null : NewSessionVariantIntent(id: variant),
  );
}

const _modelSelectionProviders = ProviderListResponse(
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
          variants: ["fast"],
          family: null,
          releaseDate: null,
        ),
      },
    ),
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      defaultModelID: "claude-3",
      models: {
        "claude-3": ProviderModel(
          id: "claude-3",
          providerID: "anthropic",
          name: "Claude 3",
          variants: ["deep"],
          family: null,
          releaseDate: null,
        ),
      },
    ),
  ],
);

ProviderListResponse _providerResponseWithVariants(List<String> variants) {
  return ProviderListResponse(
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
            variants: variants,
            family: null,
            releaseDate: null,
          ),
        },
      ),
    ],
  );
}
