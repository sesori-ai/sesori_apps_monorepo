import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_action_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockWindow() extends Mock implements SessionWindowService;

class _MockActionService() extends Mock implements SessionActionService;

class _MockAbortService() extends Mock implements SessionAbortService;

void main() {
  late _MockActionService actionService;
  late _MockAbortService abortService;
  late FakeFeedbackPromptService feedback;
  late SessionActionsCubit cubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    actionService = _MockActionService();
    abortService = _MockAbortService();
    feedback = FakeFeedbackPromptService();
    cubit = SessionActionsCubit(
      window: _MockWindow(),
      actionService: actionService,
      abortService: abortService,
      feedbackPromptService: feedback,
    );
  });

  tearDown(() => cubit.close());

  group("sendToSession", () {
    final outcomes = <SendToSessionResult>[
      const SendToSessionSent(),
      const SendToSessionRefused(code: SendToSessionErrorCode.summaryStopped, message: null),
      SendToSessionFailed(error: ApiError.generic()),
      const SendToSessionUnsupported(),
      SendToSessionUnconfirmed(error: ApiError.generic()),
    ];
    for (final outcome in outcomes) {
      test("returns ${outcome.runtimeType.toString()}", () async {
        when(
          () => actionService.sendToSession(
            sourceSessionId: "source",
            sourcePluginId: "codex",
            targetSessionId: "target",
          ),
        ).thenAnswer((_) async => outcome);

        expect(
          await cubit.sendToSession(sourceSessionId: "source", sourcePluginId: "codex", targetSessionId: "target"),
          same(outcome),
        );
      });
    }
  });

  group("stopSession", () {
    void stubStop(Future<void> Function() answer) => when(
      () => abortService.abortSession(sessionId: "source", subAgents: SessionAbortSubAgentPolicy.stop),
    ).thenAnswer((_) => answer());

    test("stops the session and its sub-agents", () async {
      stubStop(() async {});

      expect(await cubit.stopSession(sessionId: "source"), isTrue);
      verify(() => abortService.abortSession(sessionId: "source", subAgents: SessionAbortSubAgentPolicy.stop))
          .called(1);
      expect(feedback.stoppedSessions, ["source"]);
      expect(feedback.refusedStops, isEmpty);
    });

    test("is true when only a sub-agent did not stop", () async {
      stubStop(
        () async =>
            throw SessionAbortDescendantFailureException(cause: StateError("child"), causeStackTrace: StackTrace.empty),
      );

      expect(await cubit.stopSession(sessionId: "source"), isTrue);
    });

    test("is false when the bridge did not stop it", () async {
      stubStop(() async => throw ApiError.generic());

      expect(await cubit.stopSession(sessionId: "source"), isFalse);
      expect(feedback.refusedStops, isEmpty);
    });

    test("gives the turn back its feedback point when the bridge refuses the stop", () async {
      stubStop(
        () async => throw SessionAbortNotAcceptedException(
          refusal: const SessionAbortNotPerformedRefusal(reason: SessionAbortRefusalReason.subAgentStopUnsupported),
          innerError: StateError("refused"),
        ),
      );

      expect(await cubit.stopSession(sessionId: "source"), isFalse);
      expect(feedback.refusedStops, ["source"]);
    });
  });
}
