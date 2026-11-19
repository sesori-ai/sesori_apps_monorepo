import "package:drift/drift.dart";

import "../database.dart";
import "../tables/agent_pages_table.dart";

part "agent_pages_dao.g.dart";

@DriftAccessor(tables: [AgentPagesTable])
class AgentPagesDao({required AppDatabase database}) extends DatabaseAccessor<AppDatabase> with _$AgentPagesDaoMixin {
  this : super(database);

  Future<void> insertPage({required AgentPageDto row}) async {
    await into(agentPagesTable).insert(row);
  }

  Future<AgentPageDto?> getPage({required String id}) {
    return (select(agentPagesTable)..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  /// The pending pages sent by [sessionId] or surfaced under it, oldest first.
  Future<List<AgentPageDto>> listPending({required String sessionId}) {
    return (select(agentPagesTable)
          ..where(
            (row) =>
                row.status.equalsValue(AgentPageStatus.pending) &
                (row.sessionId.equals(sessionId) | row.rootSessionId.equals(sessionId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  /// Moves page [id] from pending to [status] in one statement. Returns the
  /// updated row, or null when no pending page has that id.
  Future<AgentPageDto?> settlePending({
    required String id,
    required AgentPageStatus status,
    required String outcomeJson,
    required int settledAt,
  }) async {
    final statement = update(agentPagesTable)
      ..where((row) => row.id.equals(id) & row.status.equalsValue(AgentPageStatus.pending));
    final rows = await statement.writeReturning(
      AgentPagesTableCompanion(status: Value(status), outcomeJson: Value(outcomeJson), settledAt: Value(settledAt)),
    );
    return rows.firstOrNull;
  }

  /// The distinct root sessions with a pending page.
  Future<Set<String>> pendingRootSessionIds() async {
    final query = selectOnly(agentPagesTable, distinct: true)
      ..addColumns([agentPagesTable.rootSessionId])
      ..where(agentPagesTable.status.equalsValue(AgentPageStatus.pending));
    return {for (final row in await query.get()) ?row.read(agentPagesTable.rootSessionId)};
  }
}
