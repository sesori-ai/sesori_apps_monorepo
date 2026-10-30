import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MemoryPersister() extends Fake implements PersisterRepository {
  final values = <String, String>{};

  @override
  Future<String?> readString({required StringPersistenceKey key}) async => values[key.storageKey];

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    values[key.storageKey] = value;
  }
}

void main() {
  late _MemoryPersister persister;
  late FounderCallStorage storage;

  setUp(() {
    persister = _MemoryPersister();
    storage = FounderCallStorage(persister: persister);
  });

  test("round-trips armed and retired progress as versioned device-scoped JSON", () async {
    await storage.write(progress: const FounderCallArmed());
    expect(jsonDecode(persister.values["founder_call_v1"] ?? ""), {"version": 1, "kind": "armed"});
    expect(await storage.read(), isA<FounderCallArmed>());

    await storage.write(progress: const FounderCallRetired());
    expect(jsonDecode(persister.values["founder_call_v1"] ?? ""), {"version": 1, "kind": "retired"});
    expect(await storage.read(), isA<FounderCallRetired>());
  });

  test("reads another version or an unknown kind as never armed", () async {
    for (final stored in [
      {"version": 2, "kind": "armed"},
      {"version": 1, "kind": "card"},
    ]) {
      persister.values["founder_call_v1"] = jsonEncode(stored);
      expect(await storage.read(), isNull);
    }
  });
}
