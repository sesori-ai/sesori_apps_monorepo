import "dart:async";
import "dart:typed_data";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/on_device_speech_api.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_client.dart";
import "package:test/test.dart";

class _MockVoiceApi() extends Mock implements VoiceApi;

class _MockRealtimeVoiceClient() extends Mock implements RealtimeVoiceClient;

class _MockOnDeviceSpeechApi() extends Mock implements OnDeviceSpeechApi;


final class _FakeSession() implements OnDeviceSpeechSession {
  final StreamController<OnDeviceSpeechEvent> controller = StreamController<OnDeviceSpeechEvent>();
  final List<Uint8List> sent = [];
  int finishCalls = 0;
  int cancelCalls = 0;

  @override
  Stream<OnDeviceSpeechEvent> get events => controller.stream;

  @override
  void sendAudio({required Uint8List frame}) => sent.add(frame);

  @override
  void finish() => finishCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}

void main() {
  late _MockOnDeviceSpeechApi api;
  late _FakeSession session;
  late VoiceRepository repository;
  final frame = Uint8List.fromList([1, 2]);

  setUpAll(() => registerFallbackValue(VoiceRealtimeSampleRate.hz16000));

  setUp(() {
    api = _MockOnDeviceSpeechApi();
    session = _FakeSession();
    when(() => api.open(sampleRate: any(named: "sampleRate"))).thenAnswer((_) async => session);
    repository = VoiceRepository(
      api: _MockVoiceApi(),
      realtimeClient: _MockRealtimeVoiceClient(),
      onDeviceSpeechApi: api,
    );
  });

  Future<VoiceRealtimeConnection> open() => repository.openOnDevice(sampleRate: VoiceRealtimeSampleRate.hz16000);

  test("is ready at once, and spaces the engine's bare words so they join up", () async {
    final connection = await open();
    final events = <VoiceRealtimeEvent>[];
    connection.events.listen(events.add);

    session.controller
      ..add(const OnDeviceSpeechWords(confirmedDelta: "", provisional: "hel"))
      ..add(const OnDeviceSpeechWords(confirmedDelta: " Hello there. ", provisional: ""))
      ..add(const OnDeviceSpeechWords(confirmedDelta: "", provisional: "how"))
      ..add(const OnDeviceSpeechWords(confirmedDelta: "How are you?", provisional: ""))
      ..add(const OnDeviceSpeechCompleted());
    await pumpEventQueue();

    expect(events.first, isA<VoiceRealtimeReady>());
    final words = events.whereType<VoiceRealtimeWords>().toList();
    expect(words.map((event) => event.provisional), ["hel", "", " how", ""]);
    expect(words.map((event) => event.confirmedDelta).join(), "Hello there. How are you?");
    expect(events.last, isA<VoiceRealtimeCompleted>());
  });

  test("adds no space before Chinese or Japanese, which don't use them", () async {
    final connection = await open();
    final events = <VoiceRealtimeEvent>[];
    connection.events.listen(events.add);

    session.controller
      ..add(const OnDeviceSpeechWords(confirmedDelta: "こんにちは。", provisional: ""))
      ..add(const OnDeviceSpeechWords(confirmedDelta: "元気ですか", provisional: ""))
      ..add(const OnDeviceSpeechCompleted());
    await pumpEventQueue();

    final words = events.whereType<VoiceRealtimeWords>();
    expect(words.map((event) => event.confirmedDelta).join(), "こんにちは。元気ですか");
  });

  test("an engine failure is a recording failure that keeps its reason, so nothing offers a retry", () async {
    final connection = await open();
    final events = <VoiceRealtimeEvent>[];
    connection.events.listen(events.add);

    session.controller.add(const OnDeviceSpeechFailed(cause: "model gone"));
    await pumpEventQueue();

    final failure = events.last;
    expect(failure, isA<VoiceRealtimeFailed>());
    final error = (failure as VoiceRealtimeFailed).error;
    expect(error, isA<RecordingFailedError>());
    expect((error as RecordingFailedError).innerError, "model gone");
    expect(connection.sendAudio(frame: frame), isFalse);
  });

  test("an engine stream that closes without an ending fails rather than hanging", () async {
    final connection = await open();
    final events = <VoiceRealtimeEvent>[];
    connection.events.listen(events.add);

    await session.controller.close();
    await pumpEventQueue();

    expect(events.last, isA<VoiceRealtimeFailed>());
  });

  test("an engine that stops answering after the last audio fails rather than hanging", () {
    fakeAsync((async) {
      late VoiceRealtimeConnection connection;
      unawaited(open().then((opened) => connection = opened));
      async.flushMicrotasks();
      final events = <VoiceRealtimeEvent>[];
      connection.events.listen(events.add);

      connection.finish();
      async.elapse(const Duration(seconds: 14));
      expect(events.whereType<VoiceRealtimeFailed>(), isEmpty);

      async.elapse(const Duration(seconds: 2));
      expect(events.whereType<VoiceRealtimeFailed>(), hasLength(1));
      expect(session.cancelCalls, 1);
    });
  });

  test("cancelling stops the engine even when nothing ever listened", () async {
    final connection = await open();

    await connection.cancel();

    expect(session.cancelCalls, 1);
    expect(connection.sendAudio(frame: frame), isFalse);
  });

  test("a start that fails is a recording failure, so the dictation can fall back", () async {
    when(() => api.open(sampleRate: any(named: "sampleRate"))).thenAnswer((_) async => throw StateError("busy"));

    await expectLater(open(), throwsA(isA<RecordingFailedError>()));
  });

  test("a start that comes too late fails at once, and its engine is stopped when it arrives", () {
    fakeAsync((async) {
      final opening = Completer<OnDeviceSpeechSession>();
      when(() => api.open(sampleRate: any(named: "sampleRate"))).thenAnswer((_) => opening.future);
      Object? failure;
      unawaited(
        open()
            .catchError((Object error) {
              failure = error;
              return Future<VoiceRealtimeConnection>.error(error);
            })
            .then<void>((_) {}, onError: (_) {}),
      );

      async.elapse(const Duration(seconds: 6));
      expect(failure, isA<RecordingFailedError>());

      opening.complete(session);
      async.flushMicrotasks();
      expect(session.cancelCalls, 1);
    });
  });

  test("a check that fails answers false instead of throwing", () async {
    when(api.prepare).thenAnswer((_) async => throw StateError("channel"));

    expect(await repository.prepareOnDevice(), isFalse);
  });
}
