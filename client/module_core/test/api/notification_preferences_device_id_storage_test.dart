import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

final class _MemoryPersister() extends Fake implements PersisterRepository {
  final Map<String, String> values = {};
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> readString({required StringPersistenceKey key}) async {
    readCount++;
    return values[key.storageKey];
  }

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    writeCount++;
    values[key.storageKey] = value;
  }

  @override
  Future<void> deleteString({required StringPersistenceKey key}) async {
    values.remove(key.storageKey);
  }
}

void main() {
  final uuidV4Pattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  );

  test("generates and persists a stable UUIDv4", () async {
    final persister = _MemoryPersister();
    final storage = NotificationPreferencesDeviceIdStorage(persister: persister);

    final generated = await storage.getOrCreate();
    final cached = await storage.getOrCreate();
    final restored = await NotificationPreferencesDeviceIdStorage(persister: persister).getOrCreate();

    expect(generated, matches(uuidV4Pattern));
    expect(cached, generated);
    expect(restored, generated);
    expect(persister.values.values.single, generated);
    expect(persister.writeCount, 1);
  });

  test("coalesces concurrent first reads", () async {
    final persister = _MemoryPersister();
    final storage = NotificationPreferencesDeviceIdStorage(persister: persister);

    final values = await Future.wait(List.generate(4, (_) => storage.getOrCreate()));

    expect(values.toSet(), hasLength(1));
    expect(persister.readCount, 1);
    expect(persister.writeCount, 1);
  });
}
