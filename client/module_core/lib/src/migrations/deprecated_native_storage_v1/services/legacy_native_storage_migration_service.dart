import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/keys/legacy_migration_key.dart";
import "../foundation/models/legacy_persistence_value.dart";
import "../foundation/models/legacy_storage_migration_exception.dart";
import "../repositories/legacy_native_storage_migration_repository.dart";

/// Temporary, awaited production-mobile startup work. No normal consumers may
/// start until it succeeds. Restart is the retry boundary; this owns no cache.
@lazySingleton
class LegacyNativeStorageMigrationService({
  required final LegacyNativeStorageMigrationRepository source,
  required final PersisterRepository persister,
  required final SecureStorageRepository secrets,
}) {
  // COMPATIBILITY 2026-09-25 (v1.9.1): Preserve released per-value-native mobile data.
  // Remove when supported direct upgrades exclude the last public build using it.
  // The internal module's 0.x version is not the mobile upgrade baseline.
  // ignore: remove_deprecations_in_breaking_versions
  @Deprecated("Remove only when supported direct upgrades exclude all per-value-native production builds.")
  Future<void> migrate() async {
    var operation = LegacyStorageMigrationOperation.readCompletion;
    try {
      if (await persister.readBool(key: LegacyMigrationKey.completed) ?? false) return;

      operation = LegacyStorageMigrationOperation.readSource;
      final values = await source.readValues();
      operation = LegacyStorageMigrationOperation.copyValues;
      for (final entry in values) {
        switch (entry) {
          case LegacyStringValue(:final key, :final value):
            await persister.writeString(key: key, value: value);
          case LegacyBoolValue(:final key, :final value):
            await persister.writeBool(key: key, value: value);
          case LegacySecretValue(:final key, :final value):
            await secrets.write(key: key, value: value);
        }
      }

      // Every copy has committed. Interrupted cleanup leaves those rows intact;
      // a relaunch merges only remaining source entries, never replacing a map.
      operation = LegacyStorageMigrationOperation.deleteSource;
      for (final entry in values) {
        await source.delete(sourceKey: entry.sourceKey);
      }
      operation = LegacyStorageMigrationOperation.writeCompletion;
      await persister.writeBool(key: LegacyMigrationKey.completed, value: true);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LegacyStorageMigrationException(operation: operation, innerError: error, innerStackTrace: stackTrace),
        stackTrace,
      );
    }
  }
}
