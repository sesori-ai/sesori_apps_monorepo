import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:sesori_app_ui/src/platform/voice/audio_format_config.dart";
import "package:sesori_app_ui/src/platform/voice/flutter_voice_capture.dart";
import "package:sesori_app_ui/src/platform/voice/recording_file_provider.dart";
import "package:sesori_app_ui/src/platform/voice/wake_lock_service.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class MockAudioRecorder() extends Mock implements AudioRecorder;

/// Stands in for the shell's native prewarm channel behind [RecorderPrewarm].
abstract interface class _RecorderPrewarmTarget() {
  Future<void> prewarm({required int sampleRate, required int bitRate, required int numChannels});
}

class MockRecorderPrewarm() extends Mock implements _RecorderPrewarmTarget;

class MockRecordingFileProvider() extends Mock implements RecordingFileProvider;

class MockWakeLockService() extends Mock implements WakeLockService;

class MockWakeLockLease() extends Mock implements WakeLockLease;

void main() {
  late MockAudioRecorder recorder;
  late MockRecorderPrewarm prewarmClient;
  late MockRecordingFileProvider fileProvider;
  late MockWakeLockService wakeLockService;
  late MockWakeLockLease wakeLockLease;
  late AudioFormatConfig audioFormat;
  late FlutterVoiceCapture capture;
  late Directory tempDirectory;
  late String recordingPath;
  late StreamController<Amplitude> amplitudeController;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(AudioEncoder.pcm16bits);
  });

  setUp(() async {
    recorder = MockAudioRecorder();
    prewarmClient = MockRecorderPrewarm();
    fileProvider = MockRecordingFileProvider();
    wakeLockService = MockWakeLockService();
    wakeLockLease = MockWakeLockLease();
    audioFormat = AudioFormatConfig.forPlatform(isWeb: false);
    tempDirectory = await Directory.systemTemp.createTemp("flutter_voice_capture_test_");
    recordingPath = "${tempDirectory.path}/voice.m4a";
    amplitudeController = StreamController<Amplitude>.broadcast();

    when(() => recorder.hasPermission(request: false)).thenAnswer((_) async => true);
    when(recorder.hasPermission).thenAnswer((_) async => true);
    when(() => recorder.start(any(), path: any(named: "path"))).thenAnswer((_) async {});
    when(recorder.stop).thenAnswer((_) async => recordingPath);
    when(() => recorder.onAmplitudeChanged(any())).thenAnswer((_) => amplitudeController.stream);
    when(recorder.dispose).thenAnswer((_) async {});
    when(() => fileProvider.createRecordingPath()).thenAnswer((_) async => recordingPath);
    when(
      () => prewarmClient.prewarm(
        sampleRate: any(named: "sampleRate"),
        bitRate: any(named: "bitRate"),
        numChannels: any(named: "numChannels"),
      ),
    ).thenAnswer((_) async {});
    when(wakeLockService.acquire).thenReturn(wakeLockLease);
    when(wakeLockLease.release).thenAnswer((_) async {});

    capture = FlutterVoiceCapture(
      recorderPrewarm: prewarmClient.prewarm,
      fileProvider: fileProvider,
      wakeLockService: wakeLockService,
      audioFormat: audioFormat,
      recorderFactory: () => recorder,
    );
  });

  tearDown(() async {
    await amplitudeController.close();
    await tempDirectory.delete(recursive: true);
  });

  test("prewarm checks permission without prompting and disposes its recorder", () async {
    await capture.prewarm();

    verify(() => recorder.hasPermission(request: false)).called(1);
    verify(
      () => prewarmClient.prewarm(
        sampleRate: audioFormat.sampleRate,
        bitRate: audioFormat.bitRate,
        numChannels: audioFormat.numChannels,
      ),
    ).called(1);
    verify(recorder.dispose).called(1);
  });

  test("skips prewarm without touching the recorder when the shell has no prewarm channel", () async {
    var recordersCreated = 0;
    final unwarmedCapture = FlutterVoiceCapture(
      recorderPrewarm: null,
      fileProvider: fileProvider,
      wakeLockService: wakeLockService,
      audioFormat: audioFormat,
      recorderFactory: () {
        recordersCreated++;
        return recorder;
      },
    );

    await unwarmedCapture.prewarm();

    expect(recordersCreated, 0);
    verifyNever(() => recorder.hasPermission(request: false));
  });

  test("shares one in-flight native prewarm across composer sessions", () async {
    final prewarmCompleter = Completer<void>();
    when(
      () => prewarmClient.prewarm(
        sampleRate: any(named: "sampleRate"),
        bitRate: any(named: "bitRate"),
        numChannels: any(named: "numChannels"),
      ),
    ).thenAnswer((_) => prewarmCompleter.future);

    final first = capture.prewarm();
    final second = capture.prewarm();
    await Future<void>.delayed(Duration.zero);

    verify(
      () => prewarmClient.prewarm(
        sampleRate: audioFormat.sampleRate,
        bitRate: audioFormat.bitRate,
        numChannels: audioFormat.numChannels,
      ),
    ).called(1);
    prewarmCompleter.complete();
    await Future.wait([first, second]);
  });

  test("recording start waits for the shared native prewarm", () async {
    final prewarmCompleter = Completer<void>();
    when(
      () => prewarmClient.prewarm(
        sampleRate: any(named: "sampleRate"),
        bitRate: any(named: "bitRate"),
        numChannels: any(named: "numChannels"),
      ),
    ).thenAnswer((_) => prewarmCompleter.future);

    final prewarm = capture.prewarm();
    final session = capture.createSession();
    final start = session.start();
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => recorder.start(any(), path: any(named: "path")));

    prewarmCompleter.complete();
    await prewarm;
    await start;
    verify(() => recorder.start(any(), path: recordingPath)).called(1);
    await session.cancel();
    await session.close();
  });

  test("bounds a later shared prewarm wait without cancelling its native operation", () async {
    final boundedCapture = FlutterVoiceCapture(
      recorderPrewarm: prewarmClient.prewarm,
      fileProvider: fileProvider,
      wakeLockService: wakeLockService,
      audioFormat: audioFormat,
      recorderFactory: () => recorder,
      prewarmWaitTimeout: Duration.zero,
    );
    await boundedCapture.prewarm();
    clearInteractions(prewarmClient);

    final prewarmCompleter = Completer<void>();
    when(
      () => prewarmClient.prewarm(
        sampleRate: any(named: "sampleRate"),
        bitRate: any(named: "bitRate"),
        numChannels: any(named: "numChannels"),
      ),
    ).thenAnswer((_) => prewarmCompleter.future);
    final prewarm = boundedCapture.prewarm();
    final session = boundedCapture.createSession();

    await expectLater(
      session.start(),
      throwsA(
        isA<VoiceCaptureFailed>().having(
          (error) => error.innerError,
          "innerError",
          isA<TimeoutException>(),
        ),
      ),
    );
    verifyNever(() => recorder.start(any(), path: any(named: "path")));

    final sharedPrewarm = boundedCapture.prewarm();
    verify(
      () => prewarmClient.prewarm(
        sampleRate: audioFormat.sampleRate,
        bitRate: audioFormat.bitRate,
        numChannels: audioFormat.numChannels,
      ),
    ).called(1);
    prewarmCompleter.complete();
    await Future.wait([prewarm, sharedPrewarm]);

    await session.start();
    verify(() => recorder.start(any(), path: recordingPath)).called(1);
    await session.cancel();
    await session.close();
  });

  test("does not reconfigure native audio while another session is active", () async {
    final session = capture.createSession();
    await session.start();

    await capture.prewarm();

    verifyNever(
      () => prewarmClient.prewarm(
        sampleRate: any(named: "sampleRate"),
        bitRate: any(named: "bitRate"),
        numChannels: any(named: "numChannels"),
      ),
    );
    await session.cancel();
    await session.close();
  });

  test("records, normalizes amplitude, returns a typed artifact, and deletes it", () async {
    await File(recordingPath).writeAsBytes([1, 2, 3]);
    final session = capture.createSession();
    final amplitudes = <double>[];
    final subscription = session.amplitudeStream.listen(amplitudes.add);
    addTearDown(subscription.cancel);

    await session.start();
    amplitudeController.add(Amplitude(current: -30, max: 0));
    await Future<void>.delayed(Duration.zero);
    final artifact = await session.stop();

    expect(amplitudes, contains(closeTo(0.5, 0.001)));
    expect(artifact.path, recordingPath);
    expect(artifact.mimeType, "audio/mp4");
    final config = verify(() => recorder.start(captureAny(), path: recordingPath)).captured.single as RecordConfig;
    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.numChannels, 1);
    verify(wakeLockService.acquire).called(1);

    await session.releaseOperation();
    expect(await session.artifactExists(artifact: artifact), isTrue);
    await session.deleteArtifact(artifact: artifact);
    expect(await session.artifactExists(artifact: artifact), isFalse);
    expect(File(recordingPath).existsSync(), isFalse);
    verify(wakeLockLease.release).called(1);
    await session.close();
  });

  test("maps denied permission without starting native recording", () async {
    when(recorder.hasPermission).thenAnswer((_) async => false);
    final session = capture.createSession();

    await expectLater(session.start(), throwsA(isA<VoiceCapturePermissionDenied>()));

    verifyNever(() => recorder.start(any(), path: any(named: "path")));
    await session.close();
  });

  test("preserves the native recorder failure in the typed capture error", () async {
    final nativeError = StateError("native recorder start failed");
    when(() => recorder.start(any(), path: any(named: "path"))).thenThrow(nativeError);
    final session = capture.createSession();

    await expectLater(
      session.start(),
      throwsA(
        isA<VoiceCaptureFailed>().having(
          (error) => error.innerError,
          "innerError",
          same(nativeError),
        ),
      ),
    );

    await session.close();
  });

  test("rolls back native recording when post-start amplitude setup fails", () async {
    final amplitudeError = StateError("native amplitude stream unavailable");
    when(() => recorder.onAmplitudeChanged(any())).thenThrow(amplitudeError);
    final session = capture.createSession();

    await expectLater(
      session.start(),
      throwsA(
        isA<VoiceCaptureFailed>().having(
          (error) => error.innerError,
          "innerError",
          same(amplitudeError),
        ),
      ),
    );

    verify(recorder.stop).called(1);
    when(() => recorder.onAmplitudeChanged(any())).thenAnswer((_) => amplitudeController.stream);
    await session.start();
    verify(() => recorder.start(any(), path: recordingPath)).called(2);
    await session.cancel();
    await session.close();
  });

  test("cancel stops recording, releases wake lock, and removes the current file", () async {
    await File(recordingPath).writeAsBytes([1, 2, 3]);
    final session = capture.createSession();
    await session.start();

    await session.cancel();

    verify(recorder.stop).called(1);
    verify(wakeLockLease.release).called(1);
    expect(File(recordingPath).existsSync(), isFalse);
    await session.close();
  });

  test("overlapping capture sessions hold the wake lock until both release", () async {
    final firstRecorder = MockAudioRecorder();
    final secondRecorder = MockAudioRecorder();
    for (final candidate in [firstRecorder, secondRecorder]) {
      when(candidate.hasPermission).thenAnswer((_) async => true);
      when(() => candidate.start(any(), path: any(named: "path"))).thenAnswer((_) async {});
      when(() => candidate.onAmplitudeChanged(any())).thenAnswer((_) => const Stream<Amplitude>.empty());
      when(candidate.stop).thenAnswer((_) async => recordingPath);
      when(candidate.dispose).thenAnswer((_) async {});
    }
    var enableCalls = 0;
    var disableCalls = 0;
    final leaseCoordinator = WakeLockService(
      enable: () async {
        enableCalls++;
      },
      disable: () async {
        disableCalls++;
      },
    );
    var index = 0;
    final multiCapture = FlutterVoiceCapture(
      recorderPrewarm: prewarmClient.prewarm,
      fileProvider: fileProvider,
      wakeLockService: leaseCoordinator,
      audioFormat: audioFormat,
      recorderFactory: () => [firstRecorder, secondRecorder][index++],
    );
    final first = multiCapture.createSession();
    final second = multiCapture.createSession();

    await first.start();
    await second.start();
    await Future<void>.delayed(Duration.zero);
    expect(enableCalls, 1);

    await first.releaseOperation();
    expect(disableCalls, 0);
    await second.releaseOperation();
    expect(disableCalls, 1);

    await first.close();
    await second.close();
  });

  test("each composer capture session receives a distinct native recorder", () {
    final recorders = [MockAudioRecorder(), MockAudioRecorder()];
    var index = 0;
    final multiCapture = FlutterVoiceCapture(
      recorderPrewarm: prewarmClient.prewarm,
      fileProvider: fileProvider,
      wakeLockService: wakeLockService,
      audioFormat: audioFormat,
      recorderFactory: () => recorders[index++],
    );

    final first = multiCapture.createSession();
    final second = multiCapture.createSession();

    expect(identical(first, second), isFalse);
    expect(index, 2);
  });

  group("PCM stream", () {
    late StreamController<Uint8List> chunks;
    void Function(RecordConfig)? onConfigChanged;

    setUp(() {
      chunks = StreamController<Uint8List>.broadcast();
      onConfigChanged = null;
      when(() => recorder.setOnConfigChanged(any())).thenAnswer((invocation) async {
        onConfigChanged = invocation.positionalArguments.single as void Function(RecordConfig)?;
      });
      when(() => recorder.startStream(any())).thenAnswer((_) async => chunks.stream);
      when(recorder.stop).thenAnswer((_) async {
        await chunks.close();
        return null;
      });
    });

    /// Collects what the caller sees: frames as lists, and errors.
    ({List<List<int>> frames, List<Object> errors, Future<void> done}) collect(Stream<Uint8List> stream) {
      final frames = <List<int>>[];
      final errors = <Object>[];
      final done = Completer<void>();
      stream.listen(frames.add, onError: errors.add, onDone: done.complete);
      return (frames: frames, errors: errors, done: done.future);
    }

    test("asks for PCM16 mono at 16 kHz with the same effects as recording, and no file", () async {
      final session = capture.createSession();

      await session.startPcmStream();

      final config = verify(() => recorder.startStream(captureAny())).captured.single as RecordConfig;
      expect(config.encoder, AudioEncoder.pcm16bits);
      expect(config.sampleRate, 16000);
      expect(voiceCapturePcmSampleRate.hertz, 16000);
      expect(config.numChannels, 1);
      expect(config.autoGain, isTrue);
      expect(config.noiseSuppress, isTrue);
      expect(config.audioInterruption, AudioInterruptionMode.none);
      expect(config.iosConfig.allowHapticsAndSystemSoundsDuringRecording, isTrue);
      verifyNever(() => fileProvider.createRecordingPath());
      verifyNever(() => recorder.start(any(), path: any(named: "path")));
      await session.close();
    });

    test("delivers even frames from odd chunks, and the amplitude and wake lock carry over", () async {
      final session = capture.createSession();
      final amplitudes = <double>[];
      final amplitudeSubscription = session.amplitudeStream.listen(amplitudes.add);
      addTearDown(amplitudeSubscription.cancel);

      final seen = collect(await session.startPcmStream());
      chunks.add(Uint8List.fromList([1, 2, 3]));
      chunks.add(Uint8List.fromList([4, 5, 6, 7]));
      chunks.add(Uint8List.fromList([8]));
      amplitudeController.add(Amplitude(current: -30, max: 0));
      await pumpEventQueue();

      expect(seen.frames, [
        [1, 2],
        [3, 4, 5, 6],
        [7, 8],
      ]);
      expect(amplitudes, contains(closeTo(0.5, 0.001)));
      verify(wakeLockService.acquire).called(1);
      await session.close();
    });

    test("stopping closes the stream without an error, delivers late chunks, and drops a last half sample", () async {
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());
      when(recorder.stop).thenAnswer((_) async {
        chunks.add(Uint8List.fromList([1, 2, 3]));
        await chunks.close();
        return null;
      });

      await session.stopPcmStream();
      await seen.done;

      expect(seen.frames, [
        [1, 2],
      ]);
      expect(seen.errors, isEmpty);
      verifyNever(wakeLockLease.release);

      await session.releaseOperation();
      verify(wakeLockLease.release).called(1);
      await session.close();
    });

    test("a stop that fails keeps the cause, and cancel stops the recorder again", () async {
      final stopError = StateError("native stop failed");
      when(recorder.stop).thenThrow(stopError);
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());

      await expectLater(
        session.stopPcmStream(),
        throwsA(isA<VoiceCaptureFailed>().having((error) => error.innerError, "innerError", same(stopError))),
      );
      verify(recorder.stop).called(1);

      when(recorder.stop).thenAnswer((_) async => null);
      await session.cancel();
      verify(recorder.stop).called(1);
      await seen.done;
      await session.close();
    });

    test("a recorder error reaches the frames as a capture failure holding its cause", () async {
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());
      final nativeError = StateError("AudioRecord read failed");

      chunks.addError(nativeError);
      await seen.done;

      expect(
        seen.errors.single,
        isA<VoiceCaptureFailed>().having((e) => e.innerError, "innerError", same(nativeError)),
      );
      await session.cancel();
      verify(recorder.stop).called(1);
      verify(wakeLockLease.release).called(1);
      await session.close();
    });

    test("a recorder that ends by itself is a failure, as parecord exiting would be", () async {
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());

      await chunks.close();
      await seen.done;

      expect(
        seen.errors.single,
        isA<VoiceCaptureFailed>().having((e) => e.innerError, "innerError", isA<StateError>()),
      );
      await session.close();
    });

    test("a changed rate or channel count fails the stream and later chunks are dropped", () async {
      for (final changed in const [
        RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 2),
        RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 48000, numChannels: 1),
      ]) {
        chunks = StreamController<Uint8List>.broadcast();
        final session = capture.createSession();
        final seen = collect(await session.startPcmStream());

        onConfigChanged?.call(changed);
        chunks.add(Uint8List.fromList([1, 2]));
        await seen.done;

        expect(seen.frames, isEmpty);
        expect(
          seen.errors.single,
          isA<VoiceCaptureFailed>().having((e) => e.innerError, "innerError", isA<UnsupportedError>()),
        );
        await session.close();
      }
    });

    test("a change that leaves the format alone is ignored", () async {
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());

      onConfigChanged?.call(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, bitRate: 1, sampleRate: 16000, numChannels: 1),
      );
      chunks.add(Uint8List.fromList([1, 2]));
      await pumpEventQueue();

      expect(seen.frames, [
        [1, 2],
      ]);
      expect(seen.errors, isEmpty);
      await session.close();
    });

    test("falls back: after cancel a file recording starts, and its own config changes are not failures", () async {
      await File(recordingPath).writeAsBytes([1, 2, 3]);
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());

      await session.cancel();
      await seen.done;
      expect(seen.errors, isEmpty);
      verify(wakeLockLease.release).called(1);

      when(recorder.stop).thenAnswer((_) async => recordingPath);
      await session.start();
      onConfigChanged?.call(const RecordConfig(sampleRate: 44100, numChannels: 2));
      final artifact = await session.stop();

      expect(artifact.path, recordingPath);
      expect(seen.errors, isEmpty);
      await session.close();
    });

    test("denied permission starts nothing", () async {
      when(recorder.hasPermission).thenAnswer((_) async => false);
      final session = capture.createSession();

      await expectLater(session.startPcmStream(), throwsA(isA<VoiceCapturePermissionDenied>()));

      verifyNever(() => recorder.startStream(any()));
      await session.close();
    });

    test("a failed start keeps the cause, releases everything, and a file recording still starts", () async {
      final nativeError = Exception("parecord: command not found");
      when(() => recorder.startStream(any())).thenThrow(nativeError);
      final session = capture.createSession();

      await expectLater(
        session.startPcmStream(),
        throwsA(isA<VoiceCaptureFailed>().having((error) => error.innerError, "innerError", same(nativeError))),
      );
      verifyNever(wakeLockService.acquire);
      verifyNever(recorder.stop);

      await session.start();
      verify(() => recorder.start(any(), path: recordingPath)).called(1);
      when(recorder.stop).thenAnswer((_) async => recordingPath);
      await session.close();
    });

    test("a failure after the native start stops the recorder again", () async {
      final amplitudeError = StateError("native amplitude stream unavailable");
      when(() => recorder.onAmplitudeChanged(any())).thenThrow(amplitudeError);
      final session = capture.createSession();

      await expectLater(
        session.startPcmStream(),
        throwsA(isA<VoiceCaptureFailed>().having((error) => error.innerError, "innerError", same(amplitudeError))),
      );

      verify(recorder.stop).called(1);
      await session.close();
    });

    test("holds the shared activity, so a prewarm waits until the stream's operation is released", () async {
      final session = capture.createSession();
      await session.startPcmStream();

      await capture.prewarm();
      verifyNever(
        () => prewarmClient.prewarm(
          sampleRate: any(named: "sampleRate"),
          bitRate: any(named: "bitRate"),
          numChannels: any(named: "numChannels"),
        ),
      );

      await session.stopPcmStream();
      await session.releaseOperation();
      await capture.prewarm();
      verify(
        () => prewarmClient.prewarm(
          sampleRate: any(named: "sampleRate"),
          bitRate: any(named: "bitRate"),
          numChannels: any(named: "numChannels"),
        ),
      ).called(1);
      await session.close();
    });

    test("the two modes refuse each other, and stopping refuses the wrong one", () async {
      final session = capture.createSession();
      await expectLater(session.stopPcmStream(), throwsA(isA<VoiceCaptureFailed>()));

      await session.startPcmStream();
      await expectLater(session.start(), throwsA(isA<VoiceCaptureFailed>()));
      await expectLater(session.startPcmStream(), throwsA(isA<VoiceCaptureFailed>()));
      await expectLater(session.stop(), throwsA(isA<VoiceCaptureFailed>()));
      await session.stopPcmStream();

      when(recorder.stop).thenAnswer((_) async => recordingPath);
      await session.start();
      await expectLater(session.startPcmStream(), throwsA(isA<VoiceCaptureFailed>()));
      await session.close();
    });

    test("closing while streaming stops the recorder and closes the frames", () async {
      final session = capture.createSession();
      final seen = collect(await session.startPcmStream());

      await session.close();
      await seen.done;

      expect(seen.errors, isEmpty);
      verify(recorder.stop).called(1);
      verify(recorder.dispose).called(1);
    });
  });

  group("PCM support check", () {
    FlutterVoiceCapture captureWith({required bool toolAvailable}) => FlutterVoiceCapture(
      recorderPrewarm: null,
      fileProvider: fileProvider,
      wakeLockService: wakeLockService,
      audioFormat: audioFormat,
      recorderFactory: () => recorder,
      pcmCaptureToolCheck: () async => toolAvailable,
    );

    test("needs both the recorder's encoder and the tool", () async {
      when(() => recorder.isEncoderSupported(AudioEncoder.pcm16bits)).thenAnswer((_) async => true);
      expect(await captureWith(toolAvailable: true).createSession().supportsPcmStream(), isTrue);
      expect(await captureWith(toolAvailable: false).createSession().supportsPcmStream(), isFalse);

      when(() => recorder.isEncoderSupported(AudioEncoder.pcm16bits)).thenAnswer((_) async => false);
      expect(await captureWith(toolAvailable: true).createSession().supportsPcmStream(), isFalse);
    });

    test("a check that fails reports no support", () async {
      when(() => recorder.isEncoderSupported(AudioEncoder.pcm16bits)).thenThrow(StateError("no channel"));
      expect(await captureWith(toolAvailable: true).createSession().supportsPcmStream(), isFalse);
    });

    test("only Linux looks for a tool", () async {
      expect(await isPcmCaptureToolAvailable(isLinux: false, parecord: "${tempDirectory.path}/missing"), isTrue);
    });

    test("on Linux a missing parecord reports no support", () async {
      expect(await isPcmCaptureToolAvailable(isLinux: true, parecord: "${tempDirectory.path}/missing"), isFalse);
    });

    test("on Linux parecord has to run", () async {
      Future<String> script({required String name, required int exitCode}) async {
        final file = File("${tempDirectory.path}/$name");
        await file.writeAsString("#!/bin/sh\nexit $exitCode\n");
        await Process.run("chmod", ["+x", file.path]);
        return file.path;
      }

      expect(
        await isPcmCaptureToolAvailable(isLinux: true, parecord: await script(name: "good", exitCode: 0)),
        isTrue,
      );
      expect(
        await isPcmCaptureToolAvailable(isLinux: true, parecord: await script(name: "bad", exitCode: 1)),
        isFalse,
      );
    }, testOn: "!windows");
  });
}
