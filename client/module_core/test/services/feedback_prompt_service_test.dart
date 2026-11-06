import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MemoryPersister() extends Fake implements PersisterRepository {
  final values = <String, String>{};

  @override
  Future<String?> readString({required StringPersistenceKey key}) async => values[key.storageKey];

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    values[key.storageKey] = value;
  }
}

class _FakeConfigSource() implements FeedbackPromptConfigSource {
  FeedbackPromptConfigValues values = (interactionThreshold: 3, cooldownDays: 14);

  @override
  Future<FeedbackPromptConfigValues> fetchValues() async => values;
}

Message _errorMessage({required String sessionId}) => Message.error(
  id: "msg-error",
  sessionID: sessionId,
  agent: null,
  modelID: null,
  providerID: null,
  errorName: "ProviderError",
  errorMessage: "request failed",
  time: null,
);

Session _childSession({required String id}) => Session(
  id: id,
  projectID: "project-1",
  directory: "/fixture/project",
  parentID: "ses-a",
  title: null,
  time: null,
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
  approvalOverride: null,
);

void main() {
  late StreamController<SseEvent> events;
  late MockConnectionService connectionService;
  late FakeLifecycleSource lifecycleSource;
  late _FakeConfigSource configSource;
  late FeedbackPromptStorage storage;
  late FeedbackPromptService service;
  late List<void> prompts;

  setUp(() {
    events = StreamController<SseEvent>.broadcast();
    connectionService = MockConnectionService();
    when(() => connectionService.events).thenAnswer((_) => events.stream);
    lifecycleSource = FakeLifecycleSource();
    configSource = _FakeConfigSource();
    storage = FeedbackPromptStorage(persister: _MemoryPersister());
    service = FeedbackPromptService(
      connectionService: connectionService,
      lifecycleSource: lifecycleSource,
      repository: FeedbackPromptRepository(
        configApi: FeedbackPromptConfigApi(source: configSource),
        storage: storage,
      ),
    );
    // Tests that exercise the grace set their own.
    service.finishedTurnGrace = Duration.zero;
    prompts = [];
    service.prompts.listen(prompts.add);
  });

  tearDown(() async {
    await service.dispose();
    await events.close();
    await lifecycleSource.close();
  });

  Future<FeedbackPromptState?> stored() => storage.read();

  Matcher counting({required Map<String, int> points, required Object? lastShownAt}) => isA<FeedbackPromptCounting>()
      .having((state) => state.pointsBySession, "pointsBySession", points)
      .having((state) => state.lastShownAt, "lastShownAt", lastShownAt);

  /// Delivers [data] and lets the update it causes land: the in-memory store
  /// settles within the microtasks that drain before the next timer, and the
  /// second wait outlasts the zero grace timer the event may start.
  Future<void> emitEvent(SesoriSseEvent data) async {
    events.add(SseEvent(data: data));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitStatus({required String sessionId, required SessionStatus status}) =>
      emitEvent(SesoriSseEvent.sessionStatus(sessionID: sessionId, status: status));

  Future<void> startTurn({required String sessionId}) =>
      emitStatus(sessionId: sessionId, status: const SessionStatus.busy(since: null));

  Future<void> endTurn({required String sessionId}) =>
      emitStatus(sessionId: sessionId, status: const SessionStatus.idle());

  /// Runs [times] turns in [sessionId] that each finish cleanly.
  Future<void> finishTurns({required String sessionId, int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await startTurn(sessionId: sessionId);
      await endTurn(sessionId: sessionId);
    }
  }

  test("records nothing before start, as on desktop", () async {
    await finishTurns(sessionId: "ses-a", times: 5);
    await service.recordFailure(sessionId: "ses-a");
    await service.recordCrash();
    await service.recordYes();

    expect(await stored(), isNull);
    expect(prompts, isEmpty);
  });

  test("falls back to 5 finished turns when the remote value is missing", () async {
    configSource.values = (interactionThreshold: null, cooldownDays: null);
    service.start();

    await finishTurns(sessionId: "ses-a", times: 4);
    expect(prompts, isEmpty);

    await finishTurns(sessionId: "ses-a");
    expect(prompts, hasLength(1));
  });

  group("once started", () {
    setUp(() => service.start());

    group("a point", () {
      test("is earned by a turn that finishes cleanly in the foreground", () async {
        await startTurn(sessionId: "ses-a");
        expect(await stored(), isNull, reason: "a turn still running earns nothing");

        await endTurn(sessionId: "ses-a");

        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
        expect(prompts, isEmpty);
      });

      test("is earned in whichever session the turn ran", () async {
        await finishTurns(sessionId: "ses-a");
        await finishTurns(sessionId: "ses-b");

        expect(await stored(), counting(points: {"ses-a": 1, "ses-b": 1}, lastShownAt: isNull));
      });

      test("is earned once per turn, however many busy and retry statuses it reports", () async {
        await startTurn(sessionId: "ses-a");
        await emitStatus(
          sessionId: "ses-a",
          status: const SessionStatus.retry(attempt: 1, message: "rate limited", next: 0, since: null),
        );
        await startTurn(sessionId: "ses-a");
        await endTurn(sessionId: "ses-a");
        await endTurn(sessionId: "ses-a");

        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      });

      test("is not earned by an idle status without a turn seen running", () async {
        await endTurn(sessionId: "ses-a");

        expect(await stored(), isNull);
      });

      test("is not earned by a turn that finishes while the app is in the background", () async {
        await startTurn(sessionId: "ses-a");
        lifecycleSource.emitState(LifecycleState.paused);
        await endTurn(sessionId: "ses-a");

        expect(await stored(), isNull);

        lifecycleSource.emitState(LifecycleState.resumed);
        await finishTurns(sessionId: "ses-a");
        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      });

      test("is not earned by a sub-agent session, whose parent's turn is still running", () async {
        await emitEvent(SesoriSseEvent.sessionCreated(info: _childSession(id: "ses-child")));

        await finishTurns(sessionId: "ses-child");

        expect(await stored(), isNull);
      });

      test("serializes turns that finish together", () async {
        await startTurn(sessionId: "ses-a");
        await startTurn(sessionId: "ses-b");
        events
          ..add(
            SseEvent(
              data: const SesoriSseEvent.sessionStatus(sessionID: "ses-a", status: SessionStatus.idle()),
            ),
          )
          ..add(
            SseEvent(
              data: const SesoriSseEvent.sessionStatus(sessionID: "ses-b", status: SessionStatus.idle()),
            ),
          );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(await stored(), counting(points: {"ses-a": 1, "ses-b": 1}, lastShownAt: isNull));
      });
    });

    group("the prompt", () {
      test("fires right after the turn that reaches the threshold across sessions, clearing every point", () async {
        final before = DateTime.now().toUtc();
        await finishTurns(sessionId: "ses-a", times: 2);
        expect(prompts, isEmpty);

        await startTurn(sessionId: "ses-b");
        expect(prompts, isEmpty, reason: "not while the threshold turn is still running");
        await endTurn(sessionId: "ses-b");

        expect(prompts, hasLength(1));
        expect(
          await stored(),
          counting(
            points: const {},
            lastShownAt: isA<DateTime>().having((shownAt) => shownAt.isBefore(before), "isBefore(start)", isFalse),
          ),
        );
      });

      test("keeps counting during the cooldown and fires after the first turn once it has passed", () async {
        await storage.write(
          state: FeedbackPromptCounting(
            pointsBySession: const {"ses-a": 2},
            lastShownAt: DateTime.now().toUtc().subtract(const Duration(days: 13)),
          ),
        );

        await finishTurns(sessionId: "ses-b", times: 2);

        expect(prompts, isEmpty);
        expect(await stored(), counting(points: {"ses-a": 2, "ses-b": 2}, lastShownAt: isNotNull));

        await storage.write(
          state: FeedbackPromptCounting(
            pointsBySession: const {"ses-a": 2, "ses-b": 2},
            lastShownAt: DateTime.now().toUtc().subtract(const Duration(days: 14, minutes: 1)),
          ),
        );
        await finishTurns(sessionId: "ses-c");

        expect(prompts, hasLength(1));
        expect(await stored(), counting(points: const {}, lastShownAt: isNotNull));
      });
    });

    group("a failure in one session", () {
      for (final (name, failInSessionB) in <(String, Future<void> Function())>[
        (
          "an AI error message",
          () => emitEvent(SesoriSseEvent.messageUpdated(info: _errorMessage(sessionId: "ses-b"))),
        ),
        ("a session error", () => emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-b"))),
        ("a failed send or reply", () => service.recordFailure(sessionId: "ses-b")),
      ]) {
        test("drops only that session's points when it is $name", () async {
          final shownAt = DateTime.utc(2026, 9, 1);
          await storage.write(
            state: FeedbackPromptCounting(pointsBySession: const {"ses-a": 2, "ses-b": 2}, lastShownAt: shownAt),
          );

          await failInSessionB();

          expect(await stored(), counting(points: {"ses-a": 2}, lastShownAt: shownAt));
        });
      }

      test("leaves the other sessions' points counting toward the prompt", () async {
        await storage.write(
          state: const FeedbackPromptCounting(pointsBySession: {"ses-a": 2, "ses-b": 1}, lastShownAt: null),
        );

        await service.recordFailure(sessionId: "ses-b");
        await finishTurns(sessionId: "ses-c");

        expect(prompts, hasLength(1), reason: "ses-a's 2 points and ses-c's 1 reach the threshold of 3");
      });

      test("spoils the turn it happens in, which earns no point when it ends", () async {
        await startTurn(sessionId: "ses-a");
        await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-a"));
        await endTurn(sessionId: "ses-a");

        expect(await stored(), isNull);

        await finishTurns(sessionId: "ses-a");
        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      });

      test("is ignored when the session error names no session", () async {
        await finishTurns(sessionId: "ses-a");

        await emitEvent(const SesoriSseEvent.sessionError(sessionID: null));

        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      });

      for (final (name, event) in [
        (
          "an assistant message",
          const SesoriSseEvent.messageUpdated(
            info: Message.assistant(
              id: "msg-1",
              sessionID: "ses-a",
              agent: null,
              modelID: null,
              providerID: null,
              time: null,
            ),
          ),
        ),
        (
          "a transient retry",
          const SesoriSseEvent.sessionStatus(
            sessionID: "ses-a",
            status: SessionStatus.retry(attempt: 1, message: "rate limited", next: 0, since: null),
          ),
        ),
      ]) {
        test("is not $name", () async {
          await finishTurns(sessionId: "ses-a");

          await emitEvent(event);

          expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
        });
      }
    });

    test("a crash on the previous launch drops every session's points and keeps the last showing", () async {
      final shownAt = DateTime.utc(2026, 9, 1);
      await storage.write(
        state: FeedbackPromptCounting(pointsBySession: const {"ses-a": 2, "ses-b": 1}, lastShownAt: shownAt),
      );

      await service.recordCrash();

      expect(await stored(), counting(points: const {}, lastShownAt: shownAt));
    });

    test("an error reported right after the idle spoils the turn before it earns", () async {
      service.finishedTurnGrace = const Duration(milliseconds: 50);
      await startTurn(sessionId: "ses-a");
      await endTurn(sessionId: "ses-a");
      await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-a"));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(await stored(), isNull);

      await startTurn(sessionId: "ses-a");
      await endTurn(sessionId: "ses-a");
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        await stored(),
        counting(points: {"ses-a": 1}, lastShownAt: isNull),
        reason: "a clean turn still earns once the grace passes",
      );
    });

    group("after a user stop", () {
      test("the stopped session's AI errors keep its points until its next turn starts", () async {
        await finishTurns(sessionId: "ses-a");
        await startTurn(sessionId: "ses-a");
        service.recordUserStop(sessionId: "ses-a");

        await emitEvent(SesoriSseEvent.messageUpdated(info: _errorMessage(sessionId: "ses-a")));
        await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-a"));
        await endTurn(sessionId: "ses-a");
        expect(
          await stored(),
          counting(points: {"ses-a": 1}, lastShownAt: isNull),
          reason: "the stopped turn neither fails nor earns a point",
        );

        await startTurn(sessionId: "ses-a");
        await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-a"));
        expect(await stored(), counting(points: const {}, lastShownAt: isNull));
      });

      test("the stopped turn earns no point, unless the stop was refused", () async {
        await startTurn(sessionId: "ses-a");
        service.recordUserStop(sessionId: "ses-a");
        await endTurn(sessionId: "ses-a");
        expect(await stored(), isNull);

        await startTurn(sessionId: "ses-a");
        service.recordUserStop(sessionId: "ses-a");
        service.recordUserStopRefused(sessionId: "ses-a");
        await endTurn(sessionId: "ses-a");
        expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      });

      test("other sessions' AI errors still drop their points", () async {
        await finishTurns(sessionId: "ses-b");
        service.recordUserStop(sessionId: "ses-a");

        await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-b"));

        expect(await stored(), counting(points: const {}, lastShownAt: isNull));
      });

      test("a failed send in the stopped session still drops its points", () async {
        await finishTurns(sessionId: "ses-a");
        service.recordUserStop(sessionId: "ses-a");

        await service.recordFailure(sessionId: "ses-a");

        expect(await stored(), counting(points: const {}, lastShownAt: isNull));
      });
    });

    test("Yes retires the automatic prompt for good", () async {
      await finishTurns(sessionId: "ses-a");

      await service.recordYes();
      await finishTurns(sessionId: "ses-a", times: 10);
      await service.recordFailure(sessionId: "ses-a");
      await service.recordCrash();

      expect(await stored(), isA<FeedbackPromptRetired>());
      expect(prompts, isEmpty);
    });

    test("stops listening once disposed", () async {
      await finishTurns(sessionId: "ses-a");
      await service.dispose();

      await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-a"));

      expect(await stored(), counting(points: {"ses-a": 1}, lastShownAt: isNull));
      expect(events.hasListener, isFalse);
    });
  });
}
