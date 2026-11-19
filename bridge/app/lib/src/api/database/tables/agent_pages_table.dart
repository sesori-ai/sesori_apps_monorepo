import "package:drift/drift.dart";

import "../converters/pending_page_converter.dart";
import "session_table.dart";

enum AgentPageStatus() {
  pending,
  answered,
  dismissed,
}

/// The pages agents sent the user, kept after they are settled so an answered
/// or dismissed page can be reopened read-only.
@DataClassName("AgentPageDto")
@TableIndex(name: "idx_agent_pages_status_root", columns: {#status, #rootSessionId})
class AgentPagesTable() extends Table {
  @override
  String get tableName => "agent_pages";

  TextColumn get id => text()();

  /// The session that sent the page.
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();

  /// The root of [sessionId]'s family, where the page is surfaced. Equal to
  /// [sessionId] when that session is a root.
  TextColumn get rootSessionId => text()();
  TextColumn get pageJson => text().map(const PendingPageConverter())();
  TextColumn get status => textEnum<AgentPageStatus>()();

  /// How the user settled the page, as JSON. Null while it is pending.
  TextColumn get outcomeJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get settledAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}
