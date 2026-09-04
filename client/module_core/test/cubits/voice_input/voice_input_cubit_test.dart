import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

void main() {
  late MockVoiceTranscriptionService service;
  late MockVoiceTranscriptionSession session;
  late StreamController<void> maxDurationController;

  setUp(() {
    service = MockVoiceTranscriptionService();
    session = MockVoiceTranscriptionSession();
    maxDurationController = StreamController<void>.broadcast();
    when(() => service.amplitudeStream(session: session)).thenAnswer((_) => const Stream<double>.empty());
    when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationController.stream);
    when(() => service.prewarm(session: session)).thenAnswer((_) async {});
    when(() => service.start(session: session)).thenAnswer((_) async {});
    when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) async => "hello");
    when(() => service.retry(session: session)).thenAnswer((_) async => "retried");
    when(() => service.cancel(session: session)).thenAnswer((_) async {});
    when(() => service.discard(session: session)).thenAnswer((_) async {});
    when(() => service.invalidate(session: session)).thenReturn(null);
    when(() => service.close(session: session)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await maxDurationController.close();
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
      VoiceInputState.completed(transcript: "hello"),
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
      when(() => service.stopAndTranscribe(session: session)).thenThrow(VoiceTranscriptionError.networkError());
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
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
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
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
      isA<VoiceInputTranscriptionFailed>(),
    ],
  );

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

  test("close synchronously invalidates before asynchronous cleanup", () async {
    final cubit = VoiceInputCubit(service: service, session: session);

    await cubit.close();

    verifyInOrder([
      () => service.invalidate(session: session),
      () => service.close(session: session),
    ]);
  });
}
