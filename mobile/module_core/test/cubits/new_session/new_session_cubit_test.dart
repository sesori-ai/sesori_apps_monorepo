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

      // Stub agent/provider fetches that fire on cubit construction.
      when(
        () => mockSessionService.listAgents(),
      ).thenAnswer((_) async => ApiResponse<List<AgentInfo>>.success(<AgentInfo>[]));
      when(() => mockSessionService.listProviders()).thenAnswer(
        (_) async => ApiResponse<ProviderListResponse>.success(
          const ProviderListResponse(items: [], connectedOnly: false),
        ),
      );
    });

    NewSessionCubit buildCubit() => NewSessionCubit(
      sessionService: mockSessionService,
      projectId: "project-1",
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
        // First sending is from createSessionWithMessage.
        isA<NewSessionSending>(),
        // _loadAgentModelData may resolve during the request, emitting an
        // updated NewSessionSending with default agent/model values.
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
  });
}
