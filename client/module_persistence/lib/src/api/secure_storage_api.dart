import "package:drift/drift.dart";
import "package:injectable/injectable.dart";

import "../foundation/persistence/persistence_database.dart";
import "../foundation/platform/master_key_store.dart";
import "../foundation/storage_exception.dart";

/// Raw ciphertext/native-item I/O. The repository owns unlock/key-creation
/// policy; this API never receives plaintext secret values.
@lazySingleton
class SecureStorageApi({required PersistenceDatabase database, required MasterKeyStore masterKeyStore}) {
  final PersistenceDatabase _database = database;
  final MasterKeyStore _masterKeyStore = masterKeyStore;

  Future<Uint8List?> readCiphertext({required String key}) => (_database.select(
    _database.encryptedValues,
  )..where((table) => table.key.equals(key))).map((row) => row.ciphertext).getSingleOrNull();

  Future<void> writeCiphertext({required String key, required Uint8List ciphertext}) async {
    await _database
        .into(_database.encryptedValues)
        .insertOnConflictUpdate(EncryptedValuesCompanion.insert(key: key, ciphertext: ciphertext));
  }

  Future<void> deleteCiphertext({required String key}) async {
    await _database.delete(_database.encryptedValues).delete(EncryptedValuesCompanion(key: Value(key)));
  }

  Future<void> clearCiphertexts() => _database.batch((batch) => batch.deleteAll(_database.encryptedValues));

  Future<bool> hasEncryptedValues() async {
    final query = _database.selectOnly(_database.encryptedValues)
      ..addColumns([_database.encryptedValues.key])
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  Future<String?> readMasterKey() async {
    try {
      return await _masterKeyStore.read();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(operation: StorageOperation.readMasterKey, innerError: error),
        stackTrace,
      );
    }
  }

  Future<void> writeMasterKey({required String value}) async {
    try {
      await _masterKeyStore.write(value: value);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException(operation: StorageOperation.writeMasterKey, innerError: error),
        stackTrace,
      );
    }
  }
}
