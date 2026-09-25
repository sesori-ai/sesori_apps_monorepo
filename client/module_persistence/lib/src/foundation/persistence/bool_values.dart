import "package:drift/drift.dart";

class BoolValues() extends Table {
  TextColumn get key => text()();
  BoolColumn get value => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  bool get withoutRowId => true;
}
