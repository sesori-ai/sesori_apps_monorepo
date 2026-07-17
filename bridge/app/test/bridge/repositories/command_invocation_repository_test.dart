import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/command_invocation_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/models/accepted_command_invocation.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  test("persists nullable arguments, orders by acceptance, and updates backend correlation", () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await _insertSession(db);
    final repository = CommandInvocationRepository(dao: db.commandInvocationDao);

    await repository.save(
      invocation: const AcceptedCommandInvocation(
        invocationId: "later",
        sessionId: "session",
        pluginId: "plugin",
        name: "review",
        arguments: "carefully",
        acceptedAt: 20,
        backendMessageId: null,
      ),
    );
    await repository.save(
      invocation: const AcceptedCommandInvocation(
        invocationId: "earlier",
        sessionId: "session",
        pluginId: "plugin",
        name: "test",
        arguments: null,
        acceptedAt: 10,
        backendMessageId: null,
      ),
    );

    final beforeUpdate = await repository.getForSession(pluginId: "plugin", sessionId: "session");
    expect(beforeUpdate.map((row) => row.invocationId), ["earlier", "later"]);
    expect(beforeUpdate.first.arguments, isNull);

    await repository.updateBackendMessageId(
      invocationId: "earlier",
      backendMessageId: "backend-message",
    );
    final updated = await repository.getForSession(pluginId: "plugin", sessionId: "session");
    expect(updated.first.backendMessageId, "backend-message");
  });
}

Future<void> _insertSession(AppDatabase db) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: ["project"]);
  await db.sessionDao.insertSession(
    sessionId: "session",
    backendSessionId: "backend-session",
    projectId: "project",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    pluginId: "plugin",
  );
}
