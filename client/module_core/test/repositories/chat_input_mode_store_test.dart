import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MockPersister() extends Mock implements PersisterRepository;

void main() {
  late _MockPersister storage;
  late ChatInputModeStore store;

  setUp(() {
    storage = _MockPersister();
    store = ChatInputModeStore(persister: storage);
  });

  test("reads back a persisted mode", () async {
    when(
      () => storage.writeString(
        key: StringPreferenceKey.chatInputMode,
        value: any(named: "value"),
      ),
    ).thenAnswer((_) async {});
    await store.write(mode: ChatInputMode.textFirst);

    final stored =
        verify(
              () => storage.writeString(
                key: StringPreferenceKey.chatInputMode,
                value: captureAny(named: "value"),
              ),
            ).captured.single
            as String;
    when(() => storage.readString(key: StringPreferenceKey.chatInputMode)).thenAnswer((_) async => stored);

    expect(await store.read(), ChatInputMode.textFirst);
  });

  test("falls back to voice-first when nothing is stored", () async {
    when(() => storage.readString(key: StringPreferenceKey.chatInputMode)).thenAnswer((_) async => null);

    expect(await store.read(), ChatInputMode.voiceFirst);
  });

  test("falls back to voice-first when the stored value is unknown", () async {
    when(() => storage.readString(key: StringPreferenceKey.chatInputMode)).thenAnswer((_) async => "telepathy");

    expect(await store.read(), ChatInputMode.voiceFirst);
  });

  test("falls back to voice-first when storage fails", () async {
    when(() => storage.readString(key: StringPreferenceKey.chatInputMode)).thenThrow(Exception("SQL unavailable"));

    expect(await store.read(), ChatInputMode.voiceFirst);
  });
}
