import "package:drift/drift.dart";

/// Stores project IDs that the user has hidden from project listings.
class HiddenProjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId => text().unique()();
}
