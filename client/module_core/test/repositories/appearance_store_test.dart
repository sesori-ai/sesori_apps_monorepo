import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MockPersister() extends Mock implements PersisterRepository;

void main() {
  late _MockPersister storage;
  late AppearanceStore store;

  setUp(() {
    storage = _MockPersister();
    store = AppearanceStore(persister: storage);
  });

  test("reads back a persisted mode", () async {
    when(
      () => storage.writeString(
        key: StringPreferenceKey.appearanceMode,
        value: any(named: "value"),
      ),
    ).thenAnswer((_) async {});
    await store.write(mode: AppearanceMode.dark);

    final stored =
        verify(
              () => storage.writeString(
                key: StringPreferenceKey.appearanceMode,
                value: captureAny(named: "value"),
              ),
            ).captured.single
            as String;
    when(() => storage.readString(key: StringPreferenceKey.appearanceMode)).thenAnswer((_) async => stored);

    expect(await store.read(), AppearanceMode.dark);
  });

  test("falls back to system when nothing is stored", () async {
    when(() => storage.readString(key: StringPreferenceKey.appearanceMode)).thenAnswer((_) async => null);

    expect(await store.read(), AppearanceMode.system);
  });

  test("falls back to system when the stored value is unknown", () async {
    when(() => storage.readString(key: StringPreferenceKey.appearanceMode)).thenAnswer((_) async => "sepia");

    expect(await store.read(), AppearanceMode.system);
  });

  test("falls back to system when storage fails", () async {
    when(() => storage.readString(key: StringPreferenceKey.appearanceMode)).thenThrow(Exception("SQL unavailable"));

    expect(await store.read(), AppearanceMode.system);
  });
}
