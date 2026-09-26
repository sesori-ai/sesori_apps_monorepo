import "package:drift/drift.dart";
import "package:injectable/injectable.dart";

import "../foundation/persistence/persistence_database.dart";

/// Raw typed-table access; ordinary preferences never consult the master key.
@lazySingleton
class PersisterApi({required PersistenceDatabase database}) {
  final PersistenceDatabase _database = database;

  Future<void> clear() => _database.batch((batch) {
    batch.deleteAll(_database.stringValues);
    batch.deleteAll(_database.boolValues);
  });

  Future<String?> readString({required String key}) => (_database.select(
    _database.stringValues,
  )..where((table) => table.key.equals(key))).map((row) => row.value).getSingleOrNull();

  Future<void> writeString({required String key, required String value}) async {
    await _database
        .into(_database.stringValues)
        .insertOnConflictUpdate(StringValuesCompanion.insert(key: key, value: value));
  }

  Future<void> deleteString({required String key}) async {
    await _database.delete(_database.stringValues).delete(StringValuesCompanion(key: Value(key)));
  }

  Future<bool?> readBool({required String key}) => (_database.select(
    _database.boolValues,
  )..where((table) => table.key.equals(key))).map((row) => row.value).getSingleOrNull();

  Future<void> writeBool({required String key, required bool value}) async {
    await _database
        .into(_database.boolValues)
        .insertOnConflictUpdate(BoolValuesCompanion.insert(key: key, value: value));
  }

  Future<void> deleteBool({required String key}) async {
    await _database.delete(_database.boolValues).delete(BoolValuesCompanion(key: Value(key)));
  }
}
