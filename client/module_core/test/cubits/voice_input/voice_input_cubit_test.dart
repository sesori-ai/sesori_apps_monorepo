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
    when(service.createSession).thenReturn(session);
    when(() => service.amplitudeStream(session: session)).thenAnswer((_) => const Stream<double>.empty());
    when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationController.stream);
    when(() => service.prewarm(session: session)).thenAnswer((_) async {});
    when(() => service.start(session: session)).thenAnswer((_) async {});
    when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) async => "hello");
    when(() => service.cancel(session: session)).thenAnswer((_) async {});
    when(() => service.invalidate(session: session)).thenReturn(null);
    when(() => service.close(session: session)).thenAnswer((_) async {});
  });

  tearDown(() async {
    await maxDurationController.close();
  });

  blocTest<VoiceInputCubit, VoiceInputState>(
    "starts, transcribes, acknowledges, and keeps orchestration behind the service",
    build: () => VoiceInputCubit(service: service),
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
    build: () => VoiceInputCubit(service: service),
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
    "maps a transcription transport failure into transcription-specific state",
    setUp: () {
      when(() => service.stopAndTranscribe(session: session)).thenThrow(VoiceTranscriptionError.networkError());
    },
    build: () => VoiceInputCubit(service: service),
    act: (cubit) async {
      await cubit.startRecording();
      await cubit.stopAndTranscribe(limitReached: false);
    },
    expect: () => [
      const VoiceInputState.starting(),
      const VoiceInputState.recording(),
      const VoiceInputState.transcribing(limitReached: false),
      isA<VoiceInputTranscriptionFailed>().having(
        (state) => state.error,
        "error",
        isA<NetworkVoiceError>(),
      ),
    ],
  );

  test("maximum duration auto-stops through the Cubit with its reason preserved", () async {
    final cubit = VoiceInputCubit(service: service);
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
    build: () => VoiceInputCubit(service: service),
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
    final cubit = VoiceInputCubit(service: service);

    await cubit.close();

    verifyInOrder([
      () => service.invalidate(session: session),
      () => service.close(session: session),
    ]);
  });
}
