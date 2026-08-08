import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  // Opening a session must not start a harness to learn there is nothing
  // pending. Pending state lives in the backend process — an in-memory
  // approval registry for ACP, the running HTTP server for OpenCode — so a
  // stopped backend holds none, and starting it could only ever answer "none"
  // after paying the full start cost.
  group("pending state on a stopped backend", () {
    late AppDatabase database;
    late FakeBridgePlugin plugin;
    late TestPluginRuntime runtime;

    setUp(() async {
      database = createTestDatabase();
      addTearDown(database.close);
      plugin = FakeBridgePlugin();
      addTearDown(plugin.close);
      runtime = createTestPluginRuntime(plugins: [plugin]);
      await recordSessionBinding(
        database: database,
        sessionId: "ses_a",
        backendSessionId: "backend-a",
        pluginId: plugin.id,
        projectId: "project-a",
        parentSessionId: null,
      );
    });

    test("questions report none without asking the plugin", () async {
      final repository = QuestionRepository(
        runtime: runtime,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        aggregateSourceDeadline: const Duration(seconds: 5),
      );
      runtime.stoppedPluginIds.add(plugin.id);

      expect(await repository.getPendingQuestions(sessionId: "ses_a"), isEmpty);
      expect(
        plugin.lastGetPendingQuestionsSessionId,
        isNull,
        reason: "a stopped backend must not be consulted, let alone started",
      );
    });

    test("permissions report none without asking the plugin", () async {
      final repository = PermissionRepository(
        runtime: runtime,
        sessionDao: database.sessionDao,
      );
      runtime.stoppedPluginIds.add(plugin.id);

      expect(await repository.getPendingPermissions(sessionId: "ses_a"), isEmpty);
      expect(plugin.lastGetPendingPermissionsSessionId, isNull);
    });

    test("a running backend is still asked", () async {
      final repository = QuestionRepository(
        runtime: runtime,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        aggregateSourceDeadline: const Duration(seconds: 5),
      );

      await repository.getPendingQuestions(sessionId: "ses_a");

      expect(plugin.lastGetPendingQuestionsSessionId, "backend-a");
    });
  });
}
