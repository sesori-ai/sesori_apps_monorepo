import "package:injectable/injectable.dart";

import "../foundation/platform/legacy_native_storage.dart";

@lazySingleton
class LegacyNativeStorageMigrationApi({required final LegacyNativeStorage storage}) {
  Future<Map<String, String>> readAll() => storage.readAll();

  Future<void> delete({required String key}) => storage.delete(key: key);
}
