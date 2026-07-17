import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/agent_repository.dart";
import "package:sesori_bridge/src/bridge/routing/post_agents_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("PostAgentsHandler", () {
    late FakeBridgePlugin plugin;
    late AgentRepository repository;
    late PostAgentsHandler handler;
    late AppDatabase db;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      addTearDown(db.close);
      repository = singlePluginAgentRepository(plugin: plugin, projectsDao: db.projectsDao);
      handler = PostAgentsHandler(repository);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /agent", () {
      expect(handler.canHandle(makeRequest("POST", "/agent")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/agent")), isFalse);
    });

    test("forwards the projectId from the request body to the plugin", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "planner",
          description: "Plans tasks",
          model: PluginAgentModel(modelID: "gpt-4o", providerID: "openai", variant: "high"),
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/agent"),
        body: const PluginProjectIdRequest(projectId: "/repo", pluginId: "fake"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastAgentsProjectId, equals("/repo"));
      expect(response.agents.single.name, equals("planner"));
    });
  });
}
