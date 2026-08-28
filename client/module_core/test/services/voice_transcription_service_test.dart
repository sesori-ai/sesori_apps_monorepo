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
    when(
      () => captureSession.artifactExists(artifact: any(named: "artifact")),
    ).thenAnswer((_) async => true);
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

  test("maps platform failures without discarding their typed causes", () async {
    final permissionCause = StateError("native permission check failed");
    final permissionError = VoiceCaptureError.permissionDenied(innerError: permissionCause);
    when(captureSession.start).thenThrow(permissionError);
    await expectLater(
      service.start(session: session),
      throwsA(
        isA<MicrophonePermissionDeniedError>().having((error) => error.innerError, "innerError", same(permissionError)),
      ),
    );

    final captureCause = StateError("native recorder failed");
    final captureError = VoiceCaptureError.failed(innerError: captureCause);
    when(captureSession.start).thenThrow(captureError);
    await expectLater(
      service.start(session: session),
      throwsA(
        isA<RecordingFailedError>().having(
          (error) => error.innerError,
          "innerError",
          same(captureError),
        ),
      ),
    );
  });

  test("maps terminal repository outcomes and deletes their artifacts", () async {
    final outcomes = <VoiceTranscriptionOutcome, Type>{
      const VoiceTranscriptionOutcome.notAuthenticated(): NotAuthenticatedVoiceError,
      const VoiceTranscriptionOutcome.terminalServerFailure(statusCode: 503): ServerVoiceError,
      const VoiceTranscriptionOutcome.unexpectedFailure(): RecordingFailedError,
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
      final candidateSession = service.createSession();

      await service.start(session: candidateSession);
      await expectLater(
        service.stopAndTranscribe(session: candidateSession),
        throwsA(predicate<Object>((error) => error.runtimeType == errorType)),
      );
    }

    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(outcomes.length);
  });

  test("retains a local network failure and retries the exact artifact without recording again", () async {
    var attempts = 0;
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer(
      (_) async => attempts++ == 0
          ? const VoiceTranscriptionOutcome.networkFailure()
          : const VoiceTranscriptionOutcome.success(transcript: "retried"),
    );

    await service.start(session: session);
    await expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<NetworkVoiceError>()),
    );
    verifyNever(() => captureSession.deleteArtifact(artifact: artifact));

    expect(await service.retry(session: session), "retried");
    verify(captureSession.start).called(1);
    verify(captureSession.stop).called(1);
    verify(
      () => repository.transcribe(audioFilePath: artifact.path, mimeType: artifact.mimeType),
    ).called(2);
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
  });

  test("manual retry cancellation returns to retry-pending with the artifact retained", () async {
    final retryResponse = Completer<VoiceTranscriptionOutcome>();
    var attempts = 0;
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) {
      attempts++;
      if (attempts == 1) {
        return Future.value(
          const VoiceTranscriptionOutcome.retryableServerFailure(statusCode: 503),
        );
      }
      if (attempts == 2) return retryResponse.future;
      return Future.value(const VoiceTranscriptionOutcome.success(transcript: "eventual"));
    });

    await service.start(session: session);
    await expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<RetryableServerVoiceError>()),
    );

    final cancelledRetry = service.retry(session: session);
    await Future<void>.delayed(Duration.zero);
    await service.cancel(session: session);
    retryResponse.complete(const VoiceTranscriptionOutcome.success(transcript: "stale"));
    await expectLater(cancelledRetry, throwsA(isA<TranscriptionCancelledError>()));
    verifyNever(() => captureSession.deleteArtifact(artifact: artifact));

    expect(await service.retry(session: session), "eventual");
    verify(captureSession.start).called(1);
    verify(captureSession.stop).called(1);
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
  });

  test("discard deletes a retained artifact and returns the session to idle", () async {
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.networkFailure());

    await service.start(session: session);
    await expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<NetworkVoiceError>()),
    );
    await service.discard(session: session);

    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
    await service.start(session: session);
    verify(captureSession.start).called(2);
  });

  test("a missing retained artifact is terminal and clears retry ownership", () async {
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.networkFailure());
    when(() => captureSession.artifactExists(artifact: artifact)).thenAnswer((_) async => false);

    await service.start(session: session);
    await expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<NetworkVoiceError>()),
    );
    await expectLater(
      service.retry(session: session),
      throwsA(isA<MissingRecordingArtifactError>()),
    );

    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
    await service.start(session: session);
    verify(captureSession.start).called(2);
  });

  test("closing a retry-pending session deletes its retained artifact", () async {
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.networkFailure());

    await service.start(session: session);
    await expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<NetworkVoiceError>()),
    );
    service.invalidate(session: session);
    await service.close(session: session);

    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
    verify(captureSession.close).called(1);
  });

  test("cancellation waits for an in-flight recorder stop instead of stopping twice", () async {
    final stopCompleter = Completer<VoiceRecordingArtifact>();
    when(captureSession.stop).thenAnswer((_) => stopCompleter.future);

    await service.start(session: session);
    final transcription = service.stopAndTranscribe(session: session);
    final transcriptionExpectation = expectLater(
      transcription,
      throwsA(isA<TranscriptionCancelledError>()),
    );
    await Future<void>.delayed(Duration.zero);
    final cancelling = service.cancel(session: session);
    await Future<void>.delayed(Duration.zero);

    verifyNever(captureSession.cancel);
    stopCompleter.complete(artifact);
    await cancelling;
    await transcriptionExpectation;

    verify(captureSession.stop).called(1);
    verifyNever(captureSession.cancel);
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
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
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

  test("close waits for an active native stop before disposing capture", () async {
    final stopCompleter = Completer<VoiceRecordingArtifact>();
    when(captureSession.stop).thenAnswer((_) => stopCompleter.future);

    await service.start(session: session);
    final transcription = service.stopAndTranscribe(session: session);
    await Future<void>.delayed(Duration.zero);
    service.invalidate(session: session);
    final closing = service.close(session: session);
    await Future<void>.delayed(Duration.zero);

    verifyNever(captureSession.close);
    stopCompleter.complete(artifact);
    await expectLater(transcription, throwsA(isA<TranscriptionCancelledError>()));
    await closing;

    verify(captureSession.stop).called(1);
    verify(captureSession.close).called(1);
  });

  test("close waits for active cancellation before disposing capture", () async {
    final cancelCompleter = Completer<void>();
    when(captureSession.cancel).thenAnswer((_) => cancelCompleter.future);

    await service.start(session: session);
    final cancelling = service.cancel(session: session);
    await Future<void>.delayed(Duration.zero);
    service.invalidate(session: session);
    final closing = service.close(session: session);
    await Future<void>.delayed(Duration.zero);

    verifyNever(captureSession.close);
    cancelCompleter.complete();
    await cancelling;
    await closing;

    verify(captureSession.cancel).called(1);
    verify(captureSession.close).called(1);
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
