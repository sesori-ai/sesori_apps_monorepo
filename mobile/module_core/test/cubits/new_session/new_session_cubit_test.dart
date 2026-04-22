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
      when(() => mockSessionService.listProviders()).thenAnswer(
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

    test("defaults selectedEffort to medium", () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(
        cubit.state,
        isA<NewSessionIdle>().having((state) => state.selectedEffort, "selectedEffort", SessionEffort.medium),
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
            effort: any(named: "effort"),
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
            effort: SessionEffort.medium,
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
            effort: any(named: "effort"),
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
            effort: SessionEffort.medium,
            command: "review",
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "selectEffort updates state and createSession forwards effort",
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            providerID: any(named: "providerID"),
            modelID: any(named: "modelID"),
            effort: any(named: "effort"),
            command: any(named: "command"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-effort")));
        return buildCubit();
      },
      act: (cubit) async {
        cubit.selectEffort(SessionEffort.max);
        await cubit.createSession(
          text: "hello",
          dedicatedWorktree: true,
          command: null,
        );
      },
      expect: () => [
        isA<NewSessionIdle>().having((state) => state.selectedEffort, "selectedEffort", SessionEffort.max),
        isA<NewSessionSending>().having((state) => state.selectedEffort, "selectedEffort", SessionEffort.max),
        isA<NewSessionSending>().having((state) => state.selectedEffort, "selectedEffort", SessionEffort.max),
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
            effort: SessionEffort.max,
            command: null,
            dedicatedWorktree: true,
          ),
        ).called(1);
      },
    );
  });
}
