import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:fake_async/fake_async.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../../helpers/test_helpers.dart";

class _TokenProvider() extends Mock implements AuthTokenProvider {
  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    return "fresh-token";
  }
}

class _RealtimeConnector() implements RealtimeWebSocketConnector {
  final channel = _RealtimeChannel();
  Map<String, String>? headers;
  Exception? openError;
  Completer<void>? connectGate;
  Completer<void>? connectStarted;

  @override
  Future<WebSocketChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration connectTimeout,
  }) async {
    this.headers = headers;
    final started = connectStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    final gate = connectGate;
    if (gate != null) {
      await gate.future;
    }
    final error = openError;
    if (error != null) throw error;
    return channel;
  }
}

class _StreamBoom(final Object original) implements Exception;

class _RealtimeChannel() extends Mock implements WebSocketChannel {
  final inbound = StreamController<String>();
  final outbound = <Object>[];
  final _sinkDone = Completer<void>();
  int? _closeCode;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  // ignore: prefer_specific_type -- WebSocketChannel exposes Stream<dynamic>.
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _RealtimeSink(outbound, _sinkDone, (code) => _closeCode = code);
}

class _RealtimeSink(
  final List<Object> outbound,
  final Completer<void> doneCompleter,
  final void Function(int? code) setCloseCode,
) implements WebSocketSink {
  @override
  Future<void> get done => doneCompleter.future;

  @override
  void add(Object? event) {
    if (event != null) {
      outbound.add(event);
    }
  }

  @override
  // ignore: prefer_specific_type -- WebSocketSink requires Object here.
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  // ignore: prefer_specific_type -- WebSocketSink requires Stream<dynamic>.
  Future<void> addStream(Stream<dynamic> stream) async => await stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    setCloseCode(closeCode);
    if (!doneCompleter.isCompleted) doneCompleter.complete();
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  group("VoiceTranscriptionService", () {
    late MockVoiceApi mockVoiceApi;
    late MockRealtimeVoiceApi mockRealtimeVoiceApi;
    late MockAudioRecorder mockRecorder;
    late MockRecorderPrewarmClient mockRecorderPrewarmClient;
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
      mockRealtimeVoiceApi = MockRealtimeVoiceApi();
      mockRecorder = MockAudioRecorder();
      mockRecorderPrewarmClient = MockRecorderPrewarmClient();
      mockFileProvider = MockRecordingFileProvider();
      mockWakeLockService = MockWakeLockService();
      mockAudioFormat = MockAudioFormatConfig();

      when(mockRecorder.hasPermission).thenAnswer((_) async => true);
      when(() => mockRecorder.hasPermission(request: false)).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: "path"))).thenAnswer((_) async {});
      when(mockRecorder.stop).thenAnswer((_) async => recordingPath);
      when(mockRecorder.cancel).thenAnswer((_) async {});
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
      when(() => mockAudioFormat.realtimeRecorder)
          .thenReturn(AudioFormatConfig.forPlatform(isWeb: false).realtimeRecorder);
      when(mockVoiceApi.discoverCapabilities).thenAnswer((_) async => const VoiceCapabilitiesAsyncFallback());

      service = VoiceTranscriptionService(
        voiceApi: mockVoiceApi,
        realtimeVoiceApi: mockRealtimeVoiceApi,
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

      test("returns without touching recorder after dispose", () async {
        await service.dispose();

        await service.prewarmRecording();

        verifyNever(() => mockRecorder.hasPermission(request: false));
        verifyNever(
          () => mockRecorderPrewarmClient.prewarm(
            sampleRate: any(named: "sampleRate"),
            bitRate: any(named: "bitRate"),
            numChannels: any(named: "numChannels"),
          ),
        );
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
        final startFuture = service.startRecording(projectId: "project-123");
        final startError = Completer<Object>();
        unawaited(
          startFuture.catchError((Object error) {
            if (!startError.isCompleted) startError.complete(error);
          }),
        );
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
                .startRecording(projectId: "project-123")
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
            unawaited(service.startRecording(projectId: "project-123"));
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
        await service.startRecording(projectId: "project-123");

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
      });

      test("already busy: returns without new recorder call", () async {
        await service.startRecording(projectId: "project-123");
        await service.startRecording(projectId: "project-123");

        verify(() => mockRecorder.start(any(), path: recordingPath)).called(1);
      });

      test("permission denied: throws MicrophonePermissionDeniedError and resets busy", () async {
        when(mockRecorder.hasPermission).thenAnswer((_) async => false);

        await expectLater(
          () => service.startRecording(projectId: "project-123"),
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

        await expectLater(
          () => service.startRecording(projectId: "project-123"),
          throwsA(isA<RecordingFailedError>()),
        );

        expect(service.isBusy, isFalse);
        expect(service.isRecording, isFalse);
        expect(file.existsSync(), isFalse);
        verifyNever(mockWakeLockService.enable);
      });

      test("cancel after native async start rethrows cancelled and cleans file", () async {
        final nativeStarted = Completer<void>();
        final allowStartReturn = Completer<void>();
        final file = File(recordingPath);
        await file.writeAsString("temp");
        when(() => mockRecorder.start(any(), path: recordingPath)).thenAnswer((_) async {
          nativeStarted.complete();
          await allowStartReturn.future;
        });

        final startFuture = service.startRecording(projectId: "project-123");
        await nativeStarted.future;

        await service.cancelRecording();
        allowStartReturn.complete();

        await expectLater(startFuture, throwsA(isA<TranscriptionCancelledError>()));
        expect(file.existsSync(), isFalse);
        verify(mockRecorder.cancel).called(1);
        verifyNever(mockWakeLockService.enable);
      });

      test("dispose during gated async recorder start cancels before recorder dispose", () async {
        final nativeStartCalled = Completer<void>();
        final nativeStart = Completer<void>();
        final file = File(recordingPath);
        await file.writeAsString("temp");
        when(() => mockRecorder.start(any(), path: recordingPath)).thenAnswer((_) {
          if (!nativeStartCalled.isCompleted) nativeStartCalled.complete();
          return nativeStart.future;
        });

        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        await nativeStartCalled.future;
        final startExpectation = expectLater(startFuture, throwsA(isA<TranscriptionCancelledError>()));

        final disposeFuture = service.dispose();
        await Future<void>.delayed(Duration.zero);
        verifyNever(mockRecorder.dispose);

        nativeStart.complete();

        await startExpectation;
        await disposeFuture;
        expect(file.existsSync(), isFalse);
        verifyInOrder([mockRecorder.cancel, mockRecorder.dispose]);
      });

      test("dispose during capability discovery invalidates setup and later start fails", () async {
        final capabilities = Completer<VoiceCapabilitiesDiscoveryResult>();
        when(mockVoiceApi.discoverCapabilities).thenAnswer((_) => capabilities.future);

        final startFuture = service.startRecording(projectId: "project-123");
        final startError = Completer<Object>();
        unawaited(
          startFuture.catchError((Object error) {
            if (!startError.isCompleted) startError.complete(error);
          }),
        );
        await Future<void>.delayed(Duration.zero);
        final startExpectation = expectLater(startFuture, throwsA(isA<TranscriptionCancelledError>()));
        await service.dispose();
        capabilities.complete(const VoiceCapabilitiesAsyncFallback());

        await startExpectation;
        await expectLater(
          () => service.startRecording(projectId: "project-123"),
          throwsA(isA<TranscriptionCancelledError>()),
        );
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
      });
    });

    group("stopAndTranscribe", () {
      Future<void> startWithRecordedFile() async {
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([1, 2, 3]);
      }

      test("success: stops recorder, transcribes, returns text, disables wake lock, resets busy", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.success("hello world"));

        final result = await service.stopAndTranscribe();

        expect(result, "hello world");
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockRecorder.stop).called(1);
        verify(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).called(1);
        verify(mockWakeLockService.disable).called(1);
      });

      test("not recording: throws NotRecordingError", () async {
        await expectLater(service.stopAndTranscribe, throwsA(isA<NotRecordingError>()));
      });

      test("recorder.stop throws: throws RecordingFailedError, disables wake lock", () async {
        await service.startRecording(projectId: "project-123");
        when(mockRecorder.stop).thenThrow(Exception("stop failed"));

        await expectLater(service.stopAndTranscribe, throwsA(isA<RecordingFailedError>()));

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("recorder.stop returns null: throws RecordingFailedError", () async {
        await service.startRecording(projectId: "project-123");
        when(mockRecorder.stop).thenAnswer((_) async => null);

        await expectLater(service.stopAndTranscribe, throwsA(isA<RecordingFailedError>()));

        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
      });

      test("API notAuthenticated error: throws NotAuthenticatedVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.notAuthenticated()));

        await expectLater(service.stopAndTranscribe, throwsA(isA<NotAuthenticatedVoiceError>()));
      });

      test("API nonSuccessCode error: throws ServerVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "down")));

        await expectLater(service.stopAndTranscribe, throwsA(isA<ServerVoiceError>()));
      });

      test("API dartHttpClient error: throws NetworkVoiceError", () async {
        await startWithRecordedFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("network"))));

        await expectLater(service.stopAndTranscribe, throwsA(isA<NetworkVoiceError>()));
      });
    });

    group("capability selection", () {
      Future<void> startWithFile() async {
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([1, 2, 3]);
      }

      test("old or missing capabilities preserve legacy async upload without projectKey", () async {
        await startWithFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.success("legacy"));

        expect(await service.stopAndTranscribe(), "legacy");

        verify(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).called(1);
      });

      test("disabled protocol 1 uses async upload with opaque projectKey", () async {
        const capabilities = VoiceCapabilities(realtimeEnabled: false, protocolVersions: [1]);
        when(mockVoiceApi.discoverCapabilities)
            .thenAnswer((_) async => const VoiceCapabilitiesAvailable(capabilities: capabilities));
        await startWithFile();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: deriveProjectGlossaryKey("project-123"),
            capabilities: capabilities,
          ),
        ).thenAnswer((_) async => ApiResponse.success("scoped"));

        expect(await service.stopAndTranscribe(), "scoped");

        verify(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: deriveProjectGlossaryKey("project-123"),
            capabilities: capabilities,
          ),
        ).called(1);
      });

      test("malformed capability contract fails before capture", () async {
        when(
          mockVoiceApi.discoverCapabilities,
        ).thenAnswer((_) async => const VoiceCapabilitiesContractFailure(reason: "bad shape"));

        await expectLater(
          () => service.startRecording(projectId: "project-123"),
          throwsA(isA<ContractVoiceError>()),
        );

        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
      });
    });

    group("realtime", () {
      late StreamController<Uint8List> audioFrames;
      late _RealtimeConnector connector;
      void Function(RecordConfig)? configChanged;

      setUp(() {
        audioFrames = StreamController<Uint8List>();
        addTearDown(audioFrames.close);
        connector = _RealtimeConnector();
        service = VoiceTranscriptionService(
          voiceApi: mockVoiceApi,
          realtimeVoiceApi: RealtimeVoiceApi(connector: connector, tokenProvider: _TokenProvider()),
          recorder: mockRecorder,
          recorderPrewarmClient: mockRecorderPrewarmClient,
          fileProvider: mockFileProvider,
          wakeLockService: mockWakeLockService,
          audioFormat: mockAudioFormat,
        );
        when(mockVoiceApi.discoverCapabilities).thenAnswer(
          (_) async => const VoiceCapabilitiesAvailable(
            capabilities: VoiceCapabilities(realtimeEnabled: true, protocolVersions: [1]),
          ),
        );
        when(() => mockRecorder.setOnConfigChanged(any())).thenAnswer((invocation) async {
          configChanged = invocation.positionalArguments.single as void Function(RecordConfig)?;
        });
        when(() => mockRecorder.startStream(any())).thenAnswer((_) async => audioFrames.stream);
        when(mockRecorder.pause).thenAnswer((_) async {});
        when(mockRecorder.resume).thenAnswer((_) async {});
        when(mockRecorder.stop).thenAnswer((_) async => null);
      });

      test("starts paused, waits for pause before realtime start, then forwards PCM after ready", () async {
        final pauseStarted = Completer<void>();
        final pauseCompleter = Completer<void>();
        connector.connectStarted = Completer<void>();
        when(() => mockRecorder.startStream(any())).thenAnswer((_) async {
          configChanged?.call(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 48000, numChannels: 1));
          return audioFrames.stream;
        });
        when(mockRecorder.pause).thenAnswer((_) {
          if (!pauseStarted.isCompleted) pauseStarted.complete();
          return pauseCompleter.future;
        });

        final startFuture = service.startRecording(projectId: "project-123");
        await pauseStarted.future;
        audioFrames.add(Uint8List.fromList([1, 2]));
        await Future<void>.delayed(Duration.zero);

        expect(connector.connectStarted?.isCompleted, isFalse);
        expect(connector.headers, isNull);
        expect(connector.channel.outbound, isEmpty);

        pauseCompleter.complete();
        await connector.connectStarted?.future;
        await Future<void>.delayed(Duration.zero);

        final startPayload = connector.channel.outbound.single;
        if (startPayload is! String) {
          fail("expected realtime start payload");
        }
        final decodedStart = jsonDecode(startPayload);
        if (decodedStart is! Map<String, Object?>) {
          fail("expected realtime start map");
        }
        final start = decodedStart;
        expect(start["projectKey"], deriveProjectGlossaryKey("project-123"));
        expect(start["audio"], {"encoding": "pcm_s16le", "sampleRate": 48000, "channels": 1});
        expect(start.toString(), isNot(contains("project-123")));
        expect(connector.headers, {"Authorization": "Bearer fresh-token"});

        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        audioFrames.add(Uint8List.fromList([3, 4]));
        await Future<void>.delayed(Duration.zero);

        expect(connector.channel.outbound.whereType<Uint8List>().single, [3, 4]);
        verifyInOrder([
          () => mockRecorder.setOnConfigChanged(any()),
          () => mockRecorder.startStream(any()),
          mockRecorder.pause,
          mockRecorder.resume,
        ]);
      });

      test("appends confirmed preview, replaces provisional, and completes with confirmed text only", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;

        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "hello ", "provisional": "wor"}),
        );
        connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "world", "provisional": ""}));
        await Future<void>.delayed(Duration.zero);

        final stopFuture = service.stopAndTranscribe();
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}),
        );

        expect(service.currentPreview.confirmedText, "hello world");
        expect(service.currentPreview.provisionalText, "");
        expect(await stopFuture, "hello world");
        verifyNever(
          () => mockVoiceApi.transcribe(
            any(),
            mimeType: any(named: "mimeType"),
            projectKey: any(named: "projectKey"),
            capabilities: any(named: "capabilities"),
          ),
        );
      });

      test("post-audio transport close returns confirmed partial and never uploads", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "partial", "provisional": ""}),
        );
        audioFrames.add(Uint8List.fromList([1, 2]));
        await Future<void>.delayed(Duration.zero);
        await connector.channel.inbound.close();

        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error.confirmedText, "confirmed", "partial")
                .having((error) => error.failure, "failure", isA<RealtimeTransportVoiceError>()),
          ),
        );
        verifyNever(
          () => mockVoiceApi.transcribe(
            any(),
            mimeType: any(named: "mimeType"),
            projectKey: any(named: "projectKey"),
            capabilities: any(named: "capabilities"),
          ),
        );
      });

      test("recorder stop failure on release keeps the confirmed transcript", () async {
        // Confirmed text was already accepted from the provider, so a recorder
        // that fails to stop must not discard transcribed speech behind a bare
        // recordingFailed().
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "kept words", "provisional": ""}),
        );
        audioFrames.add(Uint8List.fromList([1, 2]));
        await Future<void>.delayed(Duration.zero);

        when(mockRecorder.stop).thenThrow(Exception("stop failed"));

        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>().having(
              (error) => error.confirmedText,
              "confirmed",
              "kept words",
            ),
          ),
        );
      });

      test("terminal complete during startup after ready does not mark a stopped recorder active", () async {
        // Terminal cleanup stops the recorder for a completion just as it does
        // for a failure, so startup must not go on to mark the interaction as
        // recording. This is the non-failure half of the same window.
        final resumeGate = Completer<void>();
        when(mockRecorder.resume).thenAnswer((_) => resumeGate.future);

        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await Future<void>.delayed(Duration.zero);

        connector.channel.inbound.add(
          jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}),
        );
        await Future<void>.delayed(Duration.zero);

        resumeGate.complete();
        await startFuture;

        expect(service.isRecording, isFalse);
        verifyNever(mockWakeLockService.enable);
      });

      test("stream error during startup after ready aborts instead of marking a stopped recorder active", () async {
        // Terminating capture on a post-ready stream error stops the recorder.
        // If startup is still awaiting at that moment it must not go on to mark
        // the interaction as recording, or the composer stays live with no
        // recorder behind it.
        final resumeGate = Completer<void>();
        when(mockRecorder.resume).thenAnswer((_) => resumeGate.future);

        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await Future<void>.delayed(Duration.zero);

        audioFrames.addError(Exception("native stream failed"));
        await Future<void>.delayed(Duration.zero);

        resumeGate.complete();
        await expectLater(startFuture, throwsA(isA<VoiceTranscriptionError>()));

        expect(service.isRecording, isFalse);
        verifyNever(mockWakeLockService.enable);
      });

      test("post-ready stream error before the first frame terminates instead of stranding capture", () async {
        // The stream can fail after setup returns but before any audio frame is
        // forwarded. The pre-audio completer has no listener left by then and
        // the ready completer is already settled, so this must terminate rather
        // than record a fallback nothing will ever observe. It must also not
        // start the async file path: the realtime session is already open.
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;

        audioFrames.addError(Exception("native stream failed"));
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        verifyNever(() => mockRecorder.start(any(), path: recordingPath));
        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>().having(
              (error) => error.failure,
              "failure",
              isA<RealtimeTransportVoiceError>(),
            ),
          ),
        );
      });

      test("post-audio stream error stops capture immediately and returns partial", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "kept", "provisional": ""}),
        );
        audioFrames.add(Uint8List.fromList([1, 2]));
        audioFrames.addError(Exception("native stream failed"));
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error.confirmedText, "confirmed", "kept")
                .having((error) => error.failure, "failure", isA<RealtimeTransportVoiceError>()),
          ),
        );
        verifyNever(
          () => mockVoiceApi.transcribe(
            any(),
            mimeType: any(named: "mimeType"),
            projectKey: any(named: "projectKey"),
            capabilities: any(named: "capabilities"),
          ),
        );
      });

      test("unexpected done after ready stops once and returns partial", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "partial", "provisional": ""}),
        );

        await connector.channel.inbound.close();
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error.confirmedText, "confirmed", "partial")
                .having((error) => error.failure, "failure", isA<RealtimeTransportVoiceError>()),
          ),
        );
      });

      test("late unsupported config adjustment returns confirmed partial contract failure", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(
          jsonEncode({"type": "transcript", "confirmedDelta": "kept", "provisional": "drop"}),
        );
        audioFrames.add(Uint8List.fromList([1, 2]));
        await Future<void>.delayed(Duration.zero);
        configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));

        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error.confirmedText, "confirmed", "kept")
                .having((error) => error.failure, "failure", isA<RealtimeContractVoiceError>()),
          ),
        );
        verifyNever(
          () => mockVoiceApi.transcribe(
            any(),
            mimeType: any(named: "mimeType"),
            projectKey: any(named: "projectKey"),
            capabilities: any(named: "capabilities"),
          ),
        );
      });

      test("cancel during ready wait stops native stream and prevents fallback resurrection", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        final startExpectation = expectLater(startFuture, throwsA(isA<TranscriptionCancelledError>()));

        await service.cancelRecording();

        await startExpectation;
        expect(service.isBusy, isFalse);
        verify(mockRecorder.cancel).called(1);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
      });

      test("pre-audio open fallback cancels native stream before async file recording", () async {
        connector.openError = const RealtimeVoiceOpenHandshakeNotFoundException(cause: null, httpStatus: 404);
        await service.startRecording(projectId: "project-123");

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
      });

      test("401 open failure does not fallback", () async {
        final authCause = Exception("expired token");
        connector.openError = RealtimeVoiceOpenAuthenticationException(cause: authCause, httpStatus: 401);

        await expectLater(
          () => service.startRecording(projectId: "project-123"),
          throwsA(
            isA<NotAuthenticatedVoiceError>().having(
              (error) => error.cause,
              "cause",
              isA<RealtimeVoiceOpenAuthenticationException>().having(
                (cause) => cause.cause,
                "inner cause",
                same(authCause),
              ),
            ),
          ),
        );
        verify(mockRecorder.cancel).called(1);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
      });

      test("generic pre-ready websocket error preserves cause and falls back immediately", () async {
        final streamError = _StreamBoom(Object());
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);

        connector.channel.inbound.addError(streamError);
        await startFuture;

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
        verifyNever(mockRecorder.stop);
      });

      test("pre-ready native audio error falls back before websocket open finishes", () async {
        connector.connectGate = Completer<void>();
        final streamError = _StreamBoom(Object());
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);

        audioFrames.addError(streamError);
        await Future<void>.delayed(Duration.zero);
        connector.connectGate?.complete();
        await startFuture;

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
        verifyNever(mockRecorder.stop);
      });

      test("pre-ready native error while connector is gated closes late session before async start", () async {
        connector.connectGate = Completer<void>();
        final streamError = _StreamBoom(Object());
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);

        audioFrames.addError(streamError);
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockRecorder.start(any(), path: recordingPath));

        connector.connectGate?.complete();
        await startFuture;

        final outboundTypes = connector.channel.outbound
            .whereType<String>()
            .map((payload) => (jsonDecode(payload) as Map<String, Object?>)["type"])
            .toList();
        expect(outboundTypes, contains("cancel"));
        expect(connector.channel.closeCode, realtimeNormalCloseCode);
        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
      });

      test("pre-ready native error while pause is gated waits for pause before async start", () async {
        final pauseCompleter = Completer<void>();
        when(mockRecorder.pause).thenAnswer((_) => pauseCompleter.future);
        final streamError = _StreamBoom(Object());

        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);

        audioFrames.addError(streamError);
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockRecorder.start(any(), path: recordingPath));

        pauseCompleter.complete();
        await startFuture;

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.pause,
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
        verifyNever(mockRecorder.resume);
      });

      test("pre-ready socket done falls back to async stop without partial realtime state", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);

        await connector.channel.inbound.close();
        await startFuture;
        await File(recordingPath).writeAsBytes([1, 2, 3]);
        when(mockRecorder.stop).thenAnswer((_) async => recordingPath);
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: deriveProjectGlossaryKey("project-123"),
            capabilities: const VoiceCapabilities(realtimeEnabled: true, protocolVersions: [1]),
          ),
        ).thenAnswer((_) async => ApiResponse.success("fallback transcript"));

        expect(await service.stopAndTranscribe(), "fallback transcript");
        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
          mockRecorder.stop,
        ]);
      });

      test("pre-ready server error is typed and never falls back", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "error", "code": "unsupported_protocol", "retryable": false}),
        );

        await expectLater(startFuture, throwsA(isA<RealtimeServerVoiceError>()));
        verify(mockRecorder.stop).called(1);
        verifyNever(() => mockRecorder.start(any(), path: any(named: "path")));
      });

      test("dispose during ready wait cancels setup and prevents resume resurrection", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        final startExpectation = expectLater(startFuture, throwsA(isA<TranscriptionCancelledError>()));

        await service.dispose();
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );

        await startExpectation;
        verify(mockRecorder.cancel).called(1);
        verifyNever(mockRecorder.resume);
        verifyNever(() => mockRecorder.start(any(), path: recordingPath));
      });

      test("initial unsupported effective config falls back after native cleanup", () async {
        when(() => mockRecorder.startStream(any())).thenAnswer((_) async {
          configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));
          return audioFrames.stream;
        });

        await service.startRecording(projectId: "project-123");

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
      });

      test("config drift while connector open is gated waits for late session cleanup before async start", () async {
        var asyncStarts = 0;
        when(() => mockRecorder.start(any(), path: recordingPath)).thenAnswer((_) async {
          asyncStarts++;
        });
        connector.connectGate = Completer<void>();
        connector.connectStarted = Completer<void>();
        final startFuture = service.startRecording(projectId: "project-123");
        await connector.connectStarted?.future;

        configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));
        await Future<void>.delayed(Duration.zero);
        expect(asyncStarts, 0);

        connector.connectGate?.complete();
        await startFuture;

        final outboundTypes = connector.channel.outbound
            .whereType<String>()
            .map((payload) => (jsonDecode(payload) as Map<String, Object?>)["type"])
            .toList();
        expect(outboundTypes, contains("cancel"));
        expect(connector.channel.closeCode, realtimeNormalCloseCode);
        verifyInOrder([
          () => mockRecorder.hasPermission(request: true),
          () => mockRecorder.setOnConfigChanged(any()),
          () => mockRecorder.startStream(any()),
          mockRecorder.pause,
          () => mockRecorder.setOnConfigChanged(null),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
          () => mockRecorder.onAmplitudeChanged(any()),
        ]);
      });

      test("config drift while resume is gated waits before realtime cancel and async start", () async {
        var asyncStarts = 0;
        when(() => mockRecorder.start(any(), path: recordingPath)).thenAnswer((_) async {
          asyncStarts++;
        });
        final resumeCompleter = Completer<void>();
        when(mockRecorder.resume).thenAnswer((_) => resumeCompleter.future);
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await Future<void>.delayed(Duration.zero);

        configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));
        await Future<void>.delayed(Duration.zero);
        expect(asyncStarts, 0);

        resumeCompleter.complete();
        await startFuture;
        audioFrames.add(Uint8List.fromList([9, 10]));
        await Future<void>.delayed(Duration.zero);

        expect(connector.channel.outbound.whereType<Uint8List>(), isEmpty);
        verifyInOrder([
          () => mockRecorder.hasPermission(request: true),
          () => mockRecorder.setOnConfigChanged(any()),
          () => mockRecorder.startStream(any()),
          mockRecorder.pause,
          mockRecorder.resume,
          () => mockRecorder.setOnConfigChanged(null),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
          () => mockRecorder.onAmplitudeChanged(any()),
        ]);
      });

      test("pre-first-frame config drift after ready transitions to async capture", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;

        configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verifyInOrder([
          () => mockRecorder.startStream(any()),
          mockRecorder.cancel,
          () => mockRecorder.start(any(), path: recordingPath),
        ]);
        verifyNever(mockRecorder.stop);
      });

      test("pre-first-frame config drift after cancel does not start async capture", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;

        await service.cancelRecording();
        configChanged?.call(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1));
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockRecorder.start(any(), path: recordingPath));
      });

      test("supported adjusted config is announced in realtime start", () async {
        when(() => mockRecorder.startStream(any())).thenAnswer((_) async {
          configChanged?.call(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 48000, numChannels: 1));
          return audioFrames.stream;
        });
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;

        final startPayload = connector.channel.outbound.first;
        if (startPayload is! String) {
          fail("expected realtime start payload");
        }
        final decodedStart = jsonDecode(startPayload);
        if (decodedStart is! Map<String, Object?>) {
          fail("expected realtime start map");
        }
        final start = decodedStart;
        expect(start["audio"], {"encoding": "pcm_s16le", "sampleRate": 48000, "channels": 1});
      });

      test("server error after audio stops capture immediately and returns partial hierarchy", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "kept", "provisional": ""}));
        audioFrames.add(Uint8List.fromList([1, 2]));
        connector.channel.inbound.add(jsonEncode({"type": "error", "code": "provider_timeout", "retryable": true}));
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error, "hierarchy", isA<VoiceTranscriptionError>())
                .having((error) => error.confirmedText, "confirmed", "kept")
                .having((error) => error.retryable, "retryable", isTrue),
          ),
        );
      });

      test("concurrent server and audio failures stop native capture once", () async {
        final stopCompleter = Completer<String?>();
        when(mockRecorder.stop).thenAnswer((_) => stopCompleter.future);
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        audioFrames.add(Uint8List.fromList([1, 2]));

        connector.channel.inbound.add(jsonEncode({"type": "error", "code": "provider_timeout", "retryable": true}));
        audioFrames.addError(Exception("native stream failed"));
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        stopCompleter.complete(null);
        await Future<void>.delayed(Duration.zero);
        await expectLater(service.stopAndTranscribe(), throwsA(isA<VoiceRealtimePartialTranscriptionError>()));
      });

      test("complete before release returns confirmed text without double recorder stop", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "done", "provisional": ""}));
        connector.channel.inbound.add(
          jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}),
        );
        await Future<void>.delayed(Duration.zero);

        expect(await service.stopAndTranscribe(), "done");
        verify(mockRecorder.stop).called(1);
      });

      test("complete immediately before release waits for terminal recorder cleanup", () async {
        final terminalStop = Completer<String?>();
        when(mockRecorder.stop).thenAnswer((_) => terminalStop.future);
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "done", "provisional": ""}));
        connector.channel.inbound.add(
          jsonEncode({"type": "complete", "reason": "finished", "dailySecondsRemaining": 99}),
        );
        await Future<void>.delayed(Duration.zero);

        verify(mockRecorder.stop).called(1);
        var settled = false;
        final stopFuture = service.stopAndTranscribe().then((transcript) {
          settled = true;
          return transcript;
        });
        await Future<void>.delayed(Duration.zero);

        expect(settled, isFalse);
        expect(service.isBusy, isTrue);

        terminalStop.complete(null);

        expect(await stopFuture, "done");
        expect(settled, isTrue);
      });

      test("error immediately before release returns typed partial", () async {
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(jsonEncode({"type": "transcript", "confirmedDelta": "kept", "provisional": ""}));
        connector.channel.inbound.add(jsonEncode({"type": "error", "code": "provider_timeout", "retryable": true}));

        await expectLater(
          service.stopAndTranscribe(),
          throwsA(
            isA<VoiceRealtimePartialTranscriptionError>()
                .having((error) => error.confirmedText, "confirmed", "kept")
                .having((error) => error.failure, "failure", isA<RealtimeServerVoiceError>()),
          ),
        );
      });

      test("terminal failure cleanup gates async restart until stale stop cannot mutate it", () async {
        var stopCalls = 0;
        final terminalStop = Completer<String?>();
        when(mockRecorder.stop).thenAnswer((_) {
          stopCalls++;
          if (stopCalls == 1) return terminalStop.future;
          return Future<String?>.value(recordingPath);
        });
        final startFuture = service.startRecording(projectId: "project-123");
        await Future<void>.delayed(Duration.zero);
        connector.channel.inbound.add(
          jsonEncode({"type": "ready", "protocolVersion": 1, "maxSessionSeconds": 900, "dailySecondsRemaining": 100}),
        );
        await startFuture;
        connector.channel.inbound.add(jsonEncode({"type": "error", "code": "provider_timeout", "retryable": true}));
        await Future<void>.delayed(Duration.zero);

        when(mockVoiceApi.discoverCapabilities).thenAnswer((_) async => const VoiceCapabilitiesAsyncFallback());
        var partialSettled = false;
        final partialExpectation = expectLater(
          service.stopAndTranscribe().whenComplete(() => partialSettled = true),
          throwsA(isA<VoiceRealtimePartialTranscriptionError>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(partialSettled, isFalse);
        expect(service.isBusy, isTrue);
        await service.startRecording(projectId: "project-123");
        verifyNever(() => mockRecorder.start(any(), path: recordingPath));

        terminalStop.complete(null);
        await partialExpectation;

        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) async => ApiResponse.success("fresh"));
        await service.startRecording(projectId: "project-123");
        expect(service.isRecording, isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(service.isRecording, isTrue);
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        expect(await service.stopAndTranscribe(), "fresh");
      });
    });

    group("cancelRecording", () {
      test("cancels active recording: stops recorder, disables wake lock, resets flags", () async {
        await service.startRecording(projectId: "project-123");

        await service.cancelRecording();

        verify(mockRecorder.stop).called(1);
        expect(service.isRecording, isFalse);
        expect(service.isBusy, isFalse);
        verify(mockWakeLockService.disable).called(1);
      });

      test("cancels during transcription: throws TranscriptionCancelledError when HTTP completes", () async {
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
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
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
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
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([1, 2, 3]);

        final transcribeCompleter1 = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
        ).thenAnswer((_) => transcribeCompleter1.future);

        final stopFuture1 = service.stopAndTranscribe();
        await Future<void>.delayed(Duration.zero);

        // Cancel transcription #1.
        await service.cancelRecording();

        // Start recording #2 immediately and begin transcription.
        await service.startRecording(projectId: "project-123");
        await File(recordingPath).writeAsBytes([4, 5, 6]);

        final transcribeCompleter2 = Completer<ApiResponse<String>>();
        when(
          () => mockVoiceApi.transcribe(
            recordingPath,
            mimeType: "audio/mp4",
            projectKey: null,
            capabilities: null,
          ),
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
        final startFuture = service.startRecording(projectId: "project-123");
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
          service.startRecording(projectId: "project-123");
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
          service.startRecording(projectId: "project-123");
          async.flushMicrotasks();

          File(recordingPath).writeAsBytesSync([1, 2, 3]);
          when(
            () => mockVoiceApi.transcribe(
              recordingPath,
              mimeType: "audio/mp4",
              projectKey: null,
              capabilities: null,
            ),
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
          service.startRecording(projectId: "project-123");
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

        await service.startRecording(projectId: "project-123");
        amplitudeController.add(Amplitude(current: -30.0, max: 0.0));
        amplitudeController.add(Amplitude(current: 0.0, max: 0.0));
        await Future<void>.delayed(Duration.zero);

        expect(emitted[0], closeTo(0.5, 0.01));
        expect(emitted[1], 1.0);
      });

      test("emits 0.0 when monitoring stops", () async {
        final zeroEmission = expectLater(service.amplitudeStream, emits(0.0));

        await service.startRecording(projectId: "project-123");
        await service.cancelRecording();

        await zeroEmission;
      });
    });
  });
}
