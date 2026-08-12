import "package:drift/drift.dart";

/// Per-session freshness bookkeeping for the stored transcript.
///
/// A row exists as soon as anything is captured for the session. `syncedAt` is
/// set only by a completed backfill, so a capture-created row never claims to
/// be a complete transcript. `backendActivityAt` is the staleness comparison
/// target and is advanced only by observed backend activity — never by
/// bridge-local metadata writes such as a rename.
class HistorySyncStateTable() extends Table {
  @override
  String get tableName => "history_sync_state";

  TextColumn get sessionId => text()();
  IntColumn get watermark => integer()();
  IntColumn get backendActivityAt => integer()();
  IntColumn get syncedAt => integer().nullable()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {sessionId};
}
