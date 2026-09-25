import "dart:io";

import "package:drift/native.dart";
import "package:get_it/get_it.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_persistence/src/api/persister_api.dart";
import "package:test/test.dart";

void main() {
  test("typed primitive tables preserve absence, false, updates and key-local deletion", () async {
    final database = PersistenceDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = PersisterApi(database: database);
    expect(await api.readString(key: "first"), isNull);
    expect(await api.readBool(key: "first"), isNull);
    await api.writeString(key: "first", value: "before");
    await api.writeString(key: "second", value: "retained");
    await api.writeBool(key: "first", value: true);
    await api.writeString(key: "first", value: "after");
    await api.writeBool(key: "first", value: false);
    expect(await api.readString(key: "first"), "after");
    expect(await api.readBool(key: "first"), isFalse);
    await api.deleteString(key: "first");
    expect(await api.readString(key: "first"), isNull);
    expect(await api.readString(key: "second"), "retained");
    expect(await api.readBool(key: "first"), isFalse);
    await api.deleteBool(key: "first");
    expect(await api.readBool(key: "first"), isNull);
  });

  test("file open is lazy, enables WAL and keeps scopes separate across reopen", () async {
    final directory = Directory.systemTemp.createTempSync("sesori-storage-scope-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final platform = _FixtureDirectory(directory: directory);
    for (final scope in PersistenceScope.values) {
      final database = PersistenceDatabase.open(persistenceDirectory: platform, scope: scope);
      final api = PersisterApi(database: database);
      final before = platform.resolutions;
      try {
        expect(await api.readString(key: "scope"), isNull);
        expect(platform.resolutions, before + 1);
        final journal = await database.customSelect("PRAGMA journal_mode").getSingle();
        expect(journal.read<String>("journal_mode"), "wal");
        await api.writeString(key: "scope", value: scope.storageId);
      } finally {
        await database.close();
      }
    }
    for (final scope in PersistenceScope.values) {
      final database = PersistenceDatabase.open(persistenceDirectory: platform, scope: scope);
      try {
        expect(await PersisterApi(database: database).readString(key: "scope"), scope.storageId);
      } finally {
        await database.close();
      }
    }
  });

  test("GetIt owns lazy database construction and closes it on graph reset", () async {
    final directory = Directory.systemTemp.createTempSync("sesori-storage-disposal-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final platform = _FixtureDirectory(directory: directory);
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<PersistenceDirectory>(platform)
      ..registerSingleton<PersistenceScope>(PersistenceScope.development);
    addTearDown(getIt.reset);
    configurePersistenceDependencies(getIt: getIt);
    expect(platform.resolutions, 0);
    final database = getIt<PersistenceDatabase>();
    expect(getIt<PersistenceDatabase>(), same(database));
    expect(getIt<StorageCipher>(), same(getIt<StorageCipher>()));
    expect(getIt<PersisterRepository>(), same(getIt<PersisterRepository>()));
    expect(platform.resolutions, 0);
    final repository = getIt<PersisterRepository>();
    await repository.writeBool(key: _BoolKey.fixture, value: true);
    expect(await repository.readBool(key: _BoolKey.fixture), isTrue);
    expect(platform.resolutions, 1);
    expect(getIt.isRegistered<MasterKeyStore>(), isFalse);
    await getIt.reset();
    await expectLater(repository.readBool(key: _BoolKey.fixture), throwsA(anything));
  });
}

enum _BoolKey({@override required final String storageKey}) implements BoolPersistenceKey {
  fixture(storageKey: "fixture"),
}

class _FixtureDirectory({required final Directory directory}) implements PersistenceDirectory {
  int resolutions = 0;

  @override
  Future<Directory> resolve() async {
    resolutions++;
    return directory;
  }
}
