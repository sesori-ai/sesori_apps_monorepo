import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_launch_command_store.dart";
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
      SessionLaunchCommandStore.instance.clear("s-command");
    });

    NewSessionCubit buildCubit() => NewSessionCubit(
      sessionService: mockSessionService,
      projectId: "project-1",
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "loads available commands into idle state",
      build: () {
        when(() => mockSessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
          (_) async => ApiResponse.success(
            const CommandListResponse(
              items: <CommandInfo>[
                CommandInfo(name: "review", template: "/review", hints: <String>["file.dart"]),
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
      "createSessionWithMessage forwards dedicatedWorktree to service",
      build: () {
        when(
          () => mockSessionService.createSessionWithMessage(
            projectId: any(named: "projectId"),
            text: any(named: "text"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s1")));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.createSessionWithMessage(
          text: "hello",
          dedicatedWorktree: false,
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
            model: null,
            dedicatedWorktree: false,
          ),
        ).called(1);
      },
    );

    blocTest<NewSessionCubit, NewSessionState>(
      "createSessionWithCommand creates an empty session and stages the launch command",
      build: () {
        when(
          () => mockSessionService.createEmptySession(
            projectId: any(named: "projectId"),
            agent: any(named: "agent"),
            model: any(named: "model"),
            dedicatedWorktree: any(named: "dedicatedWorktree"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(testSession(id: "s-command")));
        return NewSessionCubit(
          sessionService: mockSessionService,
          projectId: "project-1",
          launchCommandStore: SessionLaunchCommandStore.instance,
        );
      },
      act: (cubit) async {
        await cubit.createSessionWithCommand(
          command: testCommandInfo(name: "review"),
          arguments: "lib/main.dart",
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
          () => mockSessionService.createEmptySession(
            projectId: "project-1",
            agent: null,
            model: null,
            dedicatedWorktree: true,
          ),
        ).called(1);
        final launchCommand = SessionLaunchCommandStore.instance.take("s-command");
        expect(launchCommand, isNotNull);
        expect(launchCommand!.command.name, "review");
        expect(launchCommand.arguments, "lib/main.dart");
      },
    );
  });
}
