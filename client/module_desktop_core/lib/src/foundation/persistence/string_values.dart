import "package:drift/drift.dart";

class StringValues() extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  bool get withoutRowId => true;
}
