import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_commands_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetCommandsHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late GetCommandsHandler handler;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      plugin = FakeBridgePlugin();
      handler = GetCommandsHandler(
        sessionRepository: SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /command", () {
      expect(handler.canHandle(makeRequest("POST", "/command")), isTrue);
    });

    test("accepts a request body without pluginId", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/command",
          body: jsonEncode({"projectId": "/repo"}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(plugin.lastGetCommandsProjectId, equals("/repo"));
    });

    test("maps commands through repository mapper", () async {
      plugin.commandsResult = [
        const PluginCommand(
          name: "review",
          template: "/review",
          hints: ["file.dart"],
          description: "Review changes",
          agent: "reviewer",
          model: "gpt-5",
          provider: "openai",
          source: PluginCommandSource.command,
          subtask: true,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/command"),
        body: const PluginProjectIdRequest(projectId: "/repo"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCommandsProjectId, equals("/repo"));
      expect(
        response,
        equals(
          const CommandListResponse(
            items: [
              CommandInfo(
                name: "review",
                template: null,
                hints: ["file.dart"],
                description: "Review changes",
                agent: "reviewer",
                model: "gpt-5",
                provider: "openai",
                source: CommandSource.command,
                subtask: true,
              ),
            ],
          ),
        ),
      );
    });

    test("accepts the active plugin selection", () async {
      await handler.handle(
        makeRequest("POST", "/command"),
        body: const PluginProjectIdRequest(projectId: "/repo", pluginId: "fake"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCommandsProjectId, equals("/repo"));
    });
  });
}
