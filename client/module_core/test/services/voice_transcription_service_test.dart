import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockVoiceRepository() extends Mock implements VoiceRepository;

class MockVoiceCapture() extends Mock implements VoiceCapture;

class MockVoiceCaptureSession() extends Mock implements VoiceCaptureSession;

void main() {
  late MockVoiceRepository repository;
  late MockVoiceCapture capture;
  late MockVoiceCaptureSession captureSession;
  late VoiceTranscriptionService service;
  late VoiceTranscriptionSession session;

  const artifact = VoiceRecordingArtifact(path: "/tmp/voice.m4a", mimeType: "audio/mp4");

  setUpAll(() {
    registerFallbackValue(artifact);
  });

  setUp(() {
    repository = MockVoiceRepository();
    capture = MockVoiceCapture();
    captureSession = MockVoiceCaptureSession();
    when(capture.createSession).thenReturn(captureSession);
    when(capture.prewarm).thenAnswer((_) async {});
    when(() => captureSession.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(captureSession.start).thenAnswer((_) async {});
    when(captureSession.stop).thenAnswer((_) async => artifact);
    when(captureSession.cancel).thenAnswer((_) async {});
    when(captureSession.releaseOperation).thenAnswer((_) async {});
    when(() => captureSession.deleteArtifact(artifact: any(named: "artifact"))).thenAnswer((_) async {});
    when(captureSession.close).thenAnswer((_) async {});
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.success(transcript: "hello"));
    service = VoiceTranscriptionService(repository: repository, capture: capture);
    session = service.createSession();
  });

  test("creates one distinct platform session for each composer", () {
    final firstCapture = MockVoiceCaptureSession();
    final secondCapture = MockVoiceCaptureSession();
    var created = 0;
    when(capture.createSession).thenAnswer((_) => created++ == 0 ? firstCapture : secondCapture);

    final first = service.createSession();
    final second = service.createSession();

    expect(identical(first, second), isFalse);
    expect(created, 2);
  });

  test("owns capture, repository mapping, cleanup, and lifecycle transitions", () async {
    await service.start(session: session);
    final transcript = await service.stopAndTranscribe(session: session);

    expect(transcript, "hello");
    verify(captureSession.start).called(1);
    verify(captureSession.stop).called(1);
    verify(
      () => repository.transcribe(audioFilePath: artifact.path, mimeType: artifact.mimeType),
    ).called(1);
    verify(captureSession.releaseOperation).called(1);
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);

    await service.start(session: session);
    verify(captureSession.start).called(1);
  });

  test("shares one in-flight prewarm attempt per composer session", () async {
    final completer = Completer<void>();
    when(capture.prewarm).thenAnswer((_) => completer.future);

    final first = service.prewarm(session: session);
    final second = service.prewarm(session: session);

    expect(identical(first, second), isTrue);
    verify(capture.prewarm).called(1);
    completer.complete();
    await first;
  });

  test("waits for prewarm before native capture", () async {
    final completer = Completer<void>();
    when(capture.prewarm).thenAnswer((_) => completer.future);

    unawaited(service.prewarm(session: session));
    final start = service.start(session: session);
    await Future<void>.delayed(Duration.zero);
    verifyNever(captureSession.start);

    completer.complete();
    await start;
    verify(captureSession.start).called(1);
  });

  test("maps platform permission and capture failures", () async {
    when(captureSession.start).thenThrow(VoiceCaptureError.permissionDenied());
    await expectLater(
      service.start(session: session),
      throwsA(isA<MicrophonePermissionDeniedError>()),
    );

    when(captureSession.start).thenThrow(VoiceCaptureError.failed());
    await expectLater(
      service.start(session: session),
      throwsA(isA<RecordingFailedError>()),
    );
  });

  test("maps every repository outcome to the existing typed service errors", () async {
    final outcomes = <VoiceTranscriptionOutcome, Type>{
      const VoiceTranscriptionOutcome.notAuthenticated(): NotAuthenticatedVoiceError,
      const VoiceTranscriptionOutcome.serverFailure(statusCode: 503): ServerVoiceError,
      const VoiceTranscriptionOutcome.networkFailure(): NetworkVoiceError,
      const VoiceTranscriptionOutcome.emptyTranscript(): EmptyTranscriptError,
    };

    for (final MapEntry(key: outcome, value: errorType) in outcomes.entries) {
      reset(repository);
      when(
        () => repository.transcribe(
          audioFilePath: any(named: "audioFilePath"),
          mimeType: any(named: "mimeType"),
        ),
      ).thenAnswer((_) async => outcome);

      await service.start(session: session);
      await expectLater(
        service.stopAndTranscribe(session: session),
        throwsA(predicate<Object>((error) => error.runtimeType == errorType)),
      );
    }
  });

  test("cancellation fences an in-flight upload and deletes its artifact", () async {
    final response = Completer<VoiceTranscriptionOutcome>();
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) => response.future);

    await service.start(session: session);
    final transcription = service.stopAndTranscribe(session: session);
    await Future<void>.delayed(Duration.zero);
    await service.cancel(session: session);
    await service.start(session: session);
    response.complete(const VoiceTranscriptionOutcome.success(transcript: "stale"));

    await expectLater(transcription, throwsA(isA<TranscriptionCancelledError>()));
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(2);
    verify(captureSession.releaseOperation).called(1);
    await service.cancel(session: session);
  });

  test("emits and cancels the service-owned maximum-duration timer", () {
    fakeAsync((async) {
      var reached = 0;
      service.maxDurationReachedStream(session: session).listen((_) => reached++);
      unawaited(service.start(session: session));
      async.flushMicrotasks();

      async.elapse(maxRecordingDuration);
      expect(reached, 1);

      unawaited(service.cancel(session: session));
      async.flushMicrotasks();
      async.elapse(maxRecordingDuration);
      expect(reached, 1);
    });
  });

  test("close synchronously fences startup before disposing native state", () async {
    final startCompleter = Completer<void>();
    when(captureSession.start).thenAnswer((_) => startCompleter.future);

    final starting = service.start(session: session);
    await Future<void>.delayed(Duration.zero);
    service.invalidate(session: session);
    final closing = service.close(session: session);
    startCompleter.complete();

    await expectLater(starting, throwsA(isA<TranscriptionCancelledError>()));
    await closing;
    verify(captureSession.cancel).called(1);
    verify(captureSession.close).called(1);
  });
}
