import "package:drift/drift.dart";
import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/persistence/desktop_persistence_database.dart";

/// Raw typed-table access; ordinary preferences never consult the master key.
@lazySingleton
class DesktopPrimitiveStorageApi({required DesktopPersistenceDatabase database}) implements PrimitiveStorage {
  final DesktopPersistenceDatabase _database = database;

  @override
  Future<String?> readString({required String key}) => (_database.select(
    _database.stringValues,
  )..where((table) => table.key.equals(key))).map((row) => row.value).getSingleOrNull();

  @override
  Future<void> writeString({required String key, required String value}) async {
    await _database
        .into(_database.stringValues)
        .insertOnConflictUpdate(StringValuesCompanion.insert(key: key, value: value));
  }

  @override
  Future<void> deleteString({required String key}) async {
    await _database.delete(_database.stringValues).delete(StringValuesCompanion(key: Value(key)));
  }

  @override
  Future<bool?> readBool({required String key}) => (_database.select(
    _database.boolValues,
  )..where((table) => table.key.equals(key))).map((row) => row.value).getSingleOrNull();

  @override
  Future<void> writeBool({required String key, required bool value}) async {
    await _database
        .into(_database.boolValues)
        .insertOnConflictUpdate(BoolValuesCompanion.insert(key: key, value: value));
  }

  @override
  Future<void> deleteBool({required String key}) async {
    await _database.delete(_database.boolValues).delete(BoolValuesCompanion(key: Value(key)));
  }
}
