import "package:opencode_plugin/src/models/agent_info.dart";
import "package:opencode_plugin/src/models/agent_mode.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("AgentInfo", () {
    test("decodes unknown modes tolerantly", () {
      final agent = AgentInfo.fromJson({
        "name": "planner",
        "description": "Plans tasks",
        "model": {"modelID": "gpt-4.1", "providerID": "openai"},
        "variant": "high",
        "mode": "experimental",
        "hidden": true,
      });

      expect(agent.mode, equals(AgentMode.unknown));

      final pluginAgent = agent.toPlugin();
      expect(pluginAgent.mode, equals(PluginAgentMode.unknown));
      expect(pluginAgent.model, equals(const PluginAgentModel(modelID: "gpt-4.1", providerID: "openai")));
    });
  });
}
