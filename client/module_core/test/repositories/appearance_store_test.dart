import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late AppearanceStore store;

  setUp(() {
    storage = _MockSecureStorage();
    store = AppearanceStore(secureStorage: storage);
  });

  test("reads back a persisted mode", () async {
    when(() => storage.write(key: any(named: "key"), value: any(named: "value"))).thenAnswer((_) async {});
    await store.write(mode: AppearanceMode.dark);

    final stored = verify(
      () => storage.write(key: any(named: "key"), value: captureAny(named: "value")),
    ).captured.single as String;
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => stored);

    expect(await store.read(), AppearanceMode.dark);
  });

  test("falls back to system when nothing is stored", () async {
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => null);

    expect(await store.read(), AppearanceMode.system);
  });

  test("falls back to system when the stored value is unknown", () async {
    when(() => storage.read(key: any(named: "key"))).thenAnswer((_) async => "sepia");

    expect(await store.read(), AppearanceMode.system);
  });

  test("falls back to system when storage fails", () async {
    when(() => storage.read(key: any(named: "key"))).thenThrow(Exception("keychain locked"));

    expect(await store.read(), AppearanceMode.system);
  });
}
