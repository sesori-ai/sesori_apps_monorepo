import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

final class _MemorySecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> read({required String key}) async {
    readCount++;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount++;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  final uuidV4Pattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  );

  test("generates and persists a stable UUIDv4", () async {
    final secureStorage = _MemorySecureStorage();
    final storage = NotificationPreferencesDeviceIdStorage(storage: secureStorage);

    final generated = await storage.getOrCreate();
    final cached = await storage.getOrCreate();
    final restored = await NotificationPreferencesDeviceIdStorage(storage: secureStorage).getOrCreate();

    expect(generated, matches(uuidV4Pattern));
    expect(cached, generated);
    expect(restored, generated);
    expect(secureStorage.values.values.single, generated);
    expect(secureStorage.writeCount, 1);
  });

  test("coalesces concurrent first reads", () async {
    final secureStorage = _MemorySecureStorage();
    final storage = NotificationPreferencesDeviceIdStorage(storage: secureStorage);

    final values = await Future.wait(List.generate(4, (_) => storage.getOrCreate()));

    expect(values.toSet(), hasLength(1));
    expect(secureStorage.readCount, 1);
    expect(secureStorage.writeCount, 1);
  });
}
