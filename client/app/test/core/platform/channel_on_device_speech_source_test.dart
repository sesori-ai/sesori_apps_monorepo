import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/channel_on_device_speech_source.dart";

const _channel = MethodChannel("com.sesori.app/on-device-speech");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late ChannelOnDeviceSpeechSource source;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls = [];
    source = ChannelOnDeviceSpeechSource();
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return call.method == "prepare" ? true : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  Future<void> nativeSends(Map<String, Object> event) => messenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall("event", event)),
    (_) {},
  );

  Future<OnDeviceSpeechSession> open() => source.open(sampleRate: VoiceRealtimeSampleRate.hz16000);

  test("a build without the native side answers that it can't run", () async {
    messenger.setMockMethodCallHandler(_channel, null);

    expect(await source.prepare(), isFalse);
  });

  test("starts with its session id and the audio rate", () async {
    await open();

    expect(calls.single.method, "start");
    expect(calls.single.arguments, {"sessionId": 1, "sampleRate": 16000});
  });

  test("decodes native events, and ignores those of an older session", () async {
    final session = await open();
    final events = <OnDeviceSpeechEvent>[];
    session.events.listen(events.add);

    await nativeSends({"sessionId": 99, "type": "completed"});
    await nativeSends({"sessionId": 1, "type": "words", "confirmedDelta": "hi", "provisional": "th"});
    await nativeSends({"sessionId": 1, "type": "completed"});
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect((events.first as OnDeviceSpeechWords).confirmedDelta, "hi");
    expect((events.first as OnDeviceSpeechWords).provisional, "th");
    expect(events.last, isA<OnDeviceSpeechCompleted>());
  });

  test("a native failure and an audio frame native refused both arrive as failures", () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == "sendAudio") throw PlatformException(code: "engine");
      return null;
    });
    final session = await open();
    final events = <OnDeviceSpeechEvent>[];
    session.events.listen(events.add);

    session.sendAudio(frame: Uint8List.fromList([1, 2]));
    await pumpEventQueue();

    expect(events.single, isA<OnDeviceSpeechFailed>().having((event) => event.cause, "cause", isA<PlatformException>()));
  });

  test("refuses a second session until the first has ended", () async {
    final first = await open();

    await expectLater(open(), throwsStateError);

    await first.cancel();
    await open();
    expect(calls.where((call) => call.method == "cancel"), hasLength(1));
    expect(calls.last.arguments, {"sessionId": 2, "sampleRate": 16000});
  });

  test("a start native refused leaves the source free", () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == "start") throw PlatformException(code: "start_failed");
      return null;
    });

    await expectLater(open(), throwsA(isA<PlatformException>()));

    messenger.setMockMethodCallHandler(_channel, (call) async => null);
    await open();
  });
}
