import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockSecureStorage() extends Mock implements SecureStorage;

void main() {
  late _MockSecureStorage storage;
  late ChatInputModeStore store;

  setUp(() {
    storage = _MockSecureStorage();
    store = ChatInputModeStore(secureStorage: storage);
  });

  test("reads back a persisted mode", () async {
    when(() => storage.write(key: any(named: "key"), value: any(named: "value"))).thenAnswer((_) async {});
    await store.write(mode: ChatInputMode.textFirst);

    final stored = verify(
      () => storage.write(key: any(named: "key"), value: captureAny(named: "value")),
    ).captured.single as String;
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => stored);

    expect(await store.read(), ChatInputMode.textFirst);
  });

  test("falls back to voice-first when nothing is stored", () async {
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => null);

    expect(await store.read(), ChatInputMode.voiceFirst);
  });

  test("falls back to voice-first when the stored value is unknown", () async {
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => "telepathy");

    expect(await store.read(), ChatInputMode.voiceFirst);
  });

  test("falls back to voice-first when storage fails", () async {
    when(() => storage.read(key: any(named: "key"))).thenThrow(Exception("keychain locked"));

    expect(await store.read(), ChatInputMode.voiceFirst);
  });
}
