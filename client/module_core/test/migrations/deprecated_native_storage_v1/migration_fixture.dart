import "dart:io";

import "package:get_it/get_it.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";

class MigrationFixture({required final Directory directory, required final FakeLegacyStorage source}) {
  final getIt = GetIt.asNewInstance();
  final master = FakeMasterKeyStore();

  this {
    _configure();
  }

  static Future<MigrationFixture> create({required Map<String, String> values}) async => MigrationFixture(
    directory: await Directory.systemTemp.createTemp("sesori-legacy-import-"),
    source: FakeLegacyStorage(values: Map.of(values)),
  );

  PersisterRepository get persister => getIt<PersisterRepository>();
  SecureStorageRepository get secrets => getIt<SecureStorageRepository>();
  PersistenceDatabase get database => getIt<PersistenceDatabase>();
  LegacyNativeStorageMigrationService get service => getIt<LegacyNativeStorageMigrationService>();

  Future<void> reopen() async {
    await getIt.reset();
    _configure();
  }

  Future<void> dispose() async {
    await getIt.reset();
    await directory.delete(recursive: true);
  }

  void _configure() {
    getIt.registerSingleton<PersistenceScope>(PersistenceScope.development);
    getIt.registerSingleton<PersistenceDirectory>(_FixtureDirectory(directory: directory));
    getIt.registerSingleton<MasterKeyStore>(master);
    getIt.registerLazySingleton<LegacyNativeStorage>(() => source);
    configurePersistenceDependencies(getIt: getIt);
    configureCoreDependencies(getIt);
  }
}

class _FixtureDirectory({required final Directory directory}) implements PersistenceDirectory {
  @override
  Future<Directory> resolve() async => directory;
}

class FakeMasterKeyStore() implements MasterKeyStore {
  String? value;
  int reads = 0;
  int writes = 0;
  Object? writeFailure;

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write({required String value}) async {
    writes++;
    if (writeFailure case final error?) throw error;
    this.value = value;
  }
}

class FakeLegacyStorage({required final Map<String, String> values}) implements LegacyNativeStorage {
  int reads = 0;
  int clears = 0;
  Object? clearFailure;
  final deleted = <String>[];
  ({Object error, StackTrace stackTrace})? readFailure;
  ({String key, Object error})? deleteFailure;
  Future<void> Function()? beforeDelete;

  @override
  Future<Map<String, String>> readAll() async {
    reads++;
    if (readFailure case final failure?) Error.throwWithStackTrace(failure.error, failure.stackTrace);
    return Map.of(values);
  }

  @override
  Future<void> clear() async {
    clears++;
    if (clearFailure case final error?) throw error;
    values.clear();
  }

  @override
  Future<void> delete({required String key}) async {
    await beforeDelete?.call();
    if (deleteFailure case final failure? when failure.key == key) throw failure.error;
    deleted.add(key);
    values.remove(key);
  }
}
