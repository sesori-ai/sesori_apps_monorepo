import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("NewSessionCubit", () {
    late MockSessionService mockSessionService;
    late MockPluginRepository mockPluginRepository;
    late NewSessionSelectionTracker selectionTracker;

    const defaultPlugin = PluginMetadata(
      id: "plugin-1",
      displayName: "Plugin One",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );

    setUp(() {
      mockSessionService = MockSessionService();
      mockPluginRepository = MockPluginRepository();
      selectionTracker = NewSessionSelectionTracker();

      when(mockPluginRepository.listPlugins).thenAnswer(
        (_) async => ApiResponse.success(const PluginListResponse(plugins: [defaultPlugin])),
      );

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
      when(
        () => mockSessionService.listCommands(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse<CommandListResponse>.success(const CommandListResponse(items: <CommandInfo>[])),
      );
    });

    NewSessionCubit buildCubit() => NewSessionCubit(
      sessionService: mockSessionService,
      pluginRepository: mockPluginRepository,
      selectionTracker: selectionTracker,
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
        isA<NewSessionIdle>().having((state) => state.selectedAgentModel, "selectedAgentModel", isNull),
      );
    });

    blocTest<NewSessionCubit, NewSessionState>(
      "loads available commands into idle state",
      skip: 1,
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
        isA<NewSessionIdle>().having((state) => state.availableCommands.map((c) => c.name).toList(), "commands", [
          "review",
        ]),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession forwards dedicatedWorktree to service",
      skip: 1,
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
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
          text: "hello",
          dedicatedWorktree: false,
          command: null,
        );
      },
      expect: () => [
        isA<NewSessionIdle>(),
        isA<NewSessionSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "hello",
            agent: null,
            providerID: null,
            modelID: null,
            variant: null,
            command: null,
            dedicatedWorktree: false,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSession with command passes command name to service",
      skip: 1,
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-command")));
        return NewSessionCubit(
          sessionService: mockSessionService,
          pluginRepository: mockPluginRepository,
          selectionTracker: selectionTracker,
          projectId: "project-1",
        );
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(
          text: "",
          command: "review",
          dedicatedWorktree: true,
        );
      },
      expect: () => [
        isA<NewSessionIdle>(),
        isA<NewSessionSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "",
            agent: null,
            providerID: null,
            modelID: null,
            variant: null,
            command: "review",
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectVariant updates state and createSession forwards variant",
      skip: 1,
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
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
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
          text: "hello",
          dedicatedWorktree: true,
          command: null,
        );
      },
      expect: () => [
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          isNull,
        ),
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        isA<NewSessionSending>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
            pluginId: "plugin-1",
            text: "hello",
            agent: "build",
            providerID: "openai",
            modelID: "gpt-4",
            variant: const SessionVariant(id: "xhigh"),
            command: null,
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectAgent preserves the model variant when the agent has no model preference",
      skip: 1,
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial selectedAgentModel.variant",
          isNull,
        ),
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "selectedAgentModel.variant",
          "xhigh",
        ),
        isA<NewSessionIdle>()
            .having((state) => state.selectedAgent, "selectedAgent", "Plan")
            .having((state) => state.selectedAgentModel?.variant, "selectedAgentModel.variant preserved", "xhigh"),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectModel updates selectedAgentModel to the chosen model variant",
      skip: 1,
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
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectModel(providerID: "anthropic", modelID: "claude-3");
      },
      expect: () => [
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "initial selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
        ),
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectModel leaves provider-only model variant at Default",
      skip: 1,
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "initial selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
        ),
        isA<NewSessionIdle>()
            .having(
              (state) => state.availableVariants.map((variant) => variant.id),
              "availableVariants",
              ["provisional-effort", "high"],
            )
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              const AgentModel(providerID: "openai", modelID: "gpt-5", variant: null),
            ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectVariant updates selectedAgentModel variant",
      skip: 1,
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
        cubit.selectVariant(const SessionVariant(id: "fast"));
      },
      expect: () => [
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial variant",
          isNull,
        ),
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "variant",
          "fast",
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectVariant to null clears selectedAgentModel variant",
      skip: 1,
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
        cubit.selectVariant(null);
      },
      expect: () => [
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "initial variant",
          "fast",
        ),
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel?.variant,
          "variant",
          isNull,
        ),
      ],
    );

    // --- Selection persistence across navigation (NewSessionSelectionTracker) ---

    blocTest<NewSessionCubit, NewSessionState>(
      "persists the chosen variant to the selection store",
      skip: 1,
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
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectVariant(const SessionVariant(id: "xhigh"));
      },
      verify: (_) {
        final saved = selectionTracker.read(projectId: "project-1", pluginId: "plugin-1");
        expect(saved?.agent, "build");
        expect(
          saved?.agentModel,
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
        );
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "persists the chosen model to the selection store",
      skip: 1,
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
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        cubit.selectModel(providerID: "anthropic", modelID: "claude-3");
      },
      verify: (_) {
        expect(
          selectionTracker.read(projectId: "project-1", pluginId: "plugin-1")?.agentModel,
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
        );
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "restores a persisted model + variant on load, overriding the default",
      skip: 1,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: null,
          agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "drops a persisted variant the restored model no longer offers",
      skip: 1,
      build: () {
        // Seed a model from a DIFFERENT provider than the computed default
        // (openai/gpt-4, the first provider) so a regression that discarded the
        // saved model entirely would surface openai/gpt-4 and fail this test —
        // i.e. it genuinely exercises variant-dropping, not full fallback.
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: null,
          agentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "legacy"),
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          // Saved model restored; the no-longer-offered "legacy" variant dropped.
          const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: null),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "restores a persisted non-default agent on load",
      skip: 1,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: "plan",
          agentModel: null,
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgent,
          "selectedAgent",
          "plan",
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "falls back to the default agent when the persisted agent is gone",
      skip: 1,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: "ghost",
          agentModel: null,
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgent,
          "selectedAgent",
          "build",
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "falls back to the default when the persisted model is no longer available",
      skip: 1,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: null,
          agentModel: const AgentModel(providerID: "ghost", modelID: "gone", variant: null),
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
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: null),
        ),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "clears the persisted selection once the session is created",
      skip: 1,
      build: () {
        selectionTracker.write(
          projectId: "project-1",
          pluginId: "plugin-1",
          agent: "build",
          agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
        );
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            pluginId: any(named: "pluginId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            variant: any(named: "variant"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-clear")));
        return buildCubit();
      },
      act: (cubit) async {
        await waitForComposer(cubit);
        await cubit.createSession(text: "hello", dedicatedWorktree: true, command: null);
      },
      verify: (_) {
        expect(selectionTracker.read(projectId: "project-1", pluginId: "plugin-1"), isNull);
      },
    );

    test("clears the persisted selection on success even when the cubit was closed mid-send", () async {
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "xhigh"),
      );
      final completer = Completer<ApiResponse<Session>>();
      when(
        () => mockSessionService.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = buildCubit();
      await waitForComposer(cubit);
      // Kick off creation but don't await — the request is now in flight.
      final pending = cubit.createSession(text: "hello", dedicatedWorktree: true, command: null);
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
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          providerID: any(named: "providerID"),
          modelID: any(named: "modelID"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => completer.future);

      // The in-flight request was sent with selection V1.
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "low"),
      );
      final cubit = buildCubit();
      await waitForComposer(cubit);
      final pending = cubit.createSession(text: "hi", dedicatedWorktree: true, command: null);
      // User backs out; the screen disposes this cubit.
      await cubit.close();
      // A reopened composer writes a newer selection V2 for the same project
      // while the first request is still in flight.
      selectionTracker.write(
        projectId: "project-1",
        pluginId: "plugin-1",
        agent: "build",
        agentModel: const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "high"),
      );
      // The first launch now succeeds in the background.
      completer.complete(ApiResponse.success(testSession(id: "s-late")));
      await pending;

      // V2 must survive — the late success only owned V1.
      expect(
        selectionTracker.read(projectId: "project-1", pluginId: "plugin-1")?.agentModel,
        const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "high"),
      );
    });
  });
}
