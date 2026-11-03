import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockVoiceModeConfigApi() extends Mock implements VoiceModeConfigApi;

void main() {
  late _MockVoiceModeConfigApi configApi;
  late VoiceModeRepository repository;

  setUp(() {
    configApi = _MockVoiceModeConfigApi();
    repository = VoiceModeRepository(configApi: configApi);
    when(configApi.fetchOnDeviceEnabled).thenAnswer((_) async => true);
  });

  void answerLiveEnabled({required bool liveEnabled}) =>
      when(configApi.fetchLiveEnabled).thenAnswer((_) async => liveEnabled);

  test("on-device stays off until a load has answered, then follows the kill switch", () async {
    answerLiveEnabled(liveEnabled: false);
    expect(repository.onDeviceEnabled, isFalse);

    await repository.load();
    expect(repository.onDeviceEnabled, isTrue);

    when(configApi.fetchOnDeviceEnabled).thenAnswer((_) async => false);
    await repository.load();
    expect(repository.onDeviceEnabled, isFalse);
  });

  test("live on gives live", () async {
    answerLiveEnabled(liveEnabled: true);

    await repository.load();

    expect(repository.mode, isA<VoiceModeLive>());
  });

  test("live off gives after-recording", () async {
    answerLiveEnabled(liveEnabled: false);

    await repository.load();

    expect(repository.mode, isA<VoiceModeAfterRecording>());
  });

  group("caching", () {
    test("reports after-recording before any load", () {
      expect(repository.mode, isA<VoiceModeAfterRecording>());
      verifyNever(configApi.fetchLiveEnabled);
    });

    test("reports after-recording while the first load is in flight", () async {
      final values = Completer<bool>();
      when(configApi.fetchLiveEnabled).thenAnswer((_) => values.future);

      final load = repository.load();

      expect(repository.mode, isA<VoiceModeAfterRecording>());

      values.complete(true);
      await load;

      expect(repository.mode, isA<VoiceModeLive>());
    });

    test("keeps the loaded value without fetching again", () async {
      answerLiveEnabled(liveEnabled: true);

      await repository.load();

      expect(repository.mode, isA<VoiceModeLive>());
      verify(configApi.fetchLiveEnabled).called(1);
    });

    test("a later load replaces the value", () async {
      answerLiveEnabled(liveEnabled: true);
      await repository.load();

      answerLiveEnabled(liveEnabled: false);
      await repository.load();

      expect(repository.mode, isA<VoiceModeAfterRecording>());
    });

    test("a failed load reports its error and keeps the last value", () async {
      answerLiveEnabled(liveEnabled: true);
      await repository.load();

      when(configApi.fetchLiveEnabled).thenThrow(StateError("offline"));

      await expectLater(repository.load(), throwsStateError);
      expect(repository.mode, isA<VoiceModeLive>());
    });
  });
}
