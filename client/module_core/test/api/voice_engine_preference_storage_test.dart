import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/storage/voice_engine_preference_storage.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MockPersisterRepository() extends Mock implements PersisterRepository;

void main() {
  late _MockPersisterRepository persister;
  late VoiceEnginePreferenceStorage storage;

  setUp(() {
    persister = _MockPersisterRepository();
    storage = VoiceEnginePreferenceStorage(persister: persister);
  });

  void answerRead({required String? stored}) =>
      when(() => persister.readString(key: StringPreferenceKey.voiceEngine)).thenAnswer((_) async => stored);

  for (final engine in VoiceEngine.values) {
    test("reads back ${engine.name}", () async {
      answerRead(stored: engine.storageValue);

      expect(await storage.read(), engine);
    });
  }

  test("nothing stored means device", () async {
    answerRead(stored: null);

    expect(await storage.read(), VoiceEngine.device);
  });

  test("an unknown value means device", () async {
    answerRead(stored: "whisper");

    expect(await storage.read(), VoiceEngine.device);
  });

  test("a failed read means device", () async {
    when(() => persister.readString(key: StringPreferenceKey.voiceEngine)).thenThrow(StateError("locked"));

    expect(await storage.read(), VoiceEngine.device);
  });

  test("a failed write is recovered", () async {
    when(
      () => persister.writeString(key: StringPreferenceKey.voiceEngine, value: "remote"),
    ).thenThrow(StateError("locked"));

    await expectLater(storage.write(engine: VoiceEngine.remote), completes);
  });
}
