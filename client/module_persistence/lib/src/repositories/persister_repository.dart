import "package:injectable/injectable.dart";

import "../api/persister_api.dart";
import "../foundation/keys/bool_persistence_key.dart";
import "../foundation/keys/string_persistence_key.dart";

/// Typed access to non-secret primitive values. This layer owns no value cache,
/// domain serialization, encryption switch, or storage lifetime.
@lazySingleton
class PersisterRepository({required PersisterApi persisterApi}) {
  final PersisterApi _api = persisterApi;

  /// Clears both primitive tables in this repository's scope.
  Future<void> clear() => _api.clear();

  Future<String?> readString({required StringPersistenceKey key}) => _api.readString(key: key.storageKey);

  Future<String> readStringOrDefault({required StringPersistenceKey key, required String defaultValue}) async =>
      await readString(key: key) ?? defaultValue;

  Future<void> writeString({required StringPersistenceKey key, required String value}) =>
      _api.writeString(key: key.storageKey, value: value);

  Future<void> deleteString({required StringPersistenceKey key}) => _api.deleteString(key: key.storageKey);

  Future<bool?> readBool({required BoolPersistenceKey key}) => _api.readBool(key: key.storageKey);

  Future<bool> readBoolOrDefault({required BoolPersistenceKey key, required bool defaultValue}) async =>
      await readBool(key: key) ?? defaultValue;

  Future<void> writeBool({required BoolPersistenceKey key, required bool value}) =>
      _api.writeBool(key: key.storageKey, value: value);

  Future<void> deleteBool({required BoolPersistenceKey key}) => _api.deleteBool(key: key.storageKey);
}
