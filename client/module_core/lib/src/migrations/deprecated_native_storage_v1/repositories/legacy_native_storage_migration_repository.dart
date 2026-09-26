import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../../../foundation/persistence/persistence_keys.dart";
import "../api/legacy_native_storage_migration_api.dart";
import "../foundation/models/legacy_persistence_value.dart";

@lazySingleton
class LegacyNativeStorageMigrationRepository({required final LegacyNativeStorageMigrationApi api}) {
  Future<List<LegacyPersistenceValue>> readValues() async {
    final snapshot = await api.readAll();
    // Materialize/classify everything before any destination mutation.
    return snapshot.entries
        .map((entry) => _classify(sourceKey: entry.key, value: entry.value))
        .nonNulls
        .toList(growable: false);
  }

  Future<void> delete({required String sourceKey}) => api.delete(key: sourceKey);

  LegacyPersistenceValue? _classify({required String sourceKey, required String value}) {
    final secretKey = const <SecretStorageKey>[
      ...AuthSecretKey.values,
      ...CoreSecretKey.values,
    ].firstWhereOrNull((key) => key.storageKey == sourceKey);
    if (secretKey != null) return LegacySecretValue(sourceKey: sourceKey, key: secretKey, value: value);

    final stringKey = StringPreferenceKey.values.firstWhereOrNull((key) => key.storageKey == sourceKey);
    if (stringKey != null) return LegacyStringValue(sourceKey: sourceKey, key: stringKey, value: value);

    final boolKey = BoolPreferenceKey.values.firstWhereOrNull((key) => key.storageKey == sourceKey);
    if (boolKey != null) return LegacyBoolValue(sourceKey: sourceKey, key: boolKey, value: bool.parse(value));

    if (sourceKey.startsWith(PluginPreferenceKey.prefix)) {
      return LegacyStringValue(
        sourceKey: sourceKey,
        key: PluginPreferenceKey(bridgeId: Uri.decodeComponent(sourceKey.substring(PluginPreferenceKey.prefix.length))),
        value: value,
      );
    }
    if (sourceKey.startsWith(ProductAnalyticsPreferenceKey.prefix)) {
      return LegacyStringValue(
        sourceKey: sourceKey,
        key: ProductAnalyticsPreferenceKey(userId: sourceKey.substring(ProductAnalyticsPreferenceKey.prefix.length)),
        value: value,
      );
    }
    return null;
  }
}
