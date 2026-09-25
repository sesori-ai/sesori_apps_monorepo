import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:sesori_persistence/sesori_persistence.dart";

/// Native access only. The shared repository owns initialization and caching.
class FlutterMasterKeyStore({required final FlutterSecureStorage storage, required final PersistenceScope scope})
    implements MasterKeyStore {
  @override
  Future<String?> read() => storage.read(key: scope.masterKeyStorageKey);

  @override
  Future<void> write({required String value}) => storage.write(key: scope.masterKeyStorageKey, value: value);
}
