import "dart:io";

import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../persistence_scope.dart";
import "../platform/persistence_directory.dart";
import "bool_values.dart";
import "encrypted_values.dart";
import "string_values.dart";

part "persistence_database.g.dart";

/// Shared client persistence. SQLite owns statement/transaction atomicity and
/// Drift owns the connection/isolate lifecycle. Native authorization never runs
/// inside a database transaction.
@lazySingleton
@DriftDatabase(tables: [StringValues, BoolValues, EncryptedValues])
class PersistenceDatabase({required QueryExecutor executor}) extends _$PersistenceDatabase {
  this : super(executor);

  @factoryMethod
  factory open({required PersistenceDirectory persistenceDirectory, required PersistenceScope scope}) =>
      PersistenceDatabase(
        executor: LazyDatabase(() async {
          final directory = await persistenceDirectory.resolve();
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
