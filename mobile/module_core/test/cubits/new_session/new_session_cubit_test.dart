import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("NewSessionCubit", () {
    late MockSessionService mockSessionService;

    setUp(() {
      mockSessionService = MockSessionService();

      when(
        () => mockSessionService.listAgents(),
      ).thenAnswer((_) async => ApiResponse<Agents>.success(const Agents(agents: <AgentInfo>[])));
      when(() => mockSessionService.listProviders(projectId: any(named: "projectId"))).thenAnswer(
        (_) async => ApiResponse<ProviderListResponse>.success(
          const ProviderListResponse(items: [], connectedOnly: false),
        ),
      );
      when(() => mockSessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
        (_) async => ApiResponse<CommandListResponse>.success(const CommandListResponse(items: <CommandInfo>[])),
      );
    });

    NewSessionCubit buildCubit() => NewSessionCubit(
      sessionService: mockSessionService,
      projectId: "project-1",
    );

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
      build: () {
        when(() => mockSessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
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
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
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
        await cubit.createSession(
          text: "hello",
          dedicatedWorktree: false,
          command: null,
        );
      },
      expect: () => [
        isA<NewSessionSending>(),
        isA<NewSessionSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
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
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
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
          projectId: "project-1",
        );
      },
      act: (cubit) async {
        await cubit.createSession(
          text: "",
          command: "review",
          dedicatedWorktree: true,
        );
      },
      expect: () => [
        isA<NewSessionSending>(),
        isA<NewSessionSending>(),
        isA<NewSessionCreated>(),
      ],
      verify: (_) {
        verify(
          () => mockSessionService.createSessionWithMessage(
            projectId: "project-1",
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
      build: () {
        when(() => mockSessionService.listAgents()).thenAnswer(
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
        await Future<void>.delayed(Duration.zero);
        cubit.selectVariant(const SessionVariant(id: "xhigh"));
        await cubit.createSession(
          text: "hello",
          dedicatedWorktree: true,
          command: null,
        );
      },
      expect: () => [
        isA<NewSessionIdle>()
            .having((state) => state.selectedAgentModel?.variant, "selectedAgentModel.variant", isNull),
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
      "selectAgent changes agent without affecting selected model variant",
      build: () {
        when(() => mockSessionService.listAgents()).thenAnswer(
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
        cubit.selectAgent("oracle");
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
            .having((state) => state.selectedAgent, "selectedAgent", "oracle")
            .having((state) => state.selectedAgentModel?.variant, "selectedAgentModel.variant preserved", "xhigh"),
      ],
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectModel updates selectedAgentModel to the chosen model variant",
      build: () {
        when(() => mockSessionService.listAgents()).thenAnswer(
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
        cubit.selectModel("anthropic", "claude-3");
      },
      expect: () => [
        isA<NewSessionIdle>().having(
          (state) => state.selectedAgentModel,
          "initial selectedAgentModel",
          const AgentModel(providerID: "openai", modelID: "gpt-4", variant: "fast"),
        ),
        isA<NewSessionIdle>()
            .having(
              (state) => state.selectedAgentModel,
              "selectedAgentModel",
              const AgentModel(providerID: "anthropic", modelID: "claude-3", variant: "deep"),
            ),
      ],
    );
  });
}
