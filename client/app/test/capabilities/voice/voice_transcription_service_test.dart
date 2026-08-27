import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("VoiceTranscriptionService", () {
    late MockHostedVoiceInputService mockHostedVoiceInputService;
    late MockAudioRecorder mockRecorder;
    late MockRecorderPrewarmClient mockRecorderPrewarmClient;
    late MockRecordingFileProvider mockFileProvider;
    late MockWakeLockService mockWakeLockService;
    late MockAudioFormatConfig mockAudioFormat;
    late VoiceTranscriptionService service;
    late Directory tempDir;
    late String recordingPath;
    late int hostedVoiceRecordingGeneration;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("voice_service_test");
      recordingPath = "${tempDir.path}/recording.m4a";
      hostedVoiceRecordingGeneration = 0;

      mockHostedVoiceInputService = MockHostedVoiceInputService();
      mockRecorder = MockAudioRecorder();
      mockRecorderPrewarmClient = MockRecorderPrewarmClient();
      mockFileProvider = MockRecordingFileProvider();
      mockWakeLockService = MockWakeLockService();
      mockAudioFormat = MockAudioFormatConfig();

      when(mockRecorder.hasPermission).thenAnswer((_) async => true);
      when(() => mockRecorder.hasPermission(request: false)).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: "path"))).thenAnswer((_) async {});
      when(mockRecorder.stop).thenAnswer((_) async => recordingPath);
      when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer((_) => const Stream.empty());
      when(mockRecorder.dispose).thenAnswer((_) async {});
      when(
        () => mockRecorderPrewarmClient.prewarm(
          sampleRate: any(named: "sampleRate"),
          bitRate: any(named: "bitRate"),
          numChannels: any(named: "numChannels"),
        ),
      ).thenAnswer((_) async {});
      when(() => mockFileProvider.createRecordingPath()).thenAnswer((_) async => recordingPath);
      when(mockWakeLockService.enable).thenAnswer((_) async {});
      when(mockWakeLockService.disable).thenAnswer((_) async {});
      when(() => mockAudioFormat.encoder).thenReturn(AudioEncoder.aacLc);
      when(() => mockAudioFormat.bitRate).thenReturn(128000);
      when(() => mockAudioFormat.sampleRate).thenReturn(44100);
      when(() => mockAudioFormat.numChannels).thenReturn(1);
      when(() => mockAudioFormat.mimeType).thenReturn("audio/mp4");
      when(() => mockAudioFormat.fileExtension).thenReturn("m4a");
      when(
        () => mockHostedVoiceInputService.recordingStarted(projectId: any(named: "projectId")),
      ).thenAnswer((_) => ++hostedVoiceRecordingGeneration);

      service = VoiceTranscriptionService(
        hostedVoiceInputService: mockHostedVoiceInputService,
        recorder: mockRecorder,
        recorderPrewarmClient: mockRecorderPrewarmClient,
        fileProvider: mockFileProvider,
        wakeLockService: mockWakeLockService,
        audioFormat: mockAudioFormat,
      );
    });

    tearDown(() async {
      await service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group("prewarmRecording", () {
      test("does not request permission or touch native resources when permission is absent", () async {
        when(() => mockRecorder.hasPermission(request: false)).thenAnswer((_) async => false);

        await service.prewarmRecording();

        verify(() => mockRecorder.hasPermission(request: false)).called(1);
        verifyNever(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: any(named: "sampleRate"),
            bitRate: any(named: "bitRate"),
            numChannels: any(named: "numChannels"),
          ),
        );
      });

      test("passes the exact production recording format to the native prewarmer", () async {
        await service.prewarmRecording();

        verify(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: 44100,
            bitRate: 128000,
            numChannels: 1,
          ),
        ).called(1);
      });

      test("shares one in-flight attempt between concurrent callers", () async {
        final nativePrewarm = Completer<void>();
        when(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: any(named: "sampleRate"),
            bitRate: any(named: "bitRate"),
            numChannels: any(named: "numChannels"),
          ),
        ).thenAnswer((_) => nativePrewarm.future);

        final first = service.prewarmRecording();
        final second = service.prewarmRecording();
        expect(identical(first, second), isTrue);

        nativePrewarm.complete();
        await Future.wait([first, second]);

        verify(() => mockRecorder.hasPermission(request: false)).called(1);
        verify(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: 44100,
            bitRate: 128000,
            numChannels: 1,
          ),
        ).called(1);
      });

      test("contains a native failure and allows a later retry", () async {
        var attempts = 0;
        when(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: any(named: "sampleRate"),
            bitRate: any(named: "bitRate"),
            numChannels: any(named: "numChannels"),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw Exception("prewarm failed");
        });

        await service.prewarmRecording();
        await service.prewarmRecording();

        expect(attempts, 2);
      });

      test("startRecording waits for an in-flight prewarm before starting native capture", () async {
        final nativePrewarm = Completer<void>();
        when(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: any(named: "sampleRate"),
            bitRate: any(named: "bitRate"),
            numChannels: any(named: "numChannels"),
          ),
        ).thenAnswer((_) => nativePrewarm.future);

        final prewarmFuture = service.prewarmRecording();
        await Future<void>.delayed(Duration.zero);
        final startFuture = service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));

        nativePrewarm.complete();
        await prewarmFuture;
        await startFuture;

        verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
      });

      test("a timed-out recording attempt stays serialized until prewarm finishes", () {
        fakeAsync((async) {
          final nativePrewarm = Completer<void>();
          Object? startError;
          when(
            () => mockRecorderPrewarmClient.prewarm(
              sampleRate: any(named: "sampleRate"),
              bitRate: any(named: "bitRate"),
              numChannels: any(named: "numChannels"),
            ),
          ).thenAnswer((_) => nativePrewarm.future);

          unawaited(service.prewarmRecording());
          async.flushMicrotasks();
          unawaited(
            service
                .startRecording(projectId: "project-1")
                .then<void>(
                  (_) {},
                  onError: (Object error) => startError = error,
                ),
          );
          async.flushMicrotasks();
          verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));

          try {
            async.elapse(const Duration(seconds: 2));
            async.flushMicrotasks();

            expect(startError, isA<TimeoutException>());
            expect(service.isBusy, isFalse);
            expect(service.isRecording, isFalse);
            verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));

            nativePrewarm.complete();
            async.flushMicrotasks();
            unawaited(service.startRecording(projectId: "project-1"));
            async.flushMicrotasks();

            expect(service.isRecording, isTrue);
            verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
          } finally {
            if (!nativePrewarm.isCompleted) nativePrewarm.complete();
            async.flushMicrotasks();
          }
        });
      });
    });

    group("startRecording", () {
      test("success: checks permission, starts recorder, enables wake lock, sets flags", () async {
        await service.startRecording(projectId: "project-1");

        expect(service.isRecording, isTrue);
        expect(service.isBusy, isTrue);
        verify(mockRecorder.hasPermission).called(1);
        verify(() => mockFileProvider.createRecordingPath()).called(1);
        final config =
            verify(
                  () => mockRecorder.start(captureAny(), path: recordingPath),
                ).captured.single
                as RecordConfig;
        expect(config.encoder, AudioEncoder.aacLc);
        expect(config.bitRate, 128000);
        expect(config.sampleRate, 44100);
        expect(config.numChannels, 1);
        verify(mockWakeLockService.enable).called(1);
        verify(() => mockHostedVoiceInputService.recordingStarted(projectId: "project-1")).called(1);
      });

      test("already busy: returns without new recorder call", () async {
        await service.startRecording(projectId: "project-1");
        await service.startRecording(projectId: "project-1");

        verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
      });

      test("permission denied: throws MicrophonePermissionDeniedError and resets busy", () async {
        when(mockRecorder.hasPermission).thenAnswer((_) async => false);

        await expectLater(
          () => service.startRecording(projectId: "project-1"),
          throwsA(isA<MicrophonePermissionDeniedError>()),
        );

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
        verifyNever(mockWakeLockService.enable);
      });

      test("recorder.start fails: throws RecordingFailedError, cleans file, resets busy", () async {
        final file = File(recordingPath);
        await file.writeAsString("temp");

        when(() => mockRecorder.start(any(), path: any(named: "path"))).thenThrow(Exception("start failed"));

        await expectLater(() => service.startRecording(projectId: "project-1"), throwsA(isA<RecordingFailedError>()));

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
        expect(file.existsSync(), isFalse);
        verifyNever(mockWakeLockService.enable);
      });
    });

    group("stopAndTranscribe", () {
      Future<void> startWithRecordedFile() async {
        await service.startRecording(projectId: "project-1");
        await File(recordingPath).writeAsBytes([1, 2, 3]);
      }

      test("success: stops recorder, transcribes, returns text, disables wake lock, resets busy", () async {
        await startWithRecordedFile();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: "project-1",
          ),
        ).thenAnswer((_) async => ApiResponse.success("hello world"));

        final result = await service.stopAndTranscribe(projectId: "project-1");

        expect(result, "hello world");
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockRecorder.stop).called(1);
        verify(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: "project-1",
          ),
        ).called(1);
        verify(mockWakeLockService.disable).called(1);
        verify(
          () => mockHostedVoiceInputService.recordingFinished(recordingGeneration: 1),
        ).called(1);
      });

      test("not recording: throws NotRecordingError", () async {
        await expectLater(() => service.stopAndTranscribe(projectId: "project-1"), throwsA(isA<NotRecordingError>()));
      });

      test("recorder.stop throws: throws RecordingFailedError, disables wake lock", () async {
        await service.startRecording(projectId: "project-1");
        when(mockRecorder.stop).thenThrow(Exception("stop failed"));

        await expectLater(
          () => service.stopAndTranscribe(projectId: "project-1"),
          throwsA(isA<RecordingFailedError>()),
        );

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("recorder.stop returns null: throws RecordingFailedError", () async {
        await service.startRecording(projectId: "project-1");
        when(mockRecorder.stop).thenAnswer((_) async => null);

        await expectLater(
          () => service.stopAndTranscribe(projectId: "project-1"),
          throwsA(isA<RecordingFailedError>()),
        );

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
      });

      test("API notAuthenticated error: throws NotAuthenticatedVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: "project-1",
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.notAuthenticated()));

        await expectLater(
          () => service.stopAndTranscribe(projectId: "project-1"),
          throwsA(isA<NotAuthenticatedVoiceError>()),
        );
      });

      test("API nonSuccessCode error: throws ServerVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: "project-1",
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "down")));

        await expectLater(() => service.stopAndTranscribe(projectId: "project-1"), throwsA(isA<ServerVoiceError>()));
      });

      test("API dartHttpClient error: throws NetworkVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: "project-1",
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("network"))));

        await expectLater(() => service.stopAndTranscribe(projectId: "project-1"), throwsA(isA<NetworkVoiceError>()));
      });
    });

    group("cancelRecording", () {
      test("cancels active recording: stops recorder, disables wake lock, resets flags", () async {
        await service.startRecording(projectId: "project-1");

        await service.cancelRecording();

        verify(mockRecorder.stop).called(1);
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("cancels during transcription: throws TranscriptionCancelledError when HTTP completes", () async {
        await service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: any(named: "projectId"),
          ),
        ).thenAnswer((_) => transcribeCompleter.future);

        final stopFuture = service.stopAndTranscribe(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isTrue);

        await service.cancelRecording();

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockRecorder.stop).called(1);

        // HTTP call returns, but the cancelled flag causes stopAndTranscribe
        // to throw instead of returning the transcript.
        transcribeCompleter.complete(ApiResponse.success("should be ignored"));
        await expectLater(stopFuture, throwsA(isA<TranscriptionCancelledError>()));
      });

      test("cancels during transcription: HTTP error after cancel still throws TranscriptionCancelledError", () async {
        await service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: any(named: "projectId"),
          ),
        ).thenAnswer((_) => transcribeCompleter.future);

        final stopFuture = service.stopAndTranscribe(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);

        await service.cancelRecording();

        // HTTP call returns error — but cancelled flag takes precedence.
        transcribeCompleter.complete(ApiResponse.error(ApiError.dartHttpClient(Exception("timeout"))));
        await expectLater(stopFuture, throwsA(isA<TranscriptionCancelledError>()));

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
      });

      test("cancel then restart: stale transcript from first call is discarded", () async {
        // Start recording #1 and begin transcription.
        await service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter1 = Completer<ApiResponse<String>>();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: any(named: "projectId"),
          ),
        ).thenAnswer((_) => transcribeCompleter1.future);

        final stopFuture1 = service.stopAndTranscribe(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);

        // Cancel transcription #1.
        await service.cancelRecording();

        // Start recording #2 immediately and begin transcription.
        await service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);
        await File(recordingPath).writeAsBytes([4, 5, 6]);

        final transcribeCompleter2 = Completer<ApiResponse<String>>();
        when(
          () => mockHostedVoiceInputService.transcribe(
            audioFilePath: recordingPath,
            mimeType: "audio/mp4",
            projectId: any(named: "projectId"),
          ),
        ).thenAnswer((_) => transcribeCompleter2.future);

        final stopFuture2 = service.stopAndTranscribe(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);

        // Transcription #1 returns — must be discarded despite #2 resetting state.
        transcribeCompleter1.complete(ApiResponse.success("stale transcript"));
        await expectLater(stopFuture1, throwsA(isA<TranscriptionCancelledError>()));
        verifyNever(
          () => mockHostedVoiceInputService.recordingFinished(recordingGeneration: 2),
        );

        // Transcription #2 returns — should succeed normally and remains the
        // owner of core recording state until its own cleanup.
        transcribeCompleter2.complete(ApiResponse.success("fresh transcript"));
        final result = await stopFuture2;
        expect(result, "fresh transcript");
        verify(
          () => mockHostedVoiceInputService.recordingFinished(recordingGeneration: 2),
        ).called(1);
      });

      test("cancel during wake lock enable async gap: no stale amplitude monitoring", () async {
        final amplitudeController = StreamController<Amplitude>();
        addTearDown(amplitudeController.close);
        when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer((_) => amplitudeController.stream);

        final enableCompleter = Completer<void>();
        when(mockWakeLockService.enable).thenAnswer((_) => enableCompleter.future);

        final emitted = <double>[];
        service.amplitudeStream.listen(emitted.add);

        // Start recording — will hang at _wakeLockService.enable()
        final startFuture = service.startRecording(projectId: "project-1");
        await Future<void>.delayed(Duration.zero);

        // Cancel while enable() is still in flight
        await service.cancelRecording();

        // Complete the pending enable — startRecording resumes
        enableCompleter.complete();
        await startFuture;

        // Emit amplitude data — must NOT be forwarded since recording was cancelled
        amplitudeController.add(Amplitude(current: -30.0, max: 0.0));
        await Future<void>.delayed(Duration.zero);

        // Only the 0.0 from _stopAmplitudeMonitoring during cancel should appear.
        expect(emitted, [0.0]);
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
      });

      test("not busy: returns immediately", () async {
        await service.cancelRecording();

        verifyNever(mockRecorder.stop);
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
      });
    });

    group("max duration timer", () {
      test("emits onMaxDurationReached after maxRecordingDuration", () {
        fakeAsync((async) {
          service.startRecording(projectId: "project-1");
          async.flushMicrotasks();
          expect(service.isRecording, isTrue);

          bool eventReceived = false;
          service.onMaxDurationReached.listen((_) => eventReceived = true);

          // Just before the limit — no event yet.
          async.elapse(maxRecordingDuration - const Duration(milliseconds: 1));
          expect(eventReceived, isFalse);

          // Exactly at the limit — event fires.
          async.elapse(const Duration(milliseconds: 1));
          expect(eventReceived, isTrue);
          // Service still considers itself recording — the listener must call stopAndTranscribe.
          expect(service.isRecording, isTrue);
        });
      });

      test("does not emit if stopAndTranscribe is called before limit", () {
        fakeAsync((async) {
          service.startRecording(projectId: "project-1");
          async.flushMicrotasks();

          File(recordingPath).writeAsBytesSync([1, 2, 3]);
          when(
            () => mockHostedVoiceInputService.transcribe(
              audioFilePath: recordingPath,
              mimeType: "audio/mp4",
              projectId: "project-1",
            ),
          ).thenAnswer((_) async => ApiResponse.success("text"));

          bool eventReceived = false;
          service.onMaxDurationReached.listen((_) => eventReceived = true);

          async.elapse(const Duration(minutes: 7));
          service.stopAndTranscribe(projectId: "project-1");
          async.flushMicrotasks();

          // Past the original limit — timer was cancelled by stopAndTranscribe.
          async.elapse(const Duration(minutes: 10));
          expect(eventReceived, isFalse);
        });
      });

      test("does not emit if cancelRecording is called before limit", () {
        fakeAsync((async) {
          service.startRecording(projectId: "project-1");
          async.flushMicrotasks();

          bool eventReceived = false;
          service.onMaxDurationReached.listen((_) => eventReceived = true);

          async.elapse(const Duration(minutes: 7));
          service.cancelRecording();
          async.flushMicrotasks();

          // Past the original limit — timer was cancelled by cancelRecording.
          async.elapse(const Duration(minutes: 10));
          expect(eventReceived, isFalse);
        });
      });
    });

    group("amplitude stream", () {
      test("emits normalized values during recording", () async {
        final amplitudeController = StreamController<Amplitude>();
        addTearDown(amplitudeController.close);

        when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer((_) => amplitudeController.stream);

        final emitted = <double>[];
        final sub = service.amplitudeStream.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.startRecording(projectId: "project-1");
        amplitudeController.add(Amplitude(current: -30.0, max: 0.0));
        amplitudeController.add(Amplitude(current: 0.0, max: 0.0));
        await Future<void>.delayed(Duration.zero);

        expect(emitted[0], closeTo(0.5, 0.01));
        expect(emitted[1], 1.0);
      });

      test("emits 0.0 when monitoring stops", () async {
        final zeroEmission = expectLater(service.amplitudeStream, emits(0.0));

        await service.startRecording(projectId: "project-1");
        await service.cancelRecording();

        await zeroEmission;
      });
    });
  });
}
