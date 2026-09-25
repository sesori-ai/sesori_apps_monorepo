import "package:injectable/injectable.dart";

import "../foundation/platform/primitive_storage.dart";

/// Raw I/O boundary; does not interpret domain values or select a backend.
@lazySingleton
class PersisterApi({required PrimitiveStorage primitiveStorage}) {
  final PrimitiveStorage _storage = primitiveStorage;

  Future<String?> readString({required String key}) => _storage.readString(key: key);

  Future<void> writeString({required String key, required String value}) =>
      _storage.writeString(key: key, value: value);

  Future<void> deleteString({required String key}) => _storage.deleteString(key: key);

  Future<bool?> readBool({required String key}) => _storage.readBool(key: key);

  Future<void> writeBool({required String key, required bool value}) => _storage.writeBool(key: key, value: value);

  Future<void> deleteBool({required String key}) => _storage.deleteBool(key: key);
}
