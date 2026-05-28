import "package:sesori_bridge/src/bridge/repositories/agent_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_agents_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetAgentsHandler", () {
    late FakeBridgePlugin plugin;
    late AgentRepository repository;
    late GetAgentsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      repository = AgentRepository(plugin: plugin);
      handler = GetAgentsHandler(repository);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /agent", () {
      expect(handler.canHandle(makeRequest("GET", "/agent")), isTrue);
    });

    test("returns typed list", () async {
      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.agents, isA<List<AgentInfo>>());
    });

    test("maps all fields correctly", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "planner",
          description: "Plans tasks",
          model: PluginAgentModel(modelID: "gpt-4o", providerID: "openai", variant: "high"),
          mode: PluginAgentMode.primary,
          hidden: true,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final agent = response.agents[0];
      expect(agent.name, equals("planner"));
      expect(agent.description, equals("Plans tasks"));
      expect(agent.mode, equals(AgentMode.primary));
      expect(agent.hidden, isTrue);
      expect(agent.model, equals(const AgentModel(modelID: "gpt-4o", providerID: "openai", variant: "high")));
    });

    test("maps unknown plugin agent modes to AgentMode.unknown", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "tolerant-agent",
          description: null,
          model: null,
          mode: PluginAgentMode.unknown,
          hidden: false,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.agents.single.mode, equals(AgentMode.unknown));
    });

    test("handles agents with and without model", () async {
      plugin.agentsResult = [
        const PluginAgent(
          name: "with-model",
          description: null,
          model: PluginAgentModel(modelID: "m1", providerID: "p1", variant: null),
          mode: PluginAgentMode.all,
          hidden: false,
        ),
        const PluginAgent(
          name: "without-model",
          description: null,
          model: null,
          mode: PluginAgentMode.subagent,
          hidden: false,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/agent"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.agents[0].model, isNotNull);
      expect(response.agents[1].model, isNull);
    });
  });
}
