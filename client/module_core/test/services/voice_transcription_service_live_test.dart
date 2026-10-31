import "dart:async";
import "dart:typed_data";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_client.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_protocol.dart";
import "package:sesori_shared/sesori_shared.dart" show HealthResponse, Project, ProjectGlossaryKey;
import "package:test/test.dart";

import "../capabilities/voice/fake_realtime_voice_channel.dart";

class _MockVoiceRepository() extends Mock implements VoiceRepository;

class _MockProjectRepository() extends Mock implements ProjectRepository;

class _MockVoiceModeRepository() extends Mock implements VoiceModeRepository;

class _MockVoiceCapture() extends Mock implements VoiceCapture;

class _MockVoiceCaptureSession() extends Mock implements VoiceCaptureSession;

class _MockVoiceApi() extends Mock implements VoiceApi;

class _MockConnectionService() extends Mock implements ConnectionService;

const _ready = '{"type":"ready","protocolVersion":1,"maxSessionSeconds":900,"dailySecondsRemaining":420}';
const _finished = '{"type":"complete","reason":"finished","dailySecondsRemaining":400}';
const _sessionLimit = '{"type":"complete","reason":"session_limit","dailySecondsRemaining":0}';
const _quotaLimit = '{"type":"complete","reason":"quota_limit","dailySecondsRemaining":0}';
const _serverError = '{"type":"error","code":"internal_error","retryable":true}';
const _audioTimeout = '{"type":"error","code":"audio_timeout","retryable":true}';
const _artifact = VoiceRecordingArtifact(path: "/tmp/voice.m4a", mimeType: "audio/mp4");

String _words({required String confirmed, required String provisional}) =>
    '{"type":"transcript","confirmedDelta":"$confirmed","provisional":"$provisional"}';

Uint8List _frame({required int fill}) => Uint8List.fromList([fill, fill]);

