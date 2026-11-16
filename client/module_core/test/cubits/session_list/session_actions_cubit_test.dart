import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_action_service.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockWindow() extends Mock implements SessionWindowService;

class _MockActionService() extends Mock implements SessionActionService;

class _MockAbortService() extends Mock implements SessionAbortService;

class _MemoryPersister() extends Fake implements PersisterRepository {
  final Map<BoolPersistenceKey, bool> values = {};

  @override
  Future<bool> readBoolOrDefault({required BoolPersistenceKey key, required bool defaultValue}) async =>
      values[key] ?? defaultValue;

  @override
  Future<void> writeBool({required BoolPersistenceKey key, required bool value}) async => values[key] = value;
}

void main() {
  late _MockActionService actionService;
  late _MockAbortService abortService;
  late FakeFeedbackPromptService feedback;
  late _MemoryPersister persister;
  late SessionActionsCubit cubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    actionService = _MockActionService();
    when(() => actionService.refreshForkCapabilities()).thenAnswer((_) async {});
    abortService = _MockAbortService();
    feedback = FakeFeedbackPromptService();
    persister = _MemoryPersister();
    cubit = SessionActionsCubit(
      window: _MockWindow(),
      actionService: actionService,
      abortService: abortService,
      feedbackPromptService: feedback,
      archiveAfterSendStorage: ArchiveAfterSendPreferenceStorage(persister: persister),
    );
  });

  tearDown(() => cubit.close());

  group("forkSession", () {
    for (final recreateFromBase in [false, true]) {
      test("forks after the latest finished turn, recreateFromBase $recreateFromBase", () async {
        final session = testSession(id: "ses-1", pluginId: "claude");
        when(
          () => actionService.forkSession(
            sessionId: "ses-1",
            pluginId: "claude",
            point: const ForkPoint.latest(),
            recreateFromBase: recreateFromBase,
          ),
        ).thenAnswer((_) async => SessionForked(session: session));

        final result = await cubit.forkSession(session: session, recreateFromBase: recreateFromBase);

        expect(result, isA<SessionForked>());
      });
    }
  });

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

  group("archiveAfterSend", () {
    test("is on until the user turns it off", () async {
      expect(await cubit.archiveAfterSend(), isTrue);
    });

    test("remembers the last choice on this device", () async {
      await cubit.setArchiveAfterSend(value: false);
      expect(await cubit.archiveAfterSend(), isFalse);
      expect(persister.values, {BoolPreferenceKey.archiveAfterSend: false});

      await cubit.setArchiveAfterSend(value: true);
      expect(await cubit.archiveAfterSend(), isTrue);
    });
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
