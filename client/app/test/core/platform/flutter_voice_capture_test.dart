import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/recorder_prewarm_client.dart";
import "package:sesori_mobile/capabilities/voice/recording_file_provider.dart";
import "package:sesori_mobile/capabilities/voice/wake_lock_service.dart";
import "package:sesori_mobile/core/platform/flutter_voice_capture.dart";

class MockAudioRecorder() extends Mock implements AudioRecorder;

class MockRecorderPrewarmClient() extends Mock implements RecorderPrewarmClient;

class MockRecordingFileProvider() extends Mock implements RecordingFileProvider;

class MockWakeLockService() extends Mock implements WakeLockService;

class MockWakeLockLease() extends Mock implements WakeLockLease;

void main() {
  late MockAudioRecorder recorder;
  late MockRecorderPrewarmClient prewarmClient;
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
  });

  setUp(() async {
    recorder = MockAudioRecorder();
    prewarmClient = MockRecorderPrewarmClient();
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
      recorderPrewarmClient: prewarmClient,
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
      recorderPrewarmClient: prewarmClient,
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
      recorderPrewarmClient: prewarmClient,
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
      recorderPrewarmClient: prewarmClient,
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
}
