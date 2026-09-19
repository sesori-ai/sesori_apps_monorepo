import "package:drift/drift.dart";

/// Prompt ids each session has already accepted. A client retries a send
/// whose response was lost with the same id, possibly hours later, so the
/// bridge refuses a recorded id instead of running that prompt again.
class AcceptedPromptsTable() extends Table {
  @override
  String get tableName => "accepted_prompts_table";

  TextColumn get sessionId => text()();
  TextColumn get promptId => text()();
  IntColumn get acceptedAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {sessionId, promptId};

  @override
  List<String> get customConstraints => const ["CHECK (session_id <> '')", "CHECK (prompt_id <> '')"];
}
