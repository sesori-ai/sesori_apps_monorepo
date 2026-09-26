import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../../../logging/logging.dart";
import "../foundation/keys/legacy_migration_key.dart";
import "../foundation/models/legacy_persistence_value.dart";
import "../foundation/models/legacy_storage_migration_exception.dart";
import "../repositories/legacy_native_storage_migration_repository.dart";

/// Temporary, awaited production-mobile startup work. Consumers start after
/// import or its destructive recovery attempt; this service owns no cache.
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
      _logFailure(operation: operation, error: error, stackTrace: stackTrace);
      // A failed upgrade must not strand the app on a blocking recovery screen.
      final secretsReset = await _recover(
        operation: LegacyStorageMigrationOperation.resetSecrets,
        action: secrets.reset,
      );
      await _recover(operation: LegacyStorageMigrationOperation.clearPreferences, action: persister.clear);
      // Do not discard the remaining source or trust partial destination rows
      // on a cold launch when reset failed. Leave the import/reset retryable.
      if (!secretsReset) return;
      await _recover(operation: LegacyStorageMigrationOperation.clearSource, action: source.clear);
      // Also retire an unreadable/undeletable source: it must not resurrect old
      // auth after a fresh login. Failure to persist this decision stays logged.
      await _recover(
        operation: LegacyStorageMigrationOperation.markReset,
        action: () => persister.writeBool(key: LegacyMigrationKey.completed, value: true),
      );
    }
  }

  Future<bool> _recover({
    required LegacyStorageMigrationOperation operation,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      return true;
    } on Object catch (error, stackTrace) {
      _logFailure(operation: operation, error: error, stackTrace: stackTrace);
      return false;
    }
  }

  void _logFailure({
    required LegacyStorageMigrationOperation operation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    loge(
      "Local storage migration/recovery failed",
      LegacyStorageMigrationException(operation: operation, innerError: error, innerStackTrace: stackTrace),
      stackTrace,
    );
  }
}
