import "package:sesori_persistence/sesori_persistence.dart";

/// Internal to the deprecated importer; deliberately absent from public exports.
enum LegacyMigrationKey({@override required final String storageKey}) implements BoolPersistenceKey {
  /// Absent: ordinary import. False: reset pending. True: handled.
  completed(storageKey: "deprecated_native_storage_v1_completed"),
}
