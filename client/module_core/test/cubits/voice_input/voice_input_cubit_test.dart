import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

void main() {
  const emptyPreview = VoiceTranscriptionPreview(confirmedText: "", provisionalText: "");
  late MockVoiceTranscriptionService service;
  late MockVoiceTranscriptionSession session;
  late StreamController<void> maxDurationController;
  late StreamController<VoiceRealtimeTerminalCause> realtimeTerminalController;

  setUp(() {
    service = MockVoiceTranscriptionService();
    session = MockVoiceTranscriptionSession();
    maxDurationController = StreamController<void>.broadcast();
    realtimeTerminalController = StreamController<VoiceRealtimeTerminalCause>.broadcast();
    when(() => service.amplitudeStream(session: session)).thenAnswer((_) => const Stream<double>.empty());
    when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationController.stream);
    when(
      () => service.realtimeTerminalStream(session: session),
    ).thenAnswer((_) => realtimeTerminalController.stream);
    when(() => service.currentPreview(session: session)).thenReturn(emptyPreview);
    when(() => service.previewStream(session: session)).thenAnswer((_) => const Stream.empty());
    when(() => service.prewarm(session: session)).thenAnswer((_) async {});
    when(
      () => service.start(session: session),
    ).thenAnswer((_) async {});
    when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) async => "hello");
    when(() => service.retry(session: session)).thenAnswer((_) async => "retried");
    when(() => service.cancel(session: session)).thenAnswer((_) async {});
    when(() => service.discard(session: session)).thenAnswer((_) async {});
    when(() => service.invalidate(session: session)).thenReturn(null);
    when(() => service.close(session: session)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await maxDurationController.close();
    await realtimeTerminalController.close();
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
      VoiceInputState.recording(preview: emptyPreview),
      VoiceInputState.transcribing(limitReached: false, preview: emptyPreview),
      VoiceInputState.completed(transcript: "hello"),
      VoiceInputState.idle(),
    ],
    verify: (_) {
      verify(() => service.start(session: session)).called(1);
      verify(() => service.stopAndTranscribe(session: session)).called(1);
    },
  );

  test("a server limit reached during startup auto-stops after recording becomes ready", () async {
    final startCompleter = Completer<void>();
    when(
      () => service.start(session: session),
    ).thenAnswer((_) => startCompleter.future);
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);

    final starting = cubit.startRecording();
    await Future<void>.delayed(Duration.zero);
    maxDurationController.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<VoiceInputStarting>());

    startCompleter.complete();
    await starting;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const VoiceInputState.completed(transcript: "hello"));
    verify(() => service.stopAndTranscribe(session: session)).called(1);
  });

  test("realtime terminal during startup remains observable before its queued stop", () async {
    final startCompleter = Completer<void>();
    when(
      () => service.start(session: session),
    ).thenAnswer((_) => startCompleter.future);
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);

    final starting = cubit.startRecording();
    await Future<void>.delayed(Duration.zero);
    realtimeTerminalController.add(VoiceRealtimeTerminalCause.limitReached);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<VoiceInputStarting>());

    startCompleter.complete();
    await starting;
    expect(cubit.state, const VoiceInputState.recording(preview: emptyPreview));

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const VoiceInputState.completed(transcript: "hello"));
    verify(() => service.stopAndTranscribe(session: session)).called(1);
  });

  blocTest<VoiceInputCubit, VoiceInputState>(
    "maps a permission failure into start-specific state",
    setUp: () {
      when(
        () => service.start(session: session),
      ).thenThrow(
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
      when(() => service.stopAndTranscribe(session: session)).thenThrow(VoiceTranscriptionError.networkError());
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(preview: emptyPreview),
      const VoiceInputState.transcribing(limitReached: false, preview: emptyPreview),
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
        VoiceTranscriptionError.retryableServerError(statusCode: 503),
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
      const VoiceInputState.recording(preview: emptyPreview),
      const VoiceInputState.transcribing(limitReached: false, preview: emptyPreview),
      isA<VoiceInputRetryPending>(),
      isA<VoiceInputRetrying>(),
      const VoiceInputState.completed(transcript: "retried"),
    ],
    verify: (_) => verify(() => service.retry(session: session)).called(1),
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "keeps terminal transcription failures out of retry-pending",
    setUp: () {
      when(() => service.stopAndTranscribe(session: session)).thenThrow(
        VoiceTranscriptionError.serverError(statusCode: 400),
      );
    },
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(preview: emptyPreview),
      const VoiceInputState.transcribing(limitReached: false, preview: emptyPreview),
      isA<VoiceInputTranscriptionFailed>(),
    ],
  );

  test("realtime preview stays authoritative and partial failure never enters async Retry", () async {
    final previews = StreamController<VoiceTranscriptionPreview>.broadcast();
    addTearDown(previews.close);
    when(() => service.previewStream(session: session)).thenAnswer((_) => previews.stream);
    when(() => service.stopAndTranscribe(session: session)).thenThrow(
      VoiceRealtimePartialTranscriptionError(
        confirmedText: "confirmed words",
        failure: VoiceTranscriptionError.realtimeInterrupted(
          innerError: Exception("closed"),
          innerStackTrace: null,
        ),
      ),
    );
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);

    await cubit.startRecording();
    const preview = VoiceTranscriptionPreview(confirmedText: "confirmed ", provisionalText: "draft");
    previews.add(preview);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const VoiceInputState.recording(preview: preview));

    await cubit.stopAndTranscribe(limitReached: false);
    expect(
      cubit.state,
      isA<VoiceInputRealtimePartialFailed>()
          .having((state) => state.confirmedText, "confirmedText", "confirmed words")
          .having((state) => state.error, "error", isA<RealtimeInterruptedVoiceError>()),
    );
    expect(cubit.state, isNot(isA<VoiceInputRetryPending>()));
  });

  test("realtime terminal failure auto-stops while the recording gesture is still held", () async {
    when(() => service.stopAndTranscribe(session: session)).thenThrow(
      VoiceRealtimePartialTranscriptionError(
        confirmedText: "confirmed words",
        failure: VoiceTranscriptionError.realtimeInterrupted(
          innerError: Exception("closed"),
          innerStackTrace: null,
        ),
      ),
    );
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);
    await cubit.startRecording();

    realtimeTerminalController.add(VoiceRealtimeTerminalCause.failed);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      cubit.state,
      isA<VoiceInputRealtimePartialFailed>()
          .having((state) => state.confirmedText, "confirmedText", "confirmed words")
          .having((state) => state.error, "error", isA<RealtimeInterruptedVoiceError>()),
    );
    verify(() => service.stopAndTranscribe(session: session)).called(1);
  });

  test("cancelling a manual retry returns to retry-pending", () async {
    final retryCompleter = Completer<String>();
    when(() => service.stopAndTranscribe(session: session)).thenThrow(
      VoiceTranscriptionError.networkError(),
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
      VoiceTranscriptionError.networkError(),
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
    "composer identity change discards retained recording through one Cubit intent",
    seed: () => VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError()),
    build: () => VoiceInputCubit(service: service, session: session),
    act: (cubit) => cubit.composerIdentityChanged(),
    expect: () => const [VoiceInputState.discarding(), VoiceInputState.idle()],
    verify: (_) => verify(() => service.discard(session: session)).called(1),
  );

  blocTest<VoiceInputCubit, VoiceInputState>(
    "discards a retained recording and returns to idle",
    seed: () => VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError()),
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

    expect(cubit.state, const VoiceInputState.completed(transcript: "hello"));
    verify(() => service.stopAndTranscribe(session: session)).called(1);
  });

  test("a cancelled stale finish cannot settle a newer transcribing interaction", () async {
    final firstFinish = Completer<String>();
    final secondFinish = Completer<String>();
    var stops = 0;
    when(
      () => service.stopAndTranscribe(session: session),
    ).thenAnswer((_) => stops++ == 0 ? firstFinish.future : secondFinish.future);
    final cubit = VoiceInputCubit(service: service, session: session);
    addTearDown(cubit.close);

    await cubit.startRecording();
    final staleStop = cubit.stopAndTranscribe(limitReached: false);
    await Future<void>.delayed(Duration.zero);
    await cubit.cancel();
    await cubit.startRecording();
    final currentStop = cubit.stopAndTranscribe(limitReached: false);
    await Future<void>.delayed(Duration.zero);

    firstFinish.completeError(VoiceTranscriptionError.cancelled());
    await staleStop;
    expect(cubit.state, isA<VoiceInputTranscribing>());

    secondFinish.complete("new transcript");
    await currentStop;
    expect(cubit.state, const VoiceInputState.completed(transcript: "new transcript"));
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
      VoiceInputState.recording(preview: emptyPreview),
      VoiceInputState.cancelling(),
      VoiceInputState.idle(),
    ],
    verify: (_) => verify(() => service.cancel(session: session)).called(1),
  );

  test("close synchronously invalidates before asynchronous cleanup", () async {
    final cubit = VoiceInputCubit(service: service, session: session);

    await cubit.close();

    verifyInOrder([
      () => service.invalidate(session: session),
      () => service.close(session: session),
    ]);
  });
}
