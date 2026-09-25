import "package:get_it/get_it.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

void main() {
  late GetIt getIt;
  late _MemoryPrimitiveStorage storage;
  late int platformResolutions;

  PersisterRepository repository() => getIt<PersisterRepository>();

  setUp(() {
    getIt = GetIt.asNewInstance();
    storage = _MemoryPrimitiveStorage();
    platformResolutions = 0;
    getIt.registerLazySingleton<PrimitiveStorage>(() {
      platformResolutions++;
      return storage;
    });
    configurePersistenceDependencies(getIt: getIt);
  });

  tearDown(() => getIt.reset());

  test("DI registration and repository resolution perform no storage I/O", () {
    expect(platformResolutions, 0);
    expect(storage.operationCount, 0);

    final first = repository();
    expect(repository(), same(first));
    expect(platformResolutions, 1);
    expect(storage.operationCount, 0);
    expect(getIt.isRegistered<SecureStorage>(), isFalse);
  });

  test("missing strings stay absent; defaults do not persist a value", () async {
    final persister = repository();
    expect(await persister.readString(key: _StringKey.first), isNull);
    expect(await persister.readStringOrDefault(key: _StringKey.first, defaultValue: "fallback"), "fallback");
    expect(storage.strings, isEmpty);
  });

  test("string operations use the explicit spelling and replace only their key", () async {
    final persister = repository();
    await persister.writeString(key: _StringKey.first, value: "initial");
    await persister.writeString(key: _StringKey.second, value: "retained");
    await persister.writeString(key: _StringKey.first, value: "updated");

    expect(storage.strings, {"fixture.first": "updated", "fixture.second": "retained"});
    expect(await persister.readString(key: _StringKey.first), "updated");
    expect(await persister.readStringOrDefault(key: _StringKey.first, defaultValue: "fallback"), "updated");

    await persister.deleteString(key: _StringKey.first);
    await persister.deleteString(key: _StringKey.first);
    expect(await persister.readString(key: _StringKey.first), isNull);
    expect(await persister.readString(key: _StringKey.second), "retained");
  });

  test("a stored empty string is data, not the missing-value sentinel", () async {
    final persister = repository();
    await persister.writeString(key: _StringKey.first, value: "");
    expect(await persister.readStringOrDefault(key: _StringKey.first, defaultValue: "fallback"), "");
  });

  test("missing bools stay absent and honor both caller defaults", () async {
    final persister = repository();
    expect(await persister.readBool(key: _BoolKey.first), isNull);
    expect(await persister.readBoolOrDefault(key: _BoolKey.first, defaultValue: true), isTrue);
    expect(await persister.readBoolOrDefault(key: _BoolKey.first, defaultValue: false), isFalse);
    expect(storage.bools, isEmpty);
  });

  test("bool operations preserve false, use stable spelling and delete only their key", () async {
    final persister = repository();
    await persister.writeBool(key: _BoolKey.first, value: true);
    await persister.writeBool(key: _BoolKey.second, value: true);
    await persister.writeBool(key: _BoolKey.first, value: false);

    expect(storage.bools, {"fixture.first": false, "fixture.second": true});
    expect(await persister.readBool(key: _BoolKey.first), isFalse);
    expect(await persister.readBoolOrDefault(key: _BoolKey.first, defaultValue: true), isFalse);

    await persister.deleteBool(key: _BoolKey.first);
    await persister.deleteBool(key: _BoolKey.first);
    expect(await persister.readBool(key: _BoolKey.first), isNull);
    expect(await persister.readBool(key: _BoolKey.second), isTrue);
  });

  test("string and bool operations select the corresponding primitive capability", () async {
    final persister = repository();
    await persister.writeString(key: _StringKey.first, value: "string");
    await persister.writeBool(key: _BoolKey.first, value: true);
    await persister.deleteString(key: _StringKey.first);

    expect(await persister.readBool(key: _BoolKey.first), isTrue);
    expect(await persister.readString(key: _StringKey.first), isNull);
  });

  test("immutable scoped keys pass their complete spelling through unchanged", () async {
    final persister = repository();
    const first = _ScopedStringKey(identity: "first / %");
    const second = _ScopedStringKey(identity: "second");
    await persister.writeString(key: first, value: "first value");
    await persister.writeString(key: second, value: "second value");

    expect(storage.strings, {"fixture.scope:first / %": "first value", "fixture.scope:second": "second value"});
    expect(await persister.readString(key: first), "first value");
    await persister.deleteString(key: first);
    expect(await persister.readString(key: second), "second value");
  });

  test("reads see backend changes rather than a repository value cache", () async {
    final persister = repository();
    storage.strings["fixture.first"] = "before";
    storage.bools["fixture.first"] = true;
    expect(await persister.readString(key: _StringKey.first), "before");
    expect(await persister.readBool(key: _BoolKey.first), isTrue);

    storage.strings["fixture.first"] = "after";
    storage.bools["fixture.first"] = false;
    expect(await persister.readString(key: _StringKey.first), "after");
    expect(await persister.readBool(key: _BoolKey.first), isFalse);
  });

  test("all operations preserve backend failures, including reads with defaults", () async {
    final persister = repository();
    final error = StateError("fixture storage unavailable");
    storage.failure = error;

    await expectLater(persister.readString(key: _StringKey.first), throwsA(same(error)));
    await expectLater(
      persister.readStringOrDefault(key: _StringKey.first, defaultValue: "fallback"),
      throwsA(same(error)),
    );
    await expectLater(persister.writeString(key: _StringKey.first, value: "value"), throwsA(same(error)));
    await expectLater(persister.deleteString(key: _StringKey.first), throwsA(same(error)));
    await expectLater(persister.readBool(key: _BoolKey.first), throwsA(same(error)));
    await expectLater(
      persister.readBoolOrDefault(key: _BoolKey.first, defaultValue: false),
      throwsA(same(error)),
    );
    await expectLater(persister.writeBool(key: _BoolKey.first, value: true), throwsA(same(error)));
    await expectLater(persister.deleteBool(key: _BoolKey.first), throwsA(same(error)));
    expect(storage.strings, isEmpty);
    expect(storage.bools, isEmpty);
  });
}

enum _StringKey({@override required final String storageKey}) implements StringPersistenceKey {
  first(storageKey: "fixture.first"),
  second(storageKey: "fixture.second"),
}

enum _BoolKey({@override required final String storageKey}) implements BoolPersistenceKey {
  first(storageKey: "fixture.first"),
  second(storageKey: "fixture.second"),
}

final class const _ScopedStringKey({required final String identity}) implements StringPersistenceKey {
  @override
  String get storageKey => "fixture.scope:$identity";
}

class _MemoryPrimitiveStorage() implements PrimitiveStorage {
  final strings = <String, String>{};
  final bools = <String, bool>{};
  int operationCount = 0;
  Object? failure;

  void _recordOperation() {
    operationCount++;
    if (failure case final Object error) throw error;
  }

  @override
  Future<String?> readString({required String key}) async {
    _recordOperation();
    return strings[key];
  }

  @override
  Future<void> writeString({required String key, required String value}) async {
    _recordOperation();
    strings[key] = value;
  }

  @override
  Future<void> deleteString({required String key}) async {
    _recordOperation();
    strings.remove(key);
  }

  @override
  Future<bool?> readBool({required String key}) async {
    _recordOperation();
    return bools[key];
  }

  @override
  Future<void> writeBool({required String key, required bool value}) async {
    _recordOperation();
    bools[key] = value;
  }

  @override
  Future<void> deleteBool({required String key}) async {
    _recordOperation();
    bools.remove(key);
  }
}
