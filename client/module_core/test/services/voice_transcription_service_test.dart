import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show HealthResponse, Project, ProjectGlossaryKey;
import "package:test/test.dart";

class MockVoiceRepository() extends Mock implements VoiceRepository;

class MockProjectRepository() extends Mock implements ProjectRepository;

class MockVoiceModeRepository() extends Mock implements VoiceModeRepository;

class MockVoiceCapture() extends Mock implements VoiceCapture;

class MockVoiceCaptureSession() extends Mock implements VoiceCaptureSession;

class MockConnectionService() extends Mock implements ConnectionService;

ConnectionStatus _connectedTo({required String bridgeId}) => ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token", bridgeId: bridgeId),
  health: const HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
);

void main() {
  late MockVoiceRepository repository;
  late MockProjectRepository projectRepository;
  late MockVoiceModeRepository voiceModeRepository;
  late MockVoiceCapture capture;
  late MockVoiceCaptureSession captureSession;
  late MockConnectionService connectionService;
  late VoiceTranscriptionService service;
  late VoiceTranscriptionSession session;

  const artifact = VoiceRecordingArtifact(path: "/tmp/voice.m4a", mimeType: "audio/mp4");

  setUpAll(() {
    registerFallbackValue(artifact);
  });

  setUp(() {
    repository = MockVoiceRepository();
    projectRepository = MockProjectRepository();
    voiceModeRepository = MockVoiceModeRepository();
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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.success(transcript: "hello"));
    connectionService = MockConnectionService();
    when(() => connectionService.currentStatus).thenReturn(_connectedTo(bridgeId: "computer-a"));
    service = VoiceTranscriptionService(
      repository: repository,
      projectRepository: projectRepository,
      voiceModeRepository: voiceModeRepository,
      capture: capture,
      connectionService: connectionService,
    );
    session = service.createSession(projectId: null, allowLive: false);
  });

  test("creates one distinct platform session for each composer", () {
    final firstCapture = MockVoiceCaptureSession();
    final secondCapture = MockVoiceCaptureSession();
    var created = 0;
    when(capture.createSession).thenAnswer((_) => created++ == 0 ? firstCapture : secondCapture);

    final first = service.createSession(projectId: null, allowLive: false);
    final second = service.createSession(projectId: null, allowLive: false);

    expect(identical(first, second), isFalse);
    expect(created, 2);
  });

  test("owns capture, repository mapping, cleanup, and lifecycle transitions", () async {
    await service.start(session: session);
    final result = await service.stopAndTranscribe(session: session);

    expect(result.transcript, "hello");
    expect(result.outcome, VoiceDictationOutcome.finished);
    expect(result.mode, VoiceDictationMode.afterRecording);
    verify(captureSession.start).called(1);
    verify(captureSession.stop).called(1);
    verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: null,
      ),
    ).called(1);
    verify(captureSession.releaseOperation).called(1);
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);

    await service.start(session: session);
    verify(captureSession.start).called(1);
  });

  test("forwards an available opaque project glossary key", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    when(
      () => projectRepository.getProject(projectId: "project-1"),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        Project(
          id: "project-1",
          name: "Project",
          path: "/project",
          time: null,
          voiceGlossaryKey: glossaryKey,
        ),
      ),
    );
    final scopedSession = service.createSession(projectId: "project-1", allowLive: false);
    await untilCalled(() => projectRepository.getProject(projectId: "project-1"));
    await Future<void>.delayed(Duration.zero);

    await service.start(session: scopedSession);
    await service.stopAndTranscribe(session: scopedSession);

    verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: glossaryKey,
      ),
    ).called(1);
  });

  test("a pending project context keeps the active interaction unscoped", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    final projectResponse = Completer<ApiResponse<Project>>();
    when(
      () => projectRepository.getProject(projectId: "project-1"),
    ).thenAnswer((_) => projectResponse.future);
    final scopedSession = service.createSession(projectId: "project-1", allowLive: false);
    await untilCalled(() => projectRepository.getProject(projectId: "project-1"));

    await service.start(session: scopedSession);
    await service.stopAndTranscribe(session: scopedSession);
    projectResponse.complete(
      ApiResponse.success(
        Project(
          id: "project-1",
          name: "Project",
          path: "/project",
          time: null,
          voiceGlossaryKey: glossaryKey,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await service.start(session: scopedSession);
    await service.stopAndTranscribe(session: scopedSession);

    final forwardedKeys = verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: captureAny(named: "projectGlossaryKey"),
      ),
    ).captured;
    expect(forwardedKeys, [null, glossaryKey]);
  });

  group("remembered project glossary keys", () {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );

    ApiResponse<Project> projectAnswer({required ProjectGlossaryKey? key}) => ApiResponse.success(
      Project(id: "project-1", name: "Project", path: "/project", time: null, voiceGlossaryKey: key),
    );

    Future<void> learnKey() async {
      when(
        () => projectRepository.getProject(projectId: "project-1"),
      ).thenAnswer((_) async => projectAnswer(key: glossaryKey));
      service.createSession(projectId: "project-1", allowLive: false);
      await Future<void>.delayed(Duration.zero);
    }

    Future<ProjectGlossaryKey?> uploadedKey({required VoiceTranscriptionSession from}) async {
      await service.start(session: from);
      await service.stopAndTranscribe(session: from);
      return verify(
            () => repository.transcribe(
              audioFilePath: artifact.path,
              mimeType: artifact.mimeType,
              projectGlossaryKey: captureAny(named: "projectGlossaryKey"),
            ),
          ).captured.single
          as ProjectGlossaryKey?;
    }

    void leaveBridgeUnanswered() {
      when(
        () => projectRepository.getProject(projectId: "project-1"),
      ).thenAnswer((_) => Completer<ApiResponse<Project>>().future);
    }

    test("a new composer has the key before the bridge answers, and still asks", () async {
      await learnKey();
      leaveBridgeUnanswered();
      clearInteractions(projectRepository);

      final next = service.createSession(projectId: "project-1", allowLive: false);

      verify(() => projectRepository.getProject(projectId: "project-1")).called(1);
      expect(await uploadedKey(from: next), glossaryKey);
    });

    test("another computer does not get the key", () async {
      await learnKey();
      leaveBridgeUnanswered();
      when(() => connectionService.currentStatus).thenReturn(_connectedTo(bridgeId: "computer-b"));

      final next = service.createSession(projectId: "project-1", allowLive: false);

      expect(await uploadedKey(from: next), isNull);
    });

    test("an answer is remembered for the computer that was asked", () async {
      final answer = Completer<ApiResponse<Project>>();
      when(() => projectRepository.getProject(projectId: "project-1")).thenAnswer((_) => answer.future);
      service.createSession(projectId: "project-1", allowLive: false);
      when(() => connectionService.currentStatus).thenReturn(_connectedTo(bridgeId: "computer-b"));
      answer.complete(projectAnswer(key: glossaryKey));
      await Future<void>.delayed(Duration.zero);
      leaveBridgeUnanswered();

      final next = service.createSession(projectId: "project-1", allowLive: false);

      expect(await uploadedKey(from: next), isNull);
    });

    test("an answer without a key keeps the known one", () async {
      await learnKey();
      when(
        () => projectRepository.getProject(projectId: "project-1"),
      ).thenAnswer((_) async => projectAnswer(key: null));

      final next = service.createSession(projectId: "project-1", allowLive: false);
      await Future<void>.delayed(Duration.zero);

      expect(await uploadedKey(from: next), glossaryKey);
    });

    test("a known key does not ask again for each dictation", () async {
      await learnKey();
      final next = service.createSession(projectId: "project-1", allowLive: false);
      await Future<void>.delayed(Duration.zero);
      clearInteractions(projectRepository);

      await uploadedKey(from: next);

      verifyNever(() => projectRepository.getProject(projectId: "project-1"));
    });

    test("nothing is remembered while disconnected", () async {
      when(() => connectionService.currentStatus).thenReturn(const ConnectionStatus.disconnected());
      await learnKey();
      leaveBridgeUnanswered();
      when(() => connectionService.currentStatus).thenReturn(_connectedTo(bridgeId: "computer-a"));

      final next = service.createSession(projectId: "project-1", allowLive: false);

      expect(await uploadedKey(from: next), isNull);
    });
  });

  test("a key that arrives during the recording reaches the upload", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    final projectResponse = Completer<ApiResponse<Project>>();
    when(
      () => projectRepository.getProject(projectId: "project-1"),
    ).thenAnswer((_) => projectResponse.future);
    final scopedSession = service.createSession(projectId: "project-1", allowLive: false);
    await untilCalled(() => projectRepository.getProject(projectId: "project-1"));

    await service.start(session: scopedSession);
    projectResponse.complete(
      ApiResponse.success(
        Project(
          id: "project-1",
          name: "Project",
          path: "/project",
          time: null,
          voiceGlossaryKey: glossaryKey,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await service.stopAndTranscribe(session: scopedSession);

    verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: glossaryKey,
      ),
    ).called(1);
  });

  test("refreshes missing context for a later interaction without delaying capture", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    final refreshRequested = Completer<void>();
    final refreshResponse = Completer<ApiResponse<Project>>();
    var requestCount = 0;
    when(
      () => projectRepository.getProject(projectId: "project-1"),
    ).thenAnswer((_) {
      requestCount++;
      if (requestCount == 1) {
        return Future.value(
          ApiResponse.success(
            const Project(
              id: "project-1",
              name: "Project",
              path: "/project",
              time: null,
              voiceGlossaryKey: null,
            ),
          ),
        );
      }
      refreshRequested.complete();
      return refreshResponse.future;
    });
    final scopedSession = service.createSession(projectId: "project-1", allowLive: false);
    await untilCalled(() => projectRepository.getProject(projectId: "project-1"));
    await Future<void>.delayed(Duration.zero);

    await service.start(session: scopedSession);
    await refreshRequested.future;
    await service.stopAndTranscribe(session: scopedSession);
    refreshResponse.complete(
      ApiResponse.success(
        Project(
          id: "project-1",
          name: "Project",
          path: "/project",
          time: null,
          voiceGlossaryKey: glossaryKey,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await service.start(session: scopedSession);
    await service.stopAndTranscribe(session: scopedSession);

    final forwardedKeys = verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: captureAny(named: "projectGlossaryKey"),
      ),
    ).captured;
    expect(forwardedKeys, [null, glossaryKey]);
    expect(requestCount, 2);
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
          projectGlossaryKey: any(named: "projectGlossaryKey"),
        ),
      ).thenAnswer((_) async => outcome);
      final candidateSession = service.createSession(projectId: null, allowLive: false);

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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: null,
      ),
    ).called(2);
    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
  });

  test("a retry uses a key that arrived after the first attempt", () async {
    final glossaryKey = ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    );
    final projectResponse = Completer<ApiResponse<Project>>();
    when(
      () => projectRepository.getProject(projectId: "project-1"),
    ).thenAnswer((_) => projectResponse.future);
    var attempts = 0;
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectGlossaryKey: any(named: "projectGlossaryKey"),
      ),
    ).thenAnswer(
      (_) async => switch (attempts++) {
        0 => const VoiceTranscriptionOutcome.networkFailure(),
        1 => const VoiceTranscriptionOutcome.success(transcript: "retried"),
        _ => const VoiceTranscriptionOutcome.success(transcript: "next interaction"),
      },
    );
    final scopedSession = service.createSession(projectId: "project-1", allowLive: false);
    await untilCalled(() => projectRepository.getProject(projectId: "project-1"));

    await service.start(session: scopedSession);
    await expectLater(
      service.stopAndTranscribe(session: scopedSession),
      throwsA(isA<NetworkVoiceError>()),
    );
    projectResponse.complete(
      ApiResponse.success(
        Project(
          id: "project-1",
          name: "Project",
          path: "/project",
          time: null,
          voiceGlossaryKey: glossaryKey,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await service.retry(session: scopedSession), "retried");
    await service.start(session: scopedSession);
    expect(
      (await service.stopAndTranscribe(session: scopedSession)).transcript,
      "next interaction",
    );

    final forwardedKeys = verify(
      () => repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: captureAny(named: "projectGlossaryKey"),
      ),
    ).captured;
    expect(forwardedKeys, [null, glossaryKey, glossaryKey]);
    verify(captureSession.start).called(2);
    verify(captureSession.stop).called(2);
  });

  test("cancellation during capture release cannot strand a retained artifact", () async {
    final releaseCompleter = Completer<void>();
    when(captureSession.releaseOperation).thenAnswer((_) => releaseCompleter.future);
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectGlossaryKey: any(named: "projectGlossaryKey"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.networkFailure());

    await service.start(session: session);
    final transcription = expectLater(
      service.stopAndTranscribe(session: session),
      throwsA(isA<NetworkVoiceError>()),
    );
    await Future<void>.delayed(Duration.zero);
    verify(captureSession.releaseOperation).called(1);

    final cancelling = service.cancel(session: session);
    await Future<void>.delayed(Duration.zero);
    verify(captureSession.releaseOperation).called(1);
    releaseCompleter.complete();
    await cancelling;
    await transcription;

    verify(() => captureSession.deleteArtifact(artifact: artifact)).called(1);
    await service.start(session: session);
    verify(captureSession.start).called(2);
  });

  test("manual retry cancellation returns to retry-pending with the artifact retained", () async {
    final retryResponse = Completer<VoiceTranscriptionOutcome>();
    var attempts = 0;
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
        projectGlossaryKey: any(named: "projectGlossaryKey"),
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
