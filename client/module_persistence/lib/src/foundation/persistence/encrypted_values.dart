import "package:drift/drift.dart";

/// Only authenticated ciphertext reaches this table, never plaintext secrets.
class EncryptedValues() extends Table {
  TextColumn get key => text()();
  BlobColumn get ciphertext => blob()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  bool get withoutRowId => true;
}
