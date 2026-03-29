import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  group("NewSessionCubit", () {
    late MockSessionService mockSessionService;

    setUp(() {
      mockSessionService = MockSessionService();
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
          agent: null,
          model: null,
          dedicatedWorktree: false,
        );
      },
      expect: () => [
        const NewSessionState.sending(),
        NewSessionState.created(session: testSession(id: "s1")),
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
