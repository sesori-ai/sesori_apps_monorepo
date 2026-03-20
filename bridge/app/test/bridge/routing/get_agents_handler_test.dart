import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_agents_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetAgentsHandler", () {
    late FakeBridgePlugin plugin;
    late GetAgentsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetAgentsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /agent", () {
      expect(handler.canHandle(makeRequest("GET", "/agent")), isTrue);
    });

    test("returns JSON list", () async {
      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      expect(jsonDecode(response.body!), isA<List<dynamic>>());
    });

    test("maps all fields correctly", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "planner",
          description: "Plans tasks",
          model: PluginAgentModel(modelID: "gpt-4o", providerID: "openai"),
          variant: "fast",
          mode: PluginAgentMode.primary,
          hidden: true,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final agent = body[0] as Map<String, dynamic>;
      expect(agent["name"], equals("planner"));
      expect(agent["description"], equals("Plans tasks"));
      expect(agent["variant"], equals("fast"));
      expect(agent["mode"], equals("primary"));
      expect(agent["hidden"], isTrue);

      final model = agent["model"] as Map<String, dynamic>;
      expect(model["modelID"], equals("gpt-4o"));
      expect(model["providerID"], equals("openai"));
    });

    test("handles agents with and without model", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "with-model",
          description: null,
          model: PluginAgentModel(modelID: "m1", providerID: "p1"),
          variant: null,
          mode: PluginAgentMode.all,
          hidden: false,
        ),
        const PluginAgent(
          name: "without-model",
          description: null,
          model: null,
          variant: null,
          mode: PluginAgentMode.subagent,
          hidden: false,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect((body[0] as Map<String, dynamic>)["model"], isNotNull);
      expect((body[1] as Map<String, dynamic>)["model"], isNull);
    });
  });
}
