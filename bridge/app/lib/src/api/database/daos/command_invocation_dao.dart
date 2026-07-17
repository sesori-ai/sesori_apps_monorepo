import "package:drift/drift.dart";

import "../database.dart";
import "../tables/accepted_command_invocations_table.dart";

part "command_invocation_dao.g.dart";

@DriftAccessor(tables: [AcceptedCommandInvocationsTable])
class CommandInvocationDao extends DatabaseAccessor<AppDatabase> with _$CommandInvocationDaoMixin {
  CommandInvocationDao(super.attachedDatabase);

  Future<void> insertInvocation({required AcceptedCommandInvocationDto invocation}) async {
    await into(acceptedCommandInvocationsTable).insert(invocation);
  }

  Future<void> updateBackendMessageId({required String invocationId, required String backendMessageId}) async {
    await (update(
      acceptedCommandInvocationsTable,
    )..where((table) => table.invocationId.equals(invocationId))).write(
      AcceptedCommandInvocationsTableCompanion(
        backendMessageId: Value(backendMessageId),
      ),
    );
  }

  Future<List<AcceptedCommandInvocationDto>> getInvocationsForSession({
    required String pluginId,
    required String sessionId,
  }) {
    final query = select(acceptedCommandInvocationsTable)
      ..where((table) => table.pluginId.equals(pluginId) & table.sessionId.equals(sessionId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.acceptedAt),
        (table) => OrderingTerm.asc(table.invocationId),
      ]);
    return query.get();
  }

  Future<List<AcceptedCommandInvocationDto>> getInvocationsForPlugin({required String pluginId}) {
    final query = select(acceptedCommandInvocationsTable)
      ..where((table) => table.pluginId.equals(pluginId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.acceptedAt),
        (table) => OrderingTerm.asc(table.invocationId),
      ]);
    return query.get();
  }
}
