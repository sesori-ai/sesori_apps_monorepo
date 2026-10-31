import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart" show afterRecordingResult;
import "package:test/test.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

void main() {
  late MockVoiceTranscriptionService service;
  late MockVoiceTranscriptionSession session;
  late StreamController<void> maxDurationController;
  late StreamController<VoiceLiveEvent> liveEvents;

  setUp(() {
    service = MockVoiceTranscriptionService();
    session = MockVoiceTranscriptionSession();
    maxDurationController = StreamController<void>.broadcast();
    liveEvents = StreamController<VoiceLiveEvent>.broadcast(sync: true);
    when(() => service.amplitudeStream(session: session)).thenAnswer((_) => const Stream<double>.empty());
    when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationController.stream);
    when(() => service.liveEventStream(session: session)).thenAnswer((_) => liveEvents.stream);
    when(() => service.isLive(session: session)).thenReturn(false);
    when(() => service.prewarm(session: session)).thenAnswer((_) async {});
    when(() => service.start(session: session)).thenAnswer((_) async {});
    when(() => service.stopAndTranscribe(session: session))
        .thenAnswer((_) async => afterRecordingResult(transcript: "hello"));
    when(() => service.retry(session: session)).thenAnswer((_) async => "retried");
    when(() => service.cancel(session: session)).thenAnswer((_) async {});
    when(() => service.discard(session: session)).thenAnswer((_) async {});
    when(() => service.invalidate(session: session)).thenReturn(null);
    when(() => service.close(session: session)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await maxDurationController.close();
    await liveEvents.close();
  });

  test("uses the composer-owned session injected at composition", () async {
    final cubit = VoiceInputCubit(service: service, session: session);

    expect(cubit.amplitudeStream, isA<Stream<double>>());
    await cubit.close();
  });

  blocTest<VoiceInputCubit, VoiceInputState>(
    "starts, transcribes, acknowledges, and keeps orchestration behind the service",
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
      cubit.acknowledgeOutcome();
    },
    expect: () => const [
      VoiceInputState.starting(),
      VoiceInputState.recording(),
      VoiceInputState.transcribing(limitReached: false),
      VoiceInputState.completed(
        transcript: "hello",
        outcome: VoiceDictationOutcome.finished,
        mode: VoiceDictationMode.afterRecording,
      ),
      VoiceInputState.idle(),
    ],
    verify: (_) {
      verify(() => service.start(session: session)).called(1);
      verify(() => service.stopAndTranscribe(session: session)).called(1);
    },
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "maps a permission failure into start-specific state",
    setUp: () {
      when(() => service.start(session: session)).thenThrow(
        VoiceTranscriptionError.microphonePermissionDenied(
          innerError: VoiceCaptureError.permissionDenied(innerError: null),
        ),
      );
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) => cubit.startRecording(),
    expect: () => [
      const VoiceInputState.starting(),
      isA<VoiceInputStartFailed>().having(
        (state) => state.error,
        "error",
        isA<MicrophonePermissionDeniedError>(),
      ),
    ],
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "maps a local transport failure into persistent retry-pending state",
    setUp: () {
      when(() => service.stopAndTranscribe(session: session))
          .thenThrow(VoiceTranscriptionError.networkError(innerError: null));
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
      isA<VoiceInputRetryPending>().having(
        (state) => state.error,
        "error",
        isA<NetworkVoiceError>(),
      ),
    ],
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "retries a retained recording and completes normally",
    setUp: () {
      when(() => service.stopAndTranscribe(session: session)).thenThrow(
        VoiceTranscriptionError.retryableServerError(statusCode: 503, innerError: null),
      );
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
      await cubit.retry();
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
      isA<VoiceInputRetryPending>(),
      isA<VoiceInputRetrying>(),
      const VoiceInputState.completed(
        transcript: "retried",
        outcome: VoiceDictationOutcome.finished,
        mode: VoiceDictationMode.afterRecording,
      ),
    ],
    verify: (_) => verify(() => service.retry(session: session)).called(1),
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "keeps terminal transcription failures out of retry-pending",
    setUp: () {
      when(() => service.stopAndTranscribe(session: session)).thenThrow(
        VoiceTranscriptionError.serverError(statusCode: 400, innerError: null),
      );
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
      isA<VoiceInputTranscriptionFailed>(),
    ],
  );

  test("cancelling a manual retry returns to retry-pending", () async {
    final retryCompleter = Completer<String>();
    when(() => service.stopAndTranscribe(session: session)).thenThrow(
      VoiceTranscriptionError.networkError(innerError: null),
    );
    when(() => service.retry(session: session)).thenAnswer((_) => retryCompleter.future);
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);
    await cubit.startRecording();
    await cubit.stopAndTranscribe(limitReached: false);

    final retry = cubit.retry();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<VoiceInputRetrying>());
    await cubit.cancel();
    expect(cubit.state, isA<VoiceInputRetryPending>());

    retryCompleter.completeError(VoiceTranscriptionError.cancelled());
    await retry;
    expect(cubit.state, isA<VoiceInputRetryPending>());
  });

  test("discard cancels an active retry before deleting its artifact", () async {
    final retryCompleter = Completer<String>();
    when(() => service.stopAndTranscribe(session: session)).thenThrow(
      VoiceTranscriptionError.networkError(innerError: null),
    );
    when(() => service.retry(session: session)).thenAnswer((_) => retryCompleter.future);
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);
    await cubit.startRecording();
    await cubit.stopAndTranscribe(limitReached: false);

    final retry = cubit.retry();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<VoiceInputRetrying>());
    await cubit.discard();

    expect(cubit.state, const VoiceInputState.idle());
    verifyInOrder([
      () => service.cancel(session: session),
      () => service.discard(session: session),
    ]);
    retryCompleter.completeError(VoiceTranscriptionError.cancelled());
    await retry;
    expect(cubit.state, const VoiceInputState.idle());
  });

  blocTest<VoiceInputCubit, VoiceInputState>(
    "discards a retained recording and returns to idle",
    seed: () => VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError(innerError: null)),
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) => cubit.discard(),
    expect: () => const [VoiceInputState.discarding(), VoiceInputState.idle()],
    verify: (_) => verify(() => service.discard(session: session)).called(1),
  );

  test("maximum duration auto-stops through the Cubit with its reason preserved", () async {
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);
    await cubit.startRecording();

    maxDurationController.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      cubit.state,
      const VoiceInputState.completed(
        transcript: "hello",
        outcome: VoiceDictationOutcome.limitReached,
        mode: VoiceDictationMode.afterRecording,
      ),
    );
    verify(() => service.stopAndTranscribe(session: session)).called(1);
  });

  blocTest<VoiceInputCubit, VoiceInputState>(
    "cancels active work and returns to idle",
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.cancel();
    },
    expect: () => const [
      VoiceInputState.starting(),
      VoiceInputState.recording(),
      VoiceInputState.cancelling(),
      VoiceInputState.idle(),
    ],
    verify: (_) => verify(() => service.cancel(session: session)).called(1),
  );

  group("live", () {
    const hello = LiveWords(confirmed: "hello ", provisional: "wor");

    setUp(() {
      when(() => service.isLive(session: session)).thenReturn(true);
    });

    VoiceInputState liveRecording({LiveWords words = LiveWords.none}) => VoiceInputState.liveRecording(words: words);

    VoiceDictationResult liveResult({required String transcript, required VoiceDictationOutcome outcome}) =>
        VoiceDictationResult(transcript: transcript, outcome: outcome, mode: VoiceDictationMode.live);

    blocTest<VoiceInputCubit, VoiceInputState>(
      "shows the words while held and through the finish, and completes as live",
      setUp: () {
        when(() => service.stopAndTranscribe(session: session)).thenAnswer(
          (_) async => liveResult(transcript: "hello world", outcome: VoiceDictationOutcome.finished),
        );
      },
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        liveEvents.add(const VoiceLiveWordsChanged(words: hello));
        await cubit.stopAndTranscribe(limitReached: false);
      },
      expect: () => [
        const VoiceInputState.starting(),
        liveRecording(),
        liveRecording(words: hello),
        const VoiceInputState.liveFinishing(words: hello),
        const VoiceInputState.completed(
          transcript: "hello world",
          outcome: VoiceDictationOutcome.finished,
          mode: VoiceDictationMode.live,
        ),
      ],
    );

    test("words that arrive during the finish keep updating it", () async {
      final finishing = Completer<VoiceDictationResult>();
      when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) => finishing.future);
      final cubit = VoiceInputCubit(service: service, session: session);
      addTearDown(cubit.close);
      await cubit.startRecording();
      final stop = cubit.stopAndTranscribe(limitReached: false);

      liveEvents.add(const VoiceLiveWordsChanged(words: hello));

      expect(cubit.state, const VoiceInputState.liveFinishing(words: hello));
      finishing.complete(liveResult(transcript: "hello", outcome: VoiceDictationOutcome.finished));
      await stop;
    });

    for (final error in [
      VoiceTranscriptionError.networkError(innerError: null),
      VoiceTranscriptionError.retryableServerError(statusCode: 1011, innerError: null),
    ]) {
      blocTest<VoiceInputCubit, VoiceInputState>(
        "a retryable-looking ${error.runtimeType} at the finish never offers a retry (D20)",
        setUp: () {
          when(() => service.stopAndTranscribe(session: session)).thenThrow(error);
        },
        build: () => VoiceInputCubit(service: service, session: session),
        act: (cubit) async {
          await cubit.startRecording();
          await cubit.stopAndTranscribe(limitReached: false);
        },
        expect: () => [
          const VoiceInputState.starting(),
          liveRecording(),
          const VoiceInputState.liveFinishing(words: LiveWords.none),
          VoiceInputState.transcriptionFailed(error: error),
        ],
        verify: (_) => verifyNever(() => service.retry(session: session)),
      );
    }

    blocTest<VoiceInputCubit, VoiceInputState>(
      "the fifteen minute limit finishes and reports the limit",
      setUp: () {
        when(() => service.stopAndTranscribe(session: session)).thenAnswer(
          (_) async => liveResult(transcript: "words", outcome: VoiceDictationOutcome.finished),
        );
      },
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        maxDurationController.add(null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const VoiceInputState.starting(),
        liveRecording(),
        const VoiceInputState.liveFinishing(words: LiveWords.none),
        const VoiceInputState.completed(
          transcript: "words",
          outcome: VoiceDictationOutcome.limitReached,
          mode: VoiceDictationMode.live,
        ),
      ],
    );

    blocTest<VoiceInputCubit, VoiceInputState>(
      "the limit never turns a cut-off dictation into a merely limited one",
      setUp: () {
        when(() => service.stopAndTranscribe(session: session)).thenAnswer(
          (_) async => liveResult(transcript: "words", outcome: VoiceDictationOutcome.interrupted),
        );
      },
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        await cubit.stopAndTranscribe(limitReached: true);
      },
      skip: 3,
      expect: () => const [
        VoiceInputState.completed(
          transcript: "words",
          outcome: VoiceDictationOutcome.interrupted,
          mode: VoiceDictationMode.live,
        ),
      ],
    );

    blocTest<VoiceInputCubit, VoiceInputState>(
      "a fallback while held turns into a recording",
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        liveEvents.add(const VoiceLiveFellBack());
      },
      expect: () => [const VoiceInputState.starting(), liveRecording(), const VoiceInputState.recording()],
    );

    test("a fallback that lands after the release turns into transcribing, and its words land in the box", () async {
      final finishing = Completer<VoiceDictationResult>();
      when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) => finishing.future);
      final cubit = VoiceInputCubit(service: service, session: session);
      addTearDown(cubit.close);
      await cubit.startRecording();
      final stop = cubit.stopAndTranscribe(limitReached: false);

      liveEvents.add(const VoiceLiveFellBack());
      expect(cubit.state, const VoiceInputState.transcribing(limitReached: false));

      finishing.complete(
        const VoiceDictationResult(
          transcript: "recorded",
          outcome: VoiceDictationOutcome.interrupted,
          mode: VoiceDictationMode.afterRecording,
        ),
      );
      await stop;
      expect(
        cubit.state,
        const VoiceInputState.completed(
          transcript: "recorded",
          outcome: VoiceDictationOutcome.interrupted,
          mode: VoiceDictationMode.afterRecording,
        ),
      );
    });

    blocTest<VoiceInputCubit, VoiceInputState>(
      "a session that ends while held completes with its outcome",
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        liveEvents.add(const VoiceLiveEnded(transcript: "cut", outcome: VoiceDictationOutcome.interrupted));
      },
      skip: 2,
      expect: () => const [
        VoiceInputState.completed(
          transcript: "cut",
          outcome: VoiceDictationOutcome.interrupted,
          mode: VoiceDictationMode.live,
        ),
      ],
    );

    blocTest<VoiceInputCubit, VoiceInputState>(
      "a session that fails while held reports the failure with no retry",
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        liveEvents.add(VoiceLiveFailed(error: VoiceTranscriptionError.networkError(innerError: null)));
      },
      skip: 2,
      expect: () => [isA<VoiceInputTranscriptionFailed>()],
    );

    blocTest<VoiceInputCubit, VoiceInputState>(
      "an event for a dictation already cancelled changes nothing",
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) async {
        await cubit.startRecording();
        await cubit.cancel();
        liveEvents
          ..add(const VoiceLiveWordsChanged(words: hello))
          ..add(const VoiceLiveFellBack())
          ..add(const VoiceLiveEnded(transcript: "late", outcome: VoiceDictationOutcome.finished))
          ..add(VoiceLiveFailed(error: VoiceTranscriptionError.emptyTranscript()));
      },
      expect: () => [
        const VoiceInputState.starting(),
        liveRecording(),
        const VoiceInputState.cancelling(),
        const VoiceInputState.idle(),
      ],
    );

    blocTest<VoiceInputCubit, VoiceInputState>(
      "a hold that the service ran as a recording shows as one",
      setUp: () {
        when(() => service.isLive(session: session)).thenReturn(false);
      },
      build: () => VoiceInputCubit(service: service, session: session),
      act: (cubit) => cubit.startRecording(),
      expect: () => const [VoiceInputState.starting(), VoiceInputState.recording()],
    );
  });

  test("close synchronously invalidates before asynchronous cleanup", () async {
    final cubit = VoiceInputCubit(service: service, session: session);

    await cubit.close();

    verifyInOrder([
      () => service.invalidate(session: session),
      () => service.close(session: session),
    ]);
  });
}
