import "package:drift/drift.dart";

import "../database.dart";
import "../tables/accepted_prompts_table.dart";

part "accepted_prompts_dao.g.dart";

@DriftAccessor(tables: [AcceptedPromptsTable])
class AcceptedPromptsDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$AcceptedPromptsDaoMixin {
  this : super(database);

  Future<bool> hasRow({required String sessionId, required String promptId}) async {
    final row = await (select(
      acceptedPromptsTable,
    )..where((table) => table.sessionId.equals(sessionId) & table.promptId.equals(promptId))).getSingleOrNull();
    return row != null;
  }

  Future<void> insertRow({required AcceptedPromptsTableData row}) async {
    await into(acceptedPromptsTable).insert(row);
  }

  Future<void> deleteAcceptedBefore({required int cutoff}) async {
    await (delete(acceptedPromptsTable)..where((table) => table.acceptedAt.isSmallerThanValue(cutoff))).go();
  }
}
