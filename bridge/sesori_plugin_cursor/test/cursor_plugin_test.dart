import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:test/test.dart";

void main() {
  group("CursorModelProbe", () {
    final session = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "configOptions": [
        {"id": "verbosity", "category": "other"},
        {
          "id": "model-picker",
          "category": "model",
          "currentValue": "gpt-5.4",
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
      ],
    });

    test("finds the model config by category, not by id", () {
      final config = CursorModelProbe.findModelConfig(session);
      expect(config, isNotNull);
      expect(config!["id"], "model-picker");
      expect(CursorModelProbe.currentValue(config), "gpt-5.4");
      expect(CursorModelProbe.models(config), hasLength(2));
      expect(CursorModelProbe.hasModel(CursorModelProbe.models(config), "sonnet-4.6"), isTrue);
      expect(CursorModelProbe.hasModel(CursorModelProbe.models(config), "nope"), isFalse);
    });

    test("returns null when no model option is present", () {
      final none = AcpNewSessionResult.fromJson({"sessionId": "s", "configOptions": <Object?>[]});
      expect(CursorModelProbe.findModelConfig(none), isNull);
    });
  });

  group("CursorPlugin", () {
    test("id is cursor", () {
      final plugin = CursorPlugin(processFactory: (_) async => FakeAcpProcess());
      expect(plugin.id, "cursor");
    });

    test("applyModelSelection populates providers and agents", () async {
      final plugin = CursorPlugin(
        projectCwd: "/repo",
        processFactory: (_) async => FakeAcpProcess(),
      );
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => FakeAcpProcess(),
      );
      final session = AcpNewSessionResult.fromJson({
        "sessionId": "s1",
        "configOptions": [
          {
            "id": "model-picker",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
        ],
      });

      // model=null reads the current value without issuing set_config_option.
      await plugin.applyModelSelection(client, session, null);

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, hasLength(1));
      final provider = providers.providers.single;
      expect(provider.id, "cursor");
      expect(provider.models, hasLength(2));
      expect(provider.defaultModelID, "gpt-5.4");

      final agents = await plugin.getAgents();
      expect(agents.single.model?.modelID, "gpt-5.4");
      expect(agents.single.model?.providerID, "cursor");

      await plugin.dispose();
    });

    test("getProviders is empty before any session", () async {
      final plugin = CursorPlugin(processFactory: (_) async => FakeAcpProcess());
      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, isEmpty);
      await plugin.dispose();
    });
  });
}
