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
      final completed = await persister.readBool(key: LegacyMigrationKey.completed);
      if (completed ?? false) return;
      if (completed == false) {
        await _resetPendingMigration();
        return;
      }

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
      // An unreadable marker cannot safely authorize new destruction.
      if (operation == LegacyStorageMigrationOperation.readCompletion) {
        secrets.blockAccess(error: error, stackTrace: stackTrace);
        return;
      }
      // False is durable reset intent, not an ordinary import retry. Record it
      // before modifying either store so partial native cleanup cannot restore
      // the old account after a cold launch.
      final admitted = await _recover(
        operation: LegacyStorageMigrationOperation.writeRecovery,
        blockSecretsOnFailure: true,
        action: () => persister.writeBool(key: LegacyMigrationKey.completed, value: false),
      );
      if (admitted) await _resetPendingMigration();
    }
  }

  Future<void> _resetPendingMigration() async {
    final secretsReset = await _recover(
      operation: LegacyStorageMigrationOperation.resetSecrets,
      blockSecretsOnFailure: true,
      action: secrets.reset,
    );
    final preferencesCleared = await _recover(
      operation: LegacyStorageMigrationOperation.clearPreferences,
      blockSecretsOnFailure: true,
      action: () => persister.clearAndWriteBool(key: LegacyMigrationKey.completed, value: false),
    );
    if (!secretsReset || !preferencesCleared) return;
    await _recover(
      operation: LegacyStorageMigrationOperation.clearSource,
      blockSecretsOnFailure: false,
      action: source.clear,
    );
    // A durable true is required even if source clearing succeeded: otherwise a
    // pending recovery would erase credentials from a fresh login on relaunch.
    await _recover(
      operation: LegacyStorageMigrationOperation.markReset,
      blockSecretsOnFailure: true,
      action: () => persister.writeBool(key: LegacyMigrationKey.completed, value: true),
    );
  }

  Future<bool> _recover({
    required LegacyStorageMigrationOperation operation,
    required bool blockSecretsOnFailure,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      return true;
    } on Object catch (error, stackTrace) {
      _logFailure(operation: operation, error: error, stackTrace: stackTrace);
      if (blockSecretsOnFailure) secrets.blockAccess(error: error, stackTrace: stackTrace);
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
