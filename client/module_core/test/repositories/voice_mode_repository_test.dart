import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/storage/voice_engine_preference_storage.dart";
import "package:test/test.dart";

class _MockVoiceModeConfigApi() extends Mock implements VoiceModeConfigApi;

class _MockVoiceEnginePreferenceStorage() extends Mock implements VoiceEnginePreferenceStorage;

void main() {
  late _MockVoiceModeConfigApi configApi;
  late _MockVoiceEnginePreferenceStorage engineStorage;
  late VoiceModeRepository repository;

  setUp(() {
    configApi = _MockVoiceModeConfigApi();
    engineStorage = _MockVoiceEnginePreferenceStorage();
    when(engineStorage.read).thenAnswer((_) async => VoiceEngine.remote);
    when(() => engineStorage.write(engine: any(named: "engine"))).thenAnswer((_) async {});
    repository = VoiceModeRepository(configApi: configApi, engineStorage: engineStorage);
    when(configApi.fetchOnDeviceEnabled).thenAnswer((_) async => true);
  });

  setUpAll(() => registerFallbackValue(VoiceEngine.device));

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

  group("engine", () {
    test("is device until the stored pick has been read, and the read happens once", () async {
      expect(repository.engine, VoiceEngine.device);

      await repository.loadEngine();
      await repository.loadEngine();

      expect(repository.engine, VoiceEngine.remote);
      verify(engineStorage.read).called(1);
    });

    test("a load whose Remote Config fails leaves the engine read working", () async {
      when(configApi.fetchLiveEnabled).thenThrow(StateError("no config"));

      await expectLater(repository.load(), throwsStateError);
      await repository.loadEngine();

      expect(repository.engine, VoiceEngine.remote);
    });

    test("a pick made during the first read survives it, and is persisted", () async {
      final read = Completer<VoiceEngine>();
      when(engineStorage.read).thenAnswer((_) => read.future);
      unawaited(repository.loadEngine());

      final picking = repository.setEngine(engine: VoiceEngine.remote);
      read.complete(VoiceEngine.remote);
      await picking;

      expect(repository.engine, VoiceEngine.remote);
      verify(() => engineStorage.write(engine: VoiceEngine.remote)).called(1);
    });
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
