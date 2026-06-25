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
    late MockVoiceApi mockVoiceApi;
    late MockAudioRecorder mockRecorder;
    late MockRecordingFileProvider mockFileProvider;
    late MockWakeLockService mockWakeLockService;
    late MockAudioFormatConfig mockAudioFormat;
    late VoiceTranscriptionService service;
    late Directory tempDir;
    late String recordingPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("voice_service_test");
      recordingPath = "${tempDir.path}/recording.m4a";

      mockVoiceApi = MockVoiceApi();
      mockRecorder = MockAudioRecorder();
      mockFileProvider = MockRecordingFileProvider();
      mockWakeLockService = MockWakeLockService();
      mockAudioFormat = MockAudioFormatConfig();

      when(mockRecorder.hasPermission).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: "path"))).thenAnswer((_) async {});
      when(mockRecorder.stop).thenAnswer((_) async => recordingPath);
      when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer((_) => const Stream.empty());
      when(mockRecorder.dispose).thenAnswer((_) async {});
      when(() => mockFileProvider.createRecordingPath()).thenAnswer((_) async => recordingPath);
      when(mockWakeLockService.enable).thenAnswer((_) async {});
      when(mockWakeLockService.disable).thenAnswer((_) async {});
      when(() => mockAudioFormat.encoder).thenReturn(AudioEncoder.aacLc);
      when(() => mockAudioFormat.sampleRate).thenReturn(44100);
      when(() => mockAudioFormat.mimeType).thenReturn("audio/mp4");
      when(() => mockAudioFormat.fileExtension).thenReturn("m4a");

      service = VoiceTranscriptionService(
        mockVoiceApi,
        mockRecorder,
        mockFileProvider,
        mockWakeLockService,
        mockAudioFormat,
      );
    });

    tearDown(() async {
      await service.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group("startRecording", () {
      test("success: checks permission, starts recorder, enables wake lock, sets flags", () async {
        await service.startRecording();

        expect(service.isRecording, isTrue);
        expect(service.isBusy, isTrue);
        verify(mockRecorder.hasPermission).called(1);
        verify(() => mockFileProvider.createRecordingPath()).called(1);
        verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
        verify(mockWakeLockService.enable).called(1);
      });

      test("already busy: returns without new recorder call", () async {
        await service.startRecording();
        await service.startRecording();

        verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
      });

      test("permission denied: throws MicrophonePermissionDeniedError and resets busy", () async {
        when(mockRecorder.hasPermission).thenAnswer((_) async => false);

        await expectLater(service.startRecording, throwsA(isA<MicrophonePermissionDeniedError>()));

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
        verifyNever(mockWakeLockService.enable);
      });

      test("recorder.start fails: throws RecordingFailedError, cleans file, resets busy", () async {
        final file = File(recordingPath);
        await file.writeAsString("temp");

        when(() => mockRecorder.start(any(), path: any(named: "path"))).thenThrow(Exception("start failed"));

        await expectLater(service.startRecording, throwsA(isA<RecordingFailedError>()));

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
        expect(file.existsSync(), isFalse);
        verifyNever(mockWakeLockService.enable);
      });
    });

    group("stopAndTranscribe", () {
      Future<void> startWithRecordedFile() async {
        await service.startRecording();
        await File(recordingPath).writeAsBytes([1, 2, 3]);
      }

      test("success: stops recorder, transcribes, returns text, disables wake lock, resets busy", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) async => ApiResponse.success("hello world"));

        final result = await service.stopAndTranscribe();

        expect(result, "hello world");
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockRecorder.stop).called(1);
        verify(() => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4")).called(1);
        verify(mockWakeLockService.disable).called(1);
      });

      test("not recording: throws NotRecordingError", () async {
        await expectLater(service.stopAndTranscribe, throwsA(isA<NotRecordingError>()));
      });

      test("recorder.stop throws: throws RecordingFailedError, disables wake lock", () async {
        await service.startRecording();
        when(mockRecorder.stop).thenThrow(Exception("stop failed"));

        await expectLater(service.stopAndTranscribe, throwsA(isA<RecordingFailedError>()));

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("recorder.stop returns null: throws RecordingFailedError", () async {
        await service.startRecording();
        when(mockRecorder.stop).thenAnswer((_) async => null);

        await expectLater(service.stopAndTranscribe, throwsA(isA<RecordingFailedError>()));

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
      });

      test("API notAuthenticated error: throws NotAuthenticatedVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.notAuthenticated()));

        await expectLater(service.stopAndTranscribe, throwsA(isA<NotAuthenticatedVoiceError>()));
      });

      test("API nonSuccessCode error: throws ServerVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "down")));

        await expectLater(service.stopAndTranscribe, throwsA(isA<ServerVoiceError>()));
      });

      test("API dartHttpClient error: throws NetworkVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("network"))));

        await expectLater(service.stopAndTranscribe, throwsA(isA<NetworkVoiceError>()));
      });
    });

    group("cancelRecording", () {
      test("cancels active recording: stops recorder, disables wake lock, resets flags", () async {
        await service.startRecording();

        await service.cancelRecording();

        verify(mockRecorder.stop).called(1);
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("cancels during transcription: throws TranscriptionCancelledError when HTTP completes", () async {
        await service.startRecording();
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) => transcribeCompleter.future);

        final stopFuture = service.stopAndTranscribe();
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
        await service.startRecording();
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) => transcribeCompleter.future);

        final stopFuture = service.stopAndTranscribe();
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
        await service.startRecording();
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter1 = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) => transcribeCompleter1.future);

        final stopFuture1 = service.stopAndTranscribe();
        await Future<void>.delayed(Duration.zero);

        // Cancel transcription #1.
        await service.cancelRecording();

        // Start recording #2 immediately and begin transcription.
        await service.startRecording();
        await File(recordingPath).writeAsBytes([4, 5, 6]);

        final transcribeCompleter2 = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
        ).thenAnswer((_) => transcribeCompleter2.future);

        final stopFuture2 = service.stopAndTranscribe();
        await Future<void>.delayed(Duration.zero);

        // Transcription #1 returns — must be discarded despite #2 resetting state.
        transcribeCompleter1.complete(ApiResponse.success("stale transcript"));
        await expectLater(stopFuture1, throwsA(isA<TranscriptionCancelledError>()));

        // Transcription #2 returns — should succeed normally.
        transcribeCompleter2.complete(ApiResponse.success("fresh transcript"));
        final result = await stopFuture2;
        expect(result, "fresh transcript");
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
        final startFuture = service.startRecording();
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
          service.startRecording();
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
          service.startRecording();
          async.flushMicrotasks();

          File(recordingPath).writeAsBytesSync([1, 2, 3]);
          when(
            () => mockVoiceApi.transcribe(recordingPath, mimeType: "audio/mp4"),
          ).thenAnswer((_) async => ApiResponse.success("text"));

          bool eventReceived = false;
          service.onMaxDurationReached.listen((_) => eventReceived = true);

          async.elapse(const Duration(minutes: 7));
          service.stopAndTranscribe();
          async.flushMicrotasks();

          // Past the original limit — timer was cancelled by stopAndTranscribe.
          async.elapse(const Duration(minutes: 10));
          expect(eventReceived, isFalse);
        });
      });

      test("does not emit if cancelRecording is called before limit", () {
        fakeAsync((async) {
          service.startRecording();
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

        await service.startRecording();
        amplitudeController.add(Amplitude(current: -30.0, max: 0.0));
        amplitudeController.add(Amplitude(current: 0.0, max: 0.0));
        await Future<void>.delayed(Duration.zero);

        expect(emitted[0], closeTo(0.5, 0.01));
        expect(emitted[1], 1.0);
      });

      test("emits 0.0 when monitoring stops", () async {
        final zeroEmission = expectLater(service.amplitudeStream, emits(0.0));

        await service.startRecording();
        await service.cancelRecording();

        await zeroEmission;
      });
    });
  });
}
