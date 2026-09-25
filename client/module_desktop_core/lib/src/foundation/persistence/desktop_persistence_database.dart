import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../desktop_storage_scope.dart";
import "../platform/desktop_application_support_directory.dart";
import "bool_values.dart";
import "encrypted_values.dart";
import "string_values.dart";

part "desktop_persistence_database.g.dart";

/// Scoped desktop persistence. SQLite owns statement/transaction atomicity and
/// Drift owns the connection/isolate lifecycle. Native authorization never runs
/// inside a database transaction.
@lazySingleton
@DriftDatabase(tables: [StringValues, BoolValues, EncryptedValues])
class DesktopPersistenceDatabase({required QueryExecutor executor}) extends _$DesktopPersistenceDatabase {
  this : super(executor);

  @factoryMethod
  factory open({
    required DesktopApplicationSupportDirectory applicationSupportDirectory,
    required DesktopStorageScope scope,
  }) => DesktopPersistenceDatabase(
    executor: LazyDatabase(() async {
      final directory = await applicationSupportDirectory.resolve();
      await directory.create(recursive: true);
      return NativeDatabase.createInBackground(
        File(path.join(directory.path, scope.databaseFileName)),
        setup: (database) => database.execute("PRAGMA journal_mode = WAL"),
      );
    }),
  );

  @override
  int get schemaVersion => 1;

  @disposeMethod
  @override
  Future<void> close() => super.close();
}