void main() {
  late FakeRealtimeVoiceChannel channel;
  late _MockVoiceRepository repository;
  late _MockConnectionService connectionService;
  late _MockVoiceModeRepository voiceModeRepository;
  late _MockVoiceCaptureSession capture;
  late StreamController<Uint8List> frames;
  late VoiceTranscriptionService service;
  late VoiceTranscriptionSession session;
  late List<VoiceLiveEvent> events;
  VoiceMode mode = const VoiceModeLive(presentation: VoiceLivePresentation.panel);

  setUpAll(() {
    registerFallbackValue(_artifact);
    registerFallbackValue(VoiceRealtimeSampleRate.hz16000);
  });

  /// A session whose voice mode and host support have both answered.
  Future<VoiceTranscriptionSession> createSession({String? projectId}) async {
    final created = service.createSession(projectId: projectId, allowLive: true);
    service.liveEventStream(session: created).listen(events.add);
    await pumpEventQueue();
    return created;
  }

  /// What the dictation sent after the socket's `start` frame.
  List<Object?> sentAfterStart() => channel.outbound.skip(1).toList();

  void hear(String frame) => channel.inbound.add(frame);

  Future<void> holdLive() async {
    session = await createSession();
    await service.start(session: session);
    channel.upgrade.complete();
    await pumpEventQueue();
  }

  Future<void> holdStreaming() async {
    await holdLive();
    hear(_ready);
    await pumpEventQueue();
    frames.add(_frame(fill: 1));
    await pumpEventQueue();
  }

  setUp(() {
    channel = FakeRealtimeVoiceChannel();
    events = [];
    mode = const VoiceModeLive(presentation: VoiceLivePresentation.panel);
    frames = StreamController<Uint8List>();
    repository = _MockVoiceRepository();
    voiceModeRepository = _MockVoiceModeRepository();
    connectionService = _MockConnectionService();
    when(() => connectionService.currentStatus).thenReturn(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
          bridgeId: "computer",
        ),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      ),
    );
    capture = _MockVoiceCaptureSession();
    final platform = _MockVoiceCapture();
    final realRepository = VoiceRepository(
      api: _MockVoiceApi(),
      realtimeClient: RealtimeVoiceClient.withChannelConnector(
        tokenProvider: FakeRealtimeVoiceTokenProvider(token: "token"),
        channelConnector: ({required uri, required headers}) => channel,
      ),
    );

    when(platform.createSession).thenReturn(capture);
    when(platform.prewarm).thenAnswer((_) async {});
    when(voiceModeRepository.load).thenAnswer((_) async {});
    when(() => voiceModeRepository.mode).thenAnswer((_) => mode);
    when(() => capture.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(capture.supportsPcmStream).thenAnswer((_) async => true);
    when(capture.startPcmStream).thenAnswer((_) async => frames.stream);
    when(capture.stopPcmStream).thenAnswer((_) => frames.close());
    when(capture.cancel).thenAnswer((_) async {});
    when(capture.start).thenAnswer((_) async {});
    when(capture.stop).thenAnswer((_) async => _artifact);
    when(capture.releaseOperation).thenAnswer((_) async {});
    when(capture.close).thenAnswer((_) async {});
    when(() => capture.deleteArtifact(artifact: any(named: "artifact"))).thenAnswer((_) async {});
    when(
      () => repository.openRealtime(
        sampleRate: any(named: "sampleRate"),
        projectKey: any(named: "projectKey"),
      ),
    ).thenAnswer(
      (invocation) => realRepository.openRealtime(
        sampleRate: invocation.namedArguments[#sampleRate] as VoiceRealtimeSampleRate,
        projectKey: invocation.namedArguments[#projectKey] as ProjectGlossaryKey?,
      ),
    );
    when(
      () => repository.transcribe(
        audioFilePath: any(named: "audioFilePath"),
        mimeType: any(named: "mimeType"),
        projectGlossaryKey: any(named: "projectGlossaryKey"),
      ),
    ).thenAnswer((_) async => const VoiceTranscriptionOutcome.success(transcript: "recorded words"));
    service = VoiceTranscriptionService(
      repository: repository,
      projectRepository: _MockProjectRepository(),
      voiceModeRepository: voiceModeRepository,
      capture: platform,
      connectionService: connectionService,
    );
  });

  void expectNoSocket() {
    verifyNever(
      () => repository.openRealtime(
        sampleRate: any(named: "sampleRate"),
        projectKey: any(named: "projectKey"),
      ),
    );
  }

  group("the mode decision", () {
    test("a hold before the mode has answered records, and never waits for the answer", () async {
      final load = Completer<void>();
      when(voiceModeRepository.load).thenAnswer((_) => load.future);
      session = service.createSession(projectId: null, allowLive: true);

      await service.start(session: session);

      verify(capture.start).called(1);
      verifyNever(capture.startPcmStream);
      expect(service.livePresentation(session: session), isNull);
      load.complete();
    });

    test("a hold before the host has answered records", () async {
      final support = Completer<bool>();
      when(capture.supportsPcmStream).thenAnswer((_) => support.future);
      session = service.createSession(projectId: null, allowLive: true);
      await pumpEventQueue();

      await service.start(session: session);

      verify(capture.start).called(1);
      verifyNever(capture.startPcmStream);
      support.complete(true);
    });

    test("a host that cannot stream records", () async {
      when(capture.supportsPcmStream).thenAnswer((_) async => false);
      session = await createSession();

      await service.start(session: session);

      verify(capture.start).called(1);
      verifyNever(capture.startPcmStream);
    });

    test("after-recording never asks the host, which would spawn a process on Linux", () async {
      mode = const VoiceModeAfterRecording();
      session = await createSession();

      await service.start(session: session);

      verifyNever(capture.supportsPcmStream);
      verify(capture.start).called(1);
    });

    test("a surface that keeps recording first neither loads the mode nor goes live", () async {
      session = service.createSession(projectId: null, allowLive: false);
      await pumpEventQueue();

      await service.start(session: session);

      verifyNever(voiceModeRepository.load);
      verifyNever(capture.supportsPcmStream);
      verifyNever(capture.startPcmStream);
      verify(capture.start).called(1);
    });

    test("a failed mode load keeps the last known mode", () async {
      when(voiceModeRepository.load).thenThrow(StateError("no answer"));
      session = await createSession();

      await service.start(session: session);

      verify(capture.startPcmStream).called(1);
    });

    test("the switch changing mid-dictation leaves it live, and the next hold follows the switch", () async {
      await holdStreaming();
      expect(service.livePresentation(session: session), VoiceLivePresentation.panel);

      mode = const VoiceModeAfterRecording();
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_words(confirmed: "live words", provisional: ""));
      hear(_finished);
      expect((await result).mode, VoiceDictationMode.live);

      await service.start(session: session);
      verify(capture.start).called(1);
      expect(service.livePresentation(session: session), isNull);
    });

    test("the switch turning live mid-recording leaves it recording", () async {
      session = await createSession();
      mode = const VoiceModeAfterRecording();
      await service.start(session: session);
      mode = const VoiceModeLive(presentation: VoiceLivePresentation.focus);

      final result = await service.stopAndTranscribe(session: session);

      expect(result.mode, VoiceDictationMode.afterRecording);
      expect(result.outcome, VoiceDictationOutcome.finished);
      verifyNever(capture.startPcmStream);
    });

    test("the presentation comes from the mode at the hold", () async {
      mode = const VoiceModeLive(presentation: VoiceLivePresentation.focus);
      await holdLive();

      expect(service.livePresentation(session: session), VoiceLivePresentation.focus);
    });
  });

  group("streaming", () {
    test("opens at the capture's rate with the interaction's glossary key", () async {
      final key = ProjectGlossaryKey.parse(value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ");
      final projects = _MockProjectRepository();
      final platform = _MockVoiceCapture();
      when(platform.createSession).thenReturn(capture);
      when(platform.prewarm).thenAnswer((_) async {});
      when(() => projects.getProject(projectId: "project")).thenAnswer(
        (_) async => ApiResponse.success(
          Project(id: "project", name: "Project", path: "/project", time: null, voiceGlossaryKey: key),
        ),
      );
      service = VoiceTranscriptionService(
        repository: repository,
        projectRepository: projects,
        voiceModeRepository: voiceModeRepository,
        capture: platform,
        connectionService: connectionService,
      );
      session = await createSession(projectId: "project");

      await service.start(session: session);
      await pumpEventQueue();

      verify(() => repository.openRealtime(sampleRate: voiceCapturePcmSampleRate, projectKey: key)).called(1);
    });

    test("a remembered key reaches a dictation that starts before the bridge answers", () async {
      final key = ProjectGlossaryKey.parse(value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ");
      final projects = _MockProjectRepository();
      final platform = _MockVoiceCapture();
      when(platform.createSession).thenReturn(capture);
      when(platform.prewarm).thenAnswer((_) async {});
      when(() => projects.getProject(projectId: "project")).thenAnswer(
        (_) async => ApiResponse.success(
          Project(id: "project", name: "Project", path: "/project", time: null, voiceGlossaryKey: key),
        ),
      );
      service = VoiceTranscriptionService(
        repository: repository,
        projectRepository: projects,
        voiceModeRepository: voiceModeRepository,
        capture: platform,
        connectionService: connectionService,
      );
      await createSession(projectId: "project");
      when(
        () => projects.getProject(projectId: "project"),
      ).thenAnswer((_) => Completer<ApiResponse<Project>>().future);
      session = await createSession(projectId: "project");

      await service.start(session: session);
      await pumpEventQueue();

      verify(() => repository.openRealtime(sampleRate: voiceCapturePcmSampleRate, projectKey: key)).called(1);
    });

    test("holds audio until ready, in order, and then forwards it directly", () async {
      await holdLive();
      frames.add(_frame(fill: 1));
      frames.add(_frame(fill: 2));
      await pumpEventQueue();
      expect(sentAfterStart(), isEmpty, reason: "Audio before ready would end the session.");

      hear(_ready);
      await pumpEventQueue();
      expect(sentAfterStart(), [_frame(fill: 1), _frame(fill: 2)]);

      frames.add(_frame(fill: 3));
      await pumpEventQueue();
      expect(sentAfterStart(), [_frame(fill: 1), _frame(fill: 2), _frame(fill: 3)]);
    });

    test("audio held while the socket connects also waits for ready", () async {
      session = await createSession();
      await service.start(session: session);
      frames.add(_frame(fill: 1));
      await pumpEventQueue();

      channel.upgrade.complete();
      await pumpEventQueue();
      hear(_ready);
      await pumpEventQueue();

      expect(sentAfterStart(), [_frame(fill: 1)]);
    });

    test("reports the words as they grow, with the provisional part replaced", () async {
      await holdStreaming();

      hear(_words(confirmed: "one ", provisional: "tw"));
      hear(_words(confirmed: "two ", provisional: ""));
      await pumpEventQueue();

      expect(
        events.whereType<VoiceLiveWordsChanged>().map((event) => event.words),
        const [
          LiveWords(confirmed: "one ", provisional: "tw"),
          LiveWords(confirmed: "one two ", provisional: ""),
        ],
      );
    });

    test("a release sends finish after the last frame, and lands on confirmed words only", () async {
      await holdStreaming();
      hear(_words(confirmed: "final words ", provisional: "never said"));
      await pumpEventQueue();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceFinishFrame]);
      hear(_finished);

      final ended = await result;
      expect(ended.transcript, "final words");
      expect(ended.outcome, VoiceDictationOutcome.finished);
      expect(ended.mode, VoiceDictationMode.live);
      verify(capture.cancel).called(1);
      verifyNever(capture.stop);
      await expectLater(service.stopAndTranscribe(session: session), throwsA(isA<NotRecordingError>()));
    });

    test("a blank finish is the empty-transcript error", () async {
      await holdStreaming();
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_words(confirmed: "  ", provisional: ""));
      hear(_finished);

      await expectLater(result, throwsA(isA<EmptyTranscriptError>()));
    });

    test("a microphone that fails to stop is cancelled, and the audio already sent still finishes", () async {
      when(capture.stopPcmStream).thenThrow(VoiceCaptureError.failed(innerError: StateError("stop failed")));
      when(capture.cancel).thenAnswer((_) async {
        if (!frames.isClosed) await frames.close();
      });
      await holdStreaming();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();

      verify(capture.cancel).called(1);
      expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceFinishFrame]);
      hear(_words(confirmed: "kept", provisional: ""));
      hear(_finished);
      expect((await result).transcript, "kept");
    });
  });

  group("a quick release before ready", () {
    test("waits for ready, flushes the held audio, and only then finishes", () async {
      await holdLive();
      frames.add(_frame(fill: 1));
      await pumpEventQueue();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      verify(capture.stopPcmStream).called(1);
      expect(sentAfterStart(), isEmpty, reason: "The whole dictation waits for ready.");

      hear(_ready);
      await pumpEventQueue();
      expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceFinishFrame]);

      hear(_words(confirmed: "quick", provisional: ""));
      hear(_finished);
      final ended = await result;
      expect(ended.transcript, "quick");
      expect(ended.mode, VoiceDictationMode.live);
    });

    test("a release before the socket is even open waits for it too", () async {
      session = await createSession();
      await service.start(session: session);
      frames.add(_frame(fill: 1));
      await pumpEventQueue();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      channel.upgrade.complete();
      await pumpEventQueue();
      expect(sentAfterStart(), isEmpty);

      hear(_ready);
      await pumpEventQueue();
      expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceFinishFrame]);
      hear(_finished);
      await expectLater(result, throwsA(isA<EmptyTranscriptError>()));
    });

    test("a failure then cannot record anything, so it surfaces and records nothing", () async {
      await holdLive();
      frames.add(_frame(fill: 1));
      await pumpEventQueue();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_serverError);

      await expectLater(result, throwsA(isA<RetryableServerVoiceError>()));
      verifyNever(capture.start);
      expect(events.whereType<VoiceLiveFellBack>(), isEmpty);
    });
  });

  group("a start slower than the server allows", () {
    const bytesPerSecond = 32000;
    const tick = Duration(milliseconds: 100);
    const bytesPerTick = 3200;

    /// A tenth of a second of audio that says which one it is.
    Uint8List numbered({required int index}) => Uint8List(bytesPerTick)..buffer.asByteData().setUint32(0, index);

    List<Uint8List> sentAudio() => sentAfterStart().whereType<Uint8List>().toList();

    List<int> sentNumbers() => sentAudio().map((frame) => frame.buffer.asByteData().getUint32(0)).toList();

    /// Runs [body] in fake time, with a dictation held and its socket waiting for `ready`.
    void whileHeld(void Function(FakeAsync async) body) {
      fakeAsync((async) {
        // A completer belongs to the zone that made it, so these have to be in fake time
        // too. Without onCancel, cancelling the frames returns a future of the real zone,
        // which never completes inside this synchronous body.
        channel = FakeRealtimeVoiceChannel();
        frames = StreamController<Uint8List>(onCancel: () async {});
        unawaited(holdLive());
        async.elapse(Duration.zero);
        body(async);
      });
    }

    /// The microphone delivering [count] frames at real time, from [from] on.
    void speak(FakeAsync async, {required int from, required int count}) {
      for (var index = from; index < from + count; index++) {
        frames.add(numbered(index: index));
        async.elapse(tick);
      }
    }

    void becomeReady(FakeAsync async) {
      hear(_ready);
      async.elapse(Duration.zero);
    }

    test("every byte goes out in order, with what's new behind what's held", () {
      whileHeld((async) {
        speak(async, from: 0, count: 70);
        expect(sentAudio(), isEmpty);
        expect(events, isEmpty, reason: "Seven seconds is no reason to give up.");

        becomeReady(async);
        expect(sentNumbers(), List.generate(40, (index) => index), reason: "Four seconds go at once.");

        speak(async, from: 70, count: 50);
        expect(sentNumbers(), List.generate(90, (index) => index), reason: "The rest follows at real time.");

        unawaited(service.stopAndTranscribe(session: session));
        async.elapse(const Duration(seconds: 4));
        expect(sentNumbers(), List.generate(120, (index) => index));
        expect(sentAudio().every((frame) => frame.length == bytesPerTick), isTrue);
      });
    });

    test("nothing is ever more than 4 s ahead of real time, however it is held and released", () {
      for (final heldFrames in const [41, 70, 300]) {
        whileHeld((async) {
          speak(async, from: 0, count: heldFrames);
          final readyAt = async.elapsed;
          var sentBytes = 0;
          var mostAhead = Duration.zero;
          channel.onOutbound = ({required data}) {
            if (data is! Uint8List) return;
            sentBytes += data.length;
            final sent = Duration(microseconds: sentBytes * 1000000 ~/ bytesPerSecond);
            final ahead = sent - (async.elapsed - readyAt);
            if (ahead > mostAhead) mostAhead = ahead;
          };

          becomeReady(async);
          speak(async, from: heldFrames, count: 20);
          unawaited(service.stopAndTranscribe(session: session));
          async.elapse(const Duration(seconds: 40));

          expect(sentNumbers(), List.generate(heldFrames + 20, (index) => index));
          expect(mostAhead, const Duration(seconds: 4), reason: "It uses the whole allowance and never passes it.");
        });
      }
    });

    test("a frame that doesn't fit yet waits whole, so no sample is ever cut", () {
      whileHeld((async) {
        // Three frames of 1.5 s: the third would go past the 4 s.
        for (var index = 0; index < 3; index++) {
          frames.add(Uint8List(48000)..[0] = index);
        }
        async.elapse(Duration.zero);

        becomeReady(async);
        expect(sentAudio().map((frame) => frame.length), [48000, 48000]);

        async.elapse(const Duration(milliseconds: 400));
        expect(sentAudio(), hasLength(2));

        async.elapse(tick);
        expect(sentAudio().map((frame) => frame.length), [48000, 48000, 48000]);
        expect(sentAudio().map((frame) => frame[0]), [0, 1, 2]);
      });
    });

    test("a release mid-backlog finishes only after the last byte", () {
      whileHeld((async) {
        speak(async, from: 0, count: 60);
        becomeReady(async);
        late final VoiceDictationResult ended;
        unawaited(service.stopAndTranscribe(session: session).then((result) => ended = result));
        async.elapse(Duration.zero);
        verify(capture.stopPcmStream).called(1);

        async.elapse(const Duration(milliseconds: 1900));
        expect(sentAudio(), hasLength(59));
        expect(sentAfterStart(), isNot(contains(realtimeVoiceFinishFrame)));

        async.elapse(tick);
        expect(sentNumbers(), List.generate(60, (index) => index));
        expect(sentAfterStart().last, realtimeVoiceFinishFrame);
        expect(async.periodicTimerCount, 0);

        hear(_words(confirmed: "every word", provisional: ""));
        hear(_finished);
        async.elapse(Duration.zero);
        expect(ended.transcript, "every word");
        expect(ended.outcome, VoiceDictationOutcome.finished);
      });
    });

    test("a release before ready waits for the server, then paces what was held, then finishes", () {
      whileHeld((async) {
        speak(async, from: 0, count: 60);
        unawaited(service.stopAndTranscribe(session: session));
        async.elapse(const Duration(seconds: 3));
        expect(sentAudio(), isEmpty);

        becomeReady(async);
        expect(sentAudio(), hasLength(40));
        expect(sentAfterStart().last, isNot(realtimeVoiceFinishFrame));

        async.elapse(const Duration(seconds: 2));
        expect(sentNumbers(), List.generate(60, (index) => index));
        expect(sentAfterStart().last, realtimeVoiceFinishFrame);
      });
    });

    group("mid-backlog stops at once and leaves no timer", () {
      void expectStops({required void Function() stop, required Object? lastSent}) {
        whileHeld((async) {
          speak(async, from: 0, count: 60);
          becomeReady(async);
          expect(async.periodicTimerCount, 1);

          stop();
          async.elapse(Duration.zero);

          expect(async.periodicTimerCount, 0);
          async.elapse(const Duration(seconds: 5));
          expect(sentAudio(), hasLength(40));
          expect(sentAfterStart().last, lastSent);
        });
      }

      test("for a cancel with the finger down", () {
        expectStops(
          stop: () => unawaited(service.cancel(session: session)),
          lastSent: realtimeVoiceCancelFrame,
        );
      });

      test("for closing the session", () {
        expectStops(
          stop: () => unawaited(service.close(session: session)),
          lastSent: realtimeVoiceCancelFrame,
        );
      });

      test("for the socket dropping, which hands over the words", () {
        expectStops(
          stop: () {
            hear(_words(confirmed: "kept", provisional: ""));
            unawaited(channel.inbound.close());
          },
          lastSent: isA<Uint8List>(),
        );
        expect(
          events.last,
          isA<VoiceLiveEnded>()
              .having((e) => e.transcript, "transcript", "kept")
              .having((e) => e.outcome, "outcome", VoiceDictationOutcome.interrupted),
        );
      });

      test("for the server's limit, which hands over the words", () {
        expectStops(
          stop: () {
            hear(_words(confirmed: "early ", provisional: ""));
            hear(_quotaLimit);
          },
          lastSent: isA<Uint8List>(),
        );
        expect(
          events.last,
          isA<VoiceLiveEnded>()
              .having((e) => e.transcript, "transcript", "early")
              .having((e) => e.outcome, "outcome", VoiceDictationOutcome.limitReached),
        );
      });

      test("for the X after a release", () {
        whileHeld((async) {
          speak(async, from: 0, count: 60);
          becomeReady(async);
          Object? ended;
          unawaited(service.stopAndTranscribe(session: session).then<void>((_) {}, onError: (Object e) => ended = e));
          async.elapse(tick);
          expect(sentAudio(), hasLength(41));

          unawaited(service.cancel(session: session));
          async.elapse(Duration.zero);

          expect(ended, isA<TranscriptionCancelledError>());
          expect(async.periodicTimerCount, 0);
          async.elapse(const Duration(seconds: 5));
          expect(sentAudio(), hasLength(41));
        });
      });
    });

    group("no backlog means no timer", () {
      test("for a normal start, with frames forwarded as they come", () {
        whileHeld((async) {
          speak(async, from: 0, count: 10);
          becomeReady(async);
          expect(async.periodicTimerCount, 0);
          expect(sentAudio(), hasLength(10));

          frames.add(numbered(index: 10));
          async.elapse(Duration.zero);
          expect(sentNumbers().last, 10, reason: "No tick stands between the microphone and the socket.");
          expect(async.periodicTimerCount, 0);
        });
      });

      test("for exactly the allowance, all of it sent at ready", () {
        whileHeld((async) {
          speak(async, from: 0, count: 40);
          becomeReady(async);

          expect(sentAudio(), hasLength(40));
          expect(async.periodicTimerCount, 0);
        });
      });

      test("once a backlog has drained, frames go straight through again", () {
        whileHeld((async) {
          speak(async, from: 0, count: 45);
          becomeReady(async);
          expect(async.periodicTimerCount, 1);

          async.elapse(const Duration(milliseconds: 500));
          expect(sentAudio(), hasLength(45));
          expect(async.periodicTimerCount, 0);

          frames.add(numbered(index: 45));
          async.elapse(Duration.zero);
          expect(sentNumbers().last, 45);
        });
      });
    });
  });

  group("falling back to a recording", () {
    Future<void> expectRecordedResult() async {
      final result = await service.stopAndTranscribe(session: session);
      expect(result.transcript, "recorded words");
      expect(result.outcome, VoiceDictationOutcome.interrupted, reason: "Fallback words are not sent unseen (D33).");
      expect(result.mode, VoiceDictationMode.afterRecording);
    }

    void expectFellBack() {
      expect(events.whereType<VoiceLiveFellBack>(), hasLength(1));
      verify(capture.start).called(1);
      expect(service.livePresentation(session: session), isNull);
    }

    test("when the socket cannot open", () async {
      session = await createSession();
      await service.start(session: session);
      channel.upgrade.completeError(StateError("no route"));
      await pumpEventQueue();

      expectFellBack();
      await expectRecordedResult();
    });

    test("when the server fails before ready", () async {
      await holdLive();
      hear(_serverError);
      await pumpEventQueue();

      expectFellBack();
      await expectRecordedResult();
    });

    test("when the server fails after ready but before any audio left", () async {
      await holdLive();
      hear(_ready);
      await pumpEventQueue();
      hear(_serverError);
      await pumpEventQueue();

      expectFellBack();
      await expectRecordedResult();
    });

    test("when the frames fail before any audio left", () async {
      await holdLive();
      frames.addError(VoiceCaptureError.failed(innerError: StateError("format changed")));
      await pumpEventQueue();

      expectFellBack();
      await expectRecordedResult();
    });

    test("when ready takes longer than the held audio may grow", () async {
      await holdLive();
      for (var second = 0; second < 30; second++) {
        frames.add(Uint8List(32000));
      }
      await pumpEventQueue();
      expect(events.whereType<VoiceLiveFellBack>(), isEmpty, reason: "Exactly the bound is still within it.");

      frames.add(_frame(fill: 1));
      await pumpEventQueue();

      expectFellBack();
      expect(sentAfterStart(), isEmpty);
      await expectRecordedResult();
    });

    test("when the microphone cannot stream, closing the socket and reporting no live event", () async {
      when(capture.startPcmStream).thenThrow(VoiceCaptureError.failed(innerError: StateError("no pcm")));
      session = await createSession();

      await service.start(session: session);
      channel.upgrade.complete();
      await pumpEventQueue();

      verify(capture.cancel).called(1);
      verify(capture.start).called(1);
      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), isEmpty);
      expect(events, isEmpty);
      expect(service.livePresentation(session: session), isNull);
      await expectRecordedResult();
    });

    test("not when the microphone permission is denied, and the socket closes", () async {
      when(capture.startPcmStream).thenThrow(VoiceCaptureError.permissionDenied(innerError: null));
      session = await createSession();

      await expectLater(service.start(session: session), throwsA(isA<MicrophonePermissionDeniedError>()));
      channel.upgrade.complete();
      await pumpEventQueue();

      verifyNever(capture.start);
      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), isEmpty);
    });

    test("a recorder that cannot restart fails the dictation", () async {
      when(capture.start).thenThrow(VoiceCaptureError.failed(innerError: StateError("busy")));
      await holdLive();
      hear(_serverError);
      await pumpEventQueue();

      expect(events.single, isA<VoiceLiveFailed>().having((e) => e.error, "error", isA<RecordingFailedError>()));
      await expectLater(service.stopAndTranscribe(session: session), throwsA(isA<NotRecordingError>()));
    });

    test("a release while the recorder restarts waits for it and transcribes what it caught", () async {
      final restart = Completer<void>();
      when(capture.start).thenAnswer((_) => restart.future);
      await holdLive();
      hear(_serverError);
      await pumpEventQueue();

      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      verifyNever(capture.stop);

      restart.complete();
      final ended = await result;
      verify(capture.stop).called(1);
      expect(ended.outcome, VoiceDictationOutcome.interrupted);
      expect(ended.mode, VoiceDictationMode.afterRecording);
    });

    test("a cancel while the recorder restarts leaves nothing running", () async {
      final restart = Completer<void>();
      when(capture.start).thenAnswer((_) => restart.future);
      await holdLive();
      hear(_serverError);
      await pumpEventQueue();

      await service.cancel(session: session);
      clearInteractions(capture);
      restart.complete();
      await pumpEventQueue();

      verify(capture.cancel).called(1);
      expect(events.whereType<VoiceLiveFellBack>(), isEmpty);
      await expectLater(service.stopAndTranscribe(session: session), throwsA(isA<NotRecordingError>()));
    });
  });

  group("the socket starts with the microphone", () {
    late Completer<Stream<Uint8List>> micStarting;
    late Future<void> start;

    setUp(() {
      micStarting = Completer<Stream<Uint8List>>();
      when(capture.startPcmStream).thenAnswer((_) => micStarting.future);
    });

    Future<void> holdWithMicStarting() async {
      session = await createSession();
      start = service.start(session: session);
      await pumpEventQueue();
    }

    void expectOneSocket() {
      verify(
        () => repository.openRealtime(
          sampleRate: voiceCapturePcmSampleRate,
          projectKey: null,
        ),
      ).called(1);
    }

    test("and only after any prewarm has settled, as the microphone does", () async {
      final prewarm = Completer<void>();
      final platform = _MockVoiceCapture();
      when(platform.createSession).thenReturn(capture);
      when(platform.prewarm).thenAnswer((_) => prewarm.future);
      service = VoiceTranscriptionService(
        repository: repository,
        projectRepository: _MockProjectRepository(),
        voiceModeRepository: voiceModeRepository,
        capture: platform,
        connectionService: connectionService,
      );
      session = await createSession();
      unawaited(service.prewarm(session: session));

      start = service.start(session: session);
      await pumpEventQueue();
      expectNoSocket();
      verifyNever(capture.startPcmStream);

      prewarm.complete();
      await pumpEventQueue();
      expectOneSocket();
      verify(capture.startPcmStream).called(1);

      micStarting.complete(frames.stream);
      await start;
    });

    test("before the microphone is up, and doesn't open a second one once it is", () async {
      await holdWithMicStarting();
      verify(capture.startPcmStream).called(1);
      expect(micStarting.isCompleted, isFalse);
      channel.upgrade.complete();
      await pumpEventQueue();
      expect(channel.outbound, hasLength(1), reason: "`start` is out while the microphone still starts.");

      micStarting.complete(frames.stream);
      await start;
      await pumpEventQueue();

      expectOneSocket();
      expect(channel.sinkCloseCode, isNull);
    });

    test("a microphone that fails closes the open socket and falls back as before", () async {
      await holdWithMicStarting();
      channel.upgrade.complete();
      await pumpEventQueue();
      hear(_ready);
      await pumpEventQueue();

      micStarting.completeError(VoiceCaptureError.failed(innerError: StateError("no pcm")));
      await start;
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), [realtimeVoiceCancelFrame], reason: "No audio, and a streaming server is told.");
      verifyInOrder([capture.cancel, capture.start]);
      expect(events, isEmpty);
      final result = await service.stopAndTranscribe(session: session);
      expect(result.mode, VoiceDictationMode.afterRecording);
      expect(result.outcome, VoiceDictationOutcome.interrupted);
    });

    test("a microphone that fails while the socket still connects closes it once it opens", () async {
      await holdWithMicStarting();

      micStarting.completeError(VoiceCaptureError.failed(innerError: StateError("no pcm")));
      await start;
      verify(capture.start).called(1);
      expect(channel.sinkCloseCode, isNull);

      channel.upgrade.complete();
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), isEmpty);
    });

    test("a denied permission closes the open socket and goes up as itself", () async {
      await holdWithMicStarting();
      channel.upgrade.complete();
      await pumpEventQueue();

      micStarting.completeError(VoiceCaptureError.permissionDenied(innerError: null));
      await expectLater(start, throwsA(isA<MicrophonePermissionDeniedError>()));
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
      verifyNever(capture.start);
      expect(events, isEmpty);
    });

    test("a denied permission with a socket that also fails to open reports only the denial", () async {
      await holdWithMicStarting();
      channel.upgrade.completeError(StateError("no route"));
      await pumpEventQueue();

      micStarting.completeError(VoiceCaptureError.permissionDenied(innerError: null));
      await expectLater(start, throwsA(isA<MicrophonePermissionDeniedError>()));
      await pumpEventQueue();

      verifyNever(capture.start);
    });

    test("a cancel while both start closes the socket once it opens", () async {
      await holdWithMicStarting();

      await service.cancel(session: session);
      micStarting.complete(frames.stream);
      await expectLater(start, throwsA(isA<TranscriptionCancelledError>()));
      channel.upgrade.complete();
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), isEmpty);
      expect(frames.hasListener, isFalse);
    });

    test("closing the composer while both start closes the socket", () async {
      await holdWithMicStarting();
      channel.upgrade.complete();
      await pumpEventQueue();

      final closed = service.close(session: session);
      micStarting.complete(frames.stream);
      await expectLater(start, throwsA(isA<TranscriptionCancelledError>()));
      await closed;
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
    });

    group("a hold the composer drops once the start settles", () {
      test("before the upgrade finishes sends nothing", () async {
        await holdWithMicStarting();
        micStarting.complete(frames.stream);
        await start;

        await service.cancel(session: session);
        channel.upgrade.complete();
        await pumpEventQueue();

        expect(channel.sinkCloseCode, isNotNull);
        expect(sentAfterStart(), isEmpty);
      });

      test("before ready sends no audio", () async {
        await holdWithMicStarting();
        channel.upgrade.complete();
        await pumpEventQueue();
        micStarting.complete(frames.stream);
        await start;
        frames.add(_frame(fill: 1));
        await pumpEventQueue();

        await service.cancel(session: session);
        await pumpEventQueue();

        expect(channel.sinkCloseCode, isNotNull);
        expect(sentAfterStart(), isEmpty);
      });

      test("after ready sends only cancel when no frame has come", () async {
        await holdWithMicStarting();
        channel.upgrade.complete();
        await pumpEventQueue();
        hear(_ready);
        await pumpEventQueue();
        micStarting.complete(frames.stream);
        await start;

        await service.cancel(session: session);
        await pumpEventQueue();

        expect(channel.sinkCloseCode, isNotNull);
        expect(sentAfterStart(), [realtimeVoiceCancelFrame]);
        expect(events, isEmpty);
      });

      test("after ready has already forwarded the frames that came, and hands nothing over", () async {
        await holdWithMicStarting();
        channel.upgrade.complete();
        await pumpEventQueue();
        hear(_ready);
        await pumpEventQueue();
        micStarting.complete(frames.stream);
        await start;
        await pumpEventQueue();
        frames.add(_frame(fill: 1));
        await pumpEventQueue();

        await service.cancel(session: session);
        await pumpEventQueue();

        expect(channel.sinkCloseCode, isNotNull);
        expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceCancelFrame]);
        expect(events, isEmpty);
      });
    });

    test("a socket that cannot open while the microphone starts falls back once it is up", () async {
      await holdWithMicStarting();
      channel.upgrade.completeError(StateError("no route"));
      await pumpEventQueue();
      verifyNever(capture.start);

      micStarting.complete(frames.stream);
      await start;
      await pumpEventQueue();

      expect(events.whereType<VoiceLiveFellBack>(), hasLength(1));
      verifyInOrder([capture.cancel, capture.start]);
      expect(frames.hasListener, isFalse);
      expect((await service.stopAndTranscribe(session: session)).mode, VoiceDictationMode.afterRecording);
    });

    test("a server that fails while the microphone starts falls back once it is up, socket closed", () async {
      await holdWithMicStarting();
      channel.upgrade.complete();
      await pumpEventQueue();
      hear(_ready);
      hear(_audioTimeout);
      await pumpEventQueue();
      expect(channel.sinkCloseCode, isNotNull);
      verifyNever(capture.start);

      micStarting.complete(frames.stream);
      await start;
      await pumpEventQueue();

      expect(events.whereType<VoiceLiveFellBack>(), hasLength(1));
      verifyInOrder([capture.cancel, capture.start]);
      expect(sentAfterStart(), isEmpty);
    });

    test("a socket failing while the microphone starts leaves the composer recording", () async {
      session = await createSession();
      final cubit = VoiceInputCubit(service: service, session: session);
      addTearDown(cubit.close);
      final starting = cubit.startRecording();
      await pumpEventQueue();
      channel.upgrade.completeError(StateError("no route"));
      await pumpEventQueue();

      micStarting.complete(frames.stream);
      await starting;
      await pumpEventQueue();

      expect(cubit.state, isA<VoiceInputRecording>());
      verify(capture.start).called(1);
    });

    group("ready before the microphone is up", () {
      test("waits for the run, then the first frames go out in order", () async {
        await holdWithMicStarting();
        channel.upgrade.complete();
        await pumpEventQueue();
        hear(_ready);
        await pumpEventQueue();

        frames.add(_frame(fill: 1));
        frames.add(_frame(fill: 2));
        micStarting.complete(frames.stream);
        await start;
        await pumpEventQueue();
        frames.add(_frame(fill: 3));
        await pumpEventQueue();

        expect(sentAfterStart(), [_frame(fill: 1), _frame(fill: 2), _frame(fill: 3)]);
        expect(service.livePresentation(session: session), VoiceLivePresentation.panel);
      });

      test("words and the release work as they always have", () async {
        await holdWithMicStarting();
        channel.upgrade.complete();
        await pumpEventQueue();
        hear(_ready);
        await pumpEventQueue();
        micStarting.complete(frames.stream);
        await start;
        await pumpEventQueue();
        frames.add(_frame(fill: 1));
        await pumpEventQueue();

        hear(_words(confirmed: "heard ", provisional: ""));
        final result = service.stopAndTranscribe(session: session);
        await pumpEventQueue();
        expect(sentAfterStart(), [_frame(fill: 1), realtimeVoiceFinishFrame]);
        hear(_finished);

        expect((await result).transcript, "heard");
      });

      test("needs no pacing and stays behind real time on the server's clock, which started at ready", () {
        const bytesPerTick = 3200;
        const bytesPerSecond = 32000;
        fakeAsync((async) {
          // As in the slow start tests: these have to belong to fake time.
          channel = FakeRealtimeVoiceChannel();
          frames = StreamController<Uint8List>(onCancel: () async {});
          micStarting = Completer<Stream<Uint8List>>();
          unawaited(holdWithMicStarting());
          async.elapse(Duration.zero);
          channel.upgrade.complete();
          async.elapse(Duration.zero);

          hear(_ready);
          async.elapse(Duration.zero);
          final readyAt = async.elapsed;
          var sentBytes = 0;
          var mostAhead = -const Duration(days: 1);
          channel.onOutbound = ({required data}) {
            if (data is! Uint8List) return;
            sentBytes += data.length;
            final sent = Duration(microseconds: sentBytes * 1000000 ~/ bytesPerSecond);
            final ahead = sent - (async.elapsed - readyAt);
            if (ahead > mostAhead) mostAhead = ahead;
          };

          async.elapse(const Duration(seconds: 3));
          micStarting.complete(frames.stream);
          async.elapse(Duration.zero);
          for (var tick = 0; tick < 50; tick++) {
            frames.add(Uint8List(bytesPerTick));
            async.elapse(Duration.zero);
            expect(async.periodicTimerCount, 0, reason: "Nothing waited, so nothing paces.");
            async.elapse(const Duration(milliseconds: 100));
          }

          expect(sentBytes, 50 * bytesPerTick);
          // The first frame is a tenth of a second of audio, sent three seconds after ready.
          expect(mostAhead, const Duration(milliseconds: -2900), reason: "Behind by the microphone's delay.");
          expect(channel.sinkCloseCode, isNull);
        });
      });
    });
  });

  group("failing once audio has left (D20)", () {
    test("with the finger down, hands over everything heard as interrupted", () async {
      await holdStreaming();
      hear(_words(confirmed: "confirmed ", provisional: "tentative"));
      hear(_serverError);
      await pumpEventQueue();

      expect(
        events.last,
        isA<VoiceLiveEnded>()
            .having((e) => e.transcript, "transcript", "confirmed tentative")
            .having((e) => e.outcome, "outcome", VoiceDictationOutcome.interrupted),
      );
      verifyNever(capture.start);
      verify(capture.cancel).called(1);
      await expectLater(service.stopAndTranscribe(session: session), throwsA(isA<NotRecordingError>()));
    });

    test("with the finger down and no words, fails without recording", () async {
      await holdStreaming();
      hear(_serverError);
      await pumpEventQueue();

      expect(events.single, isA<VoiceLiveFailed>().having((e) => e.error, "error", isA<RetryableServerVoiceError>()));
      verifyNever(capture.start);
    });

    test("after a release, returns everything heard as interrupted", () async {
      await holdStreaming();
      hear(_words(confirmed: "confirmed ", provisional: "tentative"));
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_serverError);

      final ended = await result;
      expect(ended.transcript, "confirmed tentative");
      expect(ended.outcome, VoiceDictationOutcome.interrupted);
      expect(ended.mode, VoiceDictationMode.live);
    });

    test("after a release with no words, throws what failed", () async {
      await holdStreaming();
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_serverError);

      await expectLater(result, throwsA(isA<RetryableServerVoiceError>()));
      verifyNever(capture.start);
    });

    test("the socket dropping counts as the same failure", () async {
      await holdStreaming();
      hear(_words(confirmed: "kept", provisional: ""));
      await pumpEventQueue();
      await channel.inbound.close();
      await pumpEventQueue();

      expect(events.last, isA<VoiceLiveEnded>().having((e) => e.outcome, "outcome", VoiceDictationOutcome.interrupted));
    });
  });

  group("the server's limits", () {
    for (final (name, frame) in const [("session", _sessionLimit), ("quota", _quotaLimit)]) {
      test("the $name limit with the finger down hands over the confirmed words", () async {
        await holdStreaming();
        hear(_words(confirmed: "limited ", provisional: "lost"));
        hear(frame);
        await pumpEventQueue();

        expect(
          events.last,
          isA<VoiceLiveEnded>()
              .having((e) => e.transcript, "transcript", "limited")
              .having((e) => e.outcome, "outcome", VoiceDictationOutcome.limitReached),
        );
        verify(capture.cancel).called(1);
      });
    }

    test("a limit with no words ends quietly rather than as an error", () async {
      await holdStreaming();
      hear(_quotaLimit);
      await pumpEventQueue();

      expect(
        events.single,
        isA<VoiceLiveEnded>()
            .having((e) => e.transcript, "transcript", isEmpty)
            .having((e) => e.outcome, "outcome", VoiceDictationOutcome.limitReached),
      );
    });

    test("the client's fifteen minute limit fires while live", () {
      fakeAsync((async) {
        var limitReached = 0;
        late VoiceTranscriptionSession created;
        unawaited(() async {
          created = service.createSession(projectId: null, allowLive: true);
          service.maxDurationReachedStream(session: created).listen((_) => limitReached++);
          await pumpEventQueue();
          await service.start(session: created);
        }());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        expect(service.livePresentation(session: created), isNotNull);
        async.elapse(maxRecordingDuration);
        expect(limitReached, 1);
      });
    });
  });

  group("cancelling", () {
    test("during the start stops the microphone and closes the socket", () async {
      final starting = Completer<Stream<Uint8List>>();
      when(capture.startPcmStream).thenAnswer((_) => starting.future);
      session = await createSession();

      final start = service.start(session: session);
      channel.upgrade.complete();
      await pumpEventQueue();
      await service.cancel(session: session);
      clearInteractions(capture);
      starting.complete(frames.stream);

      await expectLater(start, throwsA(isA<TranscriptionCancelledError>()));
      await pumpEventQueue();
      verify(capture.cancel).called(1);
      expect(channel.sinkCloseCode, isNotNull);
      expect(sentAfterStart(), isEmpty);
      expect(service.livePresentation(session: session), isNull);
    });

    test("while the socket connects closes it as soon as it opens", () async {
      session = await createSession();
      await service.start(session: session);

      await service.cancel(session: session);
      channel.upgrade.complete();
      await pumpEventQueue();

      expect(channel.sinkCloseCode, isNotNull);
      expect(events, isEmpty);
    });

    test("while streaming tells the server, releases the microphone and hands nothing over", () async {
      await holdStreaming();
      hear(_words(confirmed: "discarded", provisional: ""));
      await pumpEventQueue();

      await service.cancel(session: session);

      expect(sentAfterStart().last, realtimeVoiceCancelFrame);
      verify(capture.cancel).called(1);
      expect(events.whereType<VoiceLiveEnded>(), isEmpty);
      await expectLater(service.stopAndTranscribe(session: session), throwsA(isA<NotRecordingError>()));
    });

    test("while finishing throws cancelled and hands nothing over", () async {
      await holdStreaming();
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();

      final expectation = expectLater(result, throwsA(isA<TranscriptionCancelledError>()));
      await service.cancel(session: session);
      await expectation;
    });

    test("while the ending still releases the microphone hands nothing over", () async {
      final release = Completer<void>();
      when(capture.cancel).thenAnswer((_) => release.future);
      await holdStreaming();
      final result = service.stopAndTranscribe(session: session);
      await pumpEventQueue();
      hear(_words(confirmed: "too late", provisional: ""));
      hear(_finished);
      await pumpEventQueue();

      final expectation = expectLater(result, throwsA(isA<TranscriptionCancelledError>()));
      final cancelled = service.cancel(session: session);
      release.complete();
      await Future.wait([expectation, cancelled]);
    });

    test("leaves the session ready for another dictation", () async {
      await holdStreaming();
      await service.cancel(session: session);

      channel = FakeRealtimeVoiceChannel();
      frames = StreamController<Uint8List>();
      await service.start(session: session);

      expect(service.livePresentation(session: session), VoiceLivePresentation.panel);
    });
  });

  test("closing mid-dictation releases the socket and the microphone, and reports nothing", () async {
    await holdStreaming();
    hear(_words(confirmed: "discarded", provisional: ""));
    await pumpEventQueue();
    final before = events.length;

    await service.close(session: session);

    expect(channel.sinkCloseCode, isNotNull);
    verify(capture.cancel).called(1);
    verify(capture.close).called(1);
    expect(events, hasLength(before));
  });
}
