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

const _assistantMessage = Message.assistant(
  id: "msg-1",
  sessionID: "ses-1",
  agent: null,
  modelID: null,
  providerID: null,
  time: null,
);

const _errorMessage = Message.error(
  id: "msg-2",
  sessionID: "ses-1",
  agent: null,
  modelID: null,
  providerID: null,
  errorName: "ProviderError",
  errorMessage: "request failed",
  time: null,
);

void main() {
  late StreamController<SseEvent> events;
  late MockConnectionService connectionService;
  late _FakeConfigSource configSource;
  late FeedbackPromptStorage storage;
  late FeedbackPromptService service;
  late List<void> prompts;

  setUp(() {
    events = StreamController<SseEvent>.broadcast();
    connectionService = MockConnectionService();
    when(() => connectionService.events).thenAnswer((_) => events.stream);
    configSource = _FakeConfigSource();
    storage = FeedbackPromptStorage(persister: _MemoryPersister());
    service = FeedbackPromptService(
      connectionService: connectionService,
      repository: FeedbackPromptRepository(
        configApi: FeedbackPromptConfigApi(source: configSource),
        storage: storage,
      ),
    );
    prompts = [];
    service.prompts.listen(prompts.add);
  });

  tearDown(() async {
    await service.dispose();
    await events.close();
  });

  Future<FeedbackPromptState?> stored() => storage.read();

  Matcher counting({required int positiveCount, required Object? lastShownAt}) => isA<FeedbackPromptCounting>()
      .having((state) => state.positiveCount, "positiveCount", positiveCount)
      .having((state) => state.lastShownAt, "lastShownAt", lastShownAt);

  /// Records [times] interactions, then lets any prompt they emit arrive.
  Future<void> recordPositive({required int times}) async {
    for (var i = 0; i < times; i++) {
      await service.recordPositiveInteraction();
    }
    await Future<void>.delayed(Duration.zero);
  }

  /// Delivers [data] and lets the update it causes land: the in-memory store
  /// settles within the microtasks that drain before the next timer.
  Future<void> emitEvent(SesoriSseEvent data) async {
    events.add(SseEvent(data: data));
    await Future<void>.delayed(Duration.zero);
  }

  test("records nothing before start, as on desktop", () async {
    await recordPositive(times: 5);
    await service.recordYes();

    expect(await stored(), isNull);
    expect(prompts, isEmpty);
  });

  test("falls back to 10 interactions when the remote value is missing", () async {
    configSource.values = (interactionThreshold: null, cooldownDays: null);
    service.start();

    await recordPositive(times: 9);
    expect(prompts, isEmpty);

    await recordPositive(times: 1);
    expect(prompts, hasLength(1));
  });

  group("once started", () {
    setUp(() => service.start());

    test("adds one point per good interaction", () async {
      await recordPositive(times: 2);

      expect(await stored(), counting(positiveCount: 2, lastShownAt: isNull));
      expect(prompts, isEmpty);
    });

    test("serializes concurrent interactions", () async {
      await Future.wait([for (var i = 0; i < 2; i++) service.recordPositiveInteraction()]);

      expect(await stored(), counting(positiveCount: 2, lastShownAt: isNull));
    });

    test("shows at the threshold, resetting the count and recording the showing in one write", () async {
      final before = DateTime.now().toUtc();
      await recordPositive(times: 3);

      expect(prompts, hasLength(1));
      expect(
        await stored(),
        counting(
          positiveCount: 0,
          lastShownAt: isA<DateTime>().having((shownAt) => shownAt.isBefore(before), "isBefore(start)", isFalse),
        ),
      );
    });

    test("keeps counting during the cooldown and shows once it has passed", () async {
      await storage.write(
        state: FeedbackPromptCounting(
          positiveCount: 2,
          lastShownAt: DateTime.now().toUtc().subtract(const Duration(days: 13)),
        ),
      );

      await recordPositive(times: 2);

      expect(prompts, isEmpty);
      expect(await stored(), counting(positiveCount: 4, lastShownAt: isNotNull));

      await storage.write(
        state: FeedbackPromptCounting(
          positiveCount: 4,
          lastShownAt: DateTime.now().toUtc().subtract(const Duration(days: 14, minutes: 1)),
        ),
      );
      await recordPositive(times: 1);

      expect(prompts, hasLength(1));
      expect(await stored(), counting(positiveCount: 0, lastShownAt: isNotNull));
    });

    test("a failure resets the count and keeps the last showing", () async {
      final shownAt = DateTime.utc(2026, 9, 1);
      await storage.write(state: FeedbackPromptCounting(positiveCount: 2, lastShownAt: shownAt));

      await service.recordFailure();

      expect(await stored(), counting(positiveCount: 0, lastShownAt: shownAt));
      await recordPositive(times: 2);
      expect(prompts, isEmpty);
    });

    for (final (name, event) in [
      ("an AI error message", const SesoriSseEvent.messageUpdated(info: _errorMessage)),
      (
        "a transient retry",
        const SesoriSseEvent.sessionStatus(
          sessionID: "ses-1",
          status: SessionStatus.retry(attempt: 1, message: "rate limited", next: 0),
        ),
      ),
      ("a session error", const SesoriSseEvent.sessionError(sessionID: "ses-1")),
    ]) {
      test("$name on any session resets the count", () async {
        await recordPositive(times: 2);

        await emitEvent(event);

        expect(await stored(), counting(positiveCount: 0, lastShownAt: isNull));
      });
    }

    for (final (name, event) in [
      ("an assistant message", const SesoriSseEvent.messageUpdated(info: _assistantMessage)),
      ("a busy status", const SesoriSseEvent.sessionStatus(sessionID: "ses-1", status: SessionStatus.busy())),
    ]) {
      test("$name keeps the count", () async {
        await recordPositive(times: 2);

        await emitEvent(event);

        expect(await stored(), counting(positiveCount: 2, lastShownAt: isNull));
      });
    }

    test("Yes retires the automatic sheet for good", () async {
      await recordPositive(times: 2);

      await service.recordYes();
      await recordPositive(times: 10);
      await service.recordFailure();

      expect(await stored(), isA<FeedbackPromptRetired>());
      expect(prompts, isEmpty);
    });

    test("stops listening for AI errors once disposed", () async {
      await recordPositive(times: 2);
      await service.dispose();

      await emitEvent(const SesoriSseEvent.sessionError(sessionID: "ses-1"));

      expect(await stored(), counting(positiveCount: 2, lastShownAt: isNull));
      expect(events.hasListener, isFalse);
    });
  });
}
