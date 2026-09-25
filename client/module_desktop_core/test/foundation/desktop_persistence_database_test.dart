import "dart:convert";
import "dart:io";

import "package:drift/native.dart";
import "package:get_it/get_it.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

import "../fixtures/desktop_storage_fixture.dart";

void main() {
  test("typed primitive tables preserve absence, false, updates and key-local deletion", () async {
    final database = DesktopPersistenceDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = DesktopPrimitiveStorageApi(database: database);
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

  test("production open is lazy and development/production files stay separate", () async {
    final directory = Directory.systemTemp.createTempSync("sesori-storage-scope-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final support = _SupportDirectory(directory: directory);
    for (final scope in DesktopStorageScope.values) {
      final database = DesktopPersistenceDatabase.open(applicationSupportDirectory: support, scope: scope);
      final api = DesktopPrimitiveStorageApi(database: database);
      final before = support.resolutions;
      try {
        expect(await api.readString(key: "scope"), isNull);
        expect(support.resolutions, before + 1);
        await api.writeString(key: "scope", value: scope.storageId);
      } finally {
        await database.close();
      }
    }
    for (final scope in DesktopStorageScope.values) {
      final database = DesktopPersistenceDatabase.open(applicationSupportDirectory: support, scope: scope);
      try {
        expect(await DesktopPrimitiveStorageApi(database: database).readString(key: "scope"), scope.storageId);
      } finally {
        await database.close();
      }
    }
    expect(DesktopStorageScope.development.databaseFileName, isNot(DesktopStorageScope.production.databaseFileName));
    expect(DesktopStorageScope.development.masterKeyStorageKey, "desktop-master-key-v1-development");
    expect(DesktopStorageScope.production.masterKeyStorageKey, "desktop-master-key-v1-production");
  });

  test("file database and WAL contain ciphertext, not plaintext secrets or master keys", () async {
    const key = FixtureSecretKey(storageKey: "fixture.secret");
    const secret = "FIXTURE-SECRET-MUST-NOT-REACH-SQLITE-0123456789";
    final directory = Directory.systemTemp.createTempSync("sesori-storage-content-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final support = _SupportDirectory(directory: directory);
    final native = FixtureMasterKeyStore(value: null);
    final cipher = DesktopStorageCipher(scope: DesktopStorageScope.development);
    var database = DesktopPersistenceDatabase.open(
      applicationSupportDirectory: support,
      scope: DesktopStorageScope.development,
    );
    try {
      final api = DesktopSecureStorageApi(database: database, masterKeyStore: native);
      final repository = DesktopSecureStorageRepository(storageApi: api, cipher: cipher);
      await repository.write(key: key, value: secret);
      await DesktopPrimitiveStorageApi(database: database).writeString(key: "theme", value: "fixture-plaintext-theme");
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
      await database.close();
    }

    database = DesktopPersistenceDatabase.open(
      applicationSupportDirectory: support,
      scope: DesktopStorageScope.development,
    );
    try {
      final coldNative = FixtureMasterKeyStore(value: native.storedValue);
      final cold = DesktopSecureStorageRepository(
        storageApi: DesktopSecureStorageApi(database: database, masterKeyStore: coldNative),
        cipher: cipher,
      );
      expect(await cold.read(key: key), secret);
      expect(coldNative.reads, 1);
      expect(coldNative.writes, 0);
    } finally {
      await database.close();
    }
  });

  test("GetIt owns lazy database construction and closes it on graph reset", () async {
    final directory = Directory.systemTemp.createTempSync("sesori-storage-disposal-");
    addTearDown(() => directory.deleteSync(recursive: true));
    final support = _SupportDirectory(directory: directory);
    final native = FixtureMasterKeyStore(value: null);
    final getIt = GetIt.asNewInstance()
      ..registerSingleton<DesktopApplicationSupportDirectory>(support)
      ..registerSingleton<DesktopStorageScope>(DesktopStorageScope.development)
      ..registerSingleton<DesktopMasterKeyStore>(native);
    addTearDown(getIt.reset);
    configureDesktopCoreDependencies(getIt);
    expect(support.resolutions, 0);
    final database = getIt<DesktopPersistenceDatabase>();
    expect(support.resolutions, 0);
    expect(getIt<DesktopPersistenceDatabase>(), same(database));
    expect(getIt<DesktopSecureStorageRepository>(), same(getIt<DesktopSecureStorageRepository>()));
    final api = getIt<DesktopPrimitiveStorageApi>();
    await api.writeBool(key: "fixture", value: true);
    expect(support.resolutions, 1);
    expect(native.reads, 0);
    expect(native.writes, 0);
    await getIt.reset();
    await expectLater(api.readBool(key: "fixture"), throwsA(anything));
  });
}

class _SupportDirectory({required final Directory directory}) implements DesktopApplicationSupportDirectory {
  int resolutions = 0;

  @override
  Future<Directory> resolve() async {
    resolutions++;
    return directory;
  }
}
