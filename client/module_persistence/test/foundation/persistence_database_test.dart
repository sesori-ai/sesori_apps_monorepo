import "dart:convert";
import "dart:io";

import "package:drift/native.dart";
import "package:get_it/get_it.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_persistence/src/api/persister_api.dart";
import "package:sesori_persistence/src/api/secure_storage_api.dart";
import "package:test/test.dart";

import "../fixtures/storage_fixture.dart";

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

  test("primitive clear is atomic and leaves encrypted values/native key alone", () async {
    final database = PersistenceDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = PersisterApi(database: database);
    final native = FixtureMasterKeyStore(value: null);
    final secrets = SecureStorageRepository(
      storageApi: SecureStorageApi(database: database, masterKeyStore: native),
      cipher: StorageCipher(scope: PersistenceScope.production),
    );
    const key = FixtureSecretKey(storageKey: "auth");
    await secrets.write(key: key, value: "retained");
    await api.writeString(key: "theme", value: "dark");
    await api.writeBool(key: "registered", value: false);
    await database.customStatement("""
      CREATE TRIGGER reject_primitive_clear BEFORE DELETE ON bool_values
      BEGIN SELECT RAISE(ABORT, 'fixture clear denied'); END;
    """);
    await expectLater(api.clear(), throwsA(isA<Exception>()));
    expect(await api.readString(key: "theme"), "dark");
    expect(await api.readBool(key: "registered"), false);
    await database.customStatement("DROP TRIGGER reject_primitive_clear");
    await api.clear();
    expect(await api.readString(key: "theme"), isNull);
    expect(await api.readBool(key: "registered"), isNull);
    expect(await secrets.read(key: key), "retained");
    expect(native.reads, 1);
    expect(native.writes, 1);
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

  test("shared secret DI stays lazy and persists only ciphertext through WAL and cold reopen", () async {
    const key = FixtureSecretKey(storageKey: "fixture.secret");
    const secret = "FIXTURE-SECRET-MUST-NOT-REACH-SQLITE-0123456789";
    final directory = Directory.systemTemp.createTempSync("sesori-storage-content-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final platform = _FixtureDirectory(directory: directory);
    final native = FixtureMasterKeyStore(value: null);
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<PersistenceDirectory>(platform)
      ..registerSingleton<PersistenceScope>(PersistenceScope.development)
      ..registerSingleton<MasterKeyStore>(native);
    configurePersistenceDependencies(getIt: getIt);
    final cipher = getIt<StorageCipher>();
    final database = getIt<PersistenceDatabase>();
    try {
      final repository = getIt<SecureStorageRepository>();
      expect(getIt<SecureStorageRepository>(), same(repository));
      expect(platform.resolutions, 0);
      expect(native.reads, 0);
      expect(native.writes, 0);
      await repository.write(key: key, value: secret);
      await getIt<PersisterRepository>().writeString(key: _StringKey.theme, value: "fixture-plaintext-theme");
      final encodedMasterKey = native.storedValue!;
      final files = directory.listSync().whereType<File>().toList();
      expect(files.any((file) => file.path.endsWith("-wal")), isTrue);
      final contents = files.map((file) => latin1.decode(file.readAsBytesSync())).toList();
      expect(contents.any((content) => content.contains("fixture-plaintext-theme")), isTrue);
      for (final content in contents) {
        expect(content.contains(secret), isFalse);
        expect(content.contains(encodedMasterKey), isFalse);
        expect(content.contains(latin1.decode(base64Decode(encodedMasterKey))), isFalse);
      }
      final row = await database.select(database.encryptedValues).getSingle();
      expect(row.key, key.storageKey);
      expect(utf8.decode(row.ciphertext, allowMalformed: true), isNot(contains(secret)));
    } finally {
      await getIt.reset();
    }

    final reopened = PersistenceDatabase.open(
      persistenceDirectory: platform,
      scope: PersistenceScope.development,
    );
    try {
      final coldNative = FixtureMasterKeyStore(value: native.storedValue);
      final cold = SecureStorageRepository(
        storageApi: SecureStorageApi(database: reopened, masterKeyStore: coldNative),
        cipher: cipher,
      );
      expect(await cold.read(key: key), secret);
      expect(coldNative.reads, 1);
      expect(coldNative.writes, 0);
    } finally {
      await reopened.close();
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

enum _StringKey({@override required final String storageKey}) implements StringPersistenceKey {
  theme(storageKey: "theme"),
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
