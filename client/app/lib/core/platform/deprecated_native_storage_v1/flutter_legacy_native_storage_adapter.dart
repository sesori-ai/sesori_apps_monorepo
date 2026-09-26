import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// DEPRECATED / TEMPORARY: old mobile keyspace access for the isolated importer.
/// Remove with core's deprecated_native_storage_v1 directory and startup seam.
/// Never catch a native failure and substitute an empty snapshot.
class FlutterLegacyNativeStorageAdapter({required final FlutterSecureStorage storage}) implements LegacyNativeStorage {
  @override
  Future<Map<String, String>> readAll() => storage.readAll();

  @override
  Future<void> delete({required String key}) => storage.delete(key: key);

  @override
  Future<void> clear() => storage.deleteAll();
}
