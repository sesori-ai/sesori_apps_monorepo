import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ClaudeBackendCatalogRepository", () {
    const repository = ClaudeBackendCatalogRepository();

    test("maps models, effort variants, commands, and permission-mode agents", () {
      final catalog = repository.map(
        handshake: {
          "commands": [
            {"name": "review", "description": "Review changes", "argumentHint": "<scope>"},
          ],
          "agents": [
            {"name": "general-purpose", "description": "Not user-facing"},
          ],
          "models": [
            {
              "value": "default",
              "resolvedModel": "claude-opus-test",
              "displayName": "Default (recommended)",
              "supportsEffort": true,
              "supportedEffortLevels": ["low", "medium", "future", "high", "xhigh", "max"],
            },
            {
              "value": "haiku",
              "resolvedModel": "claude-haiku-test",
              "displayName": "Haiku",
            },
          ],
          "account": {"email": "private@example.com"},
        },
      );

      expect(catalog.agents.map((agent) => agent.name), ["Default", "Plan"]);
      expect(catalog.agents.every((agent) => agent.model?.modelID == "default"), isTrue);
      final provider = catalog.providers.providers.single;
      expect(provider, isA<PluginProviderAnthropic>());
      expect(provider.id, "anthropic");
      expect(provider.defaultModelID, "default");
      expect(provider.models.map((model) => model.id), ["default", "haiku"]);
      expect(provider.models.first.variants, ["low", "medium", "high", "xhigh", "max"]);
      expect(provider.models.last.variants, isEmpty);
      expect(
        catalog.commands,
        const [
          PluginCommand(
            name: "review",
            description: "Review changes",
            hints: ["<scope>"],
            provider: null,
            source: PluginCommandSource.command,
          ),
        ],
      );
    });

    test("filters malformed entries and falls back to the first model", () {
      final catalog = repository.map(
        handshake: {
          "commands": [
            {"description": "missing name"},
            "not an object",
          ],
          "models": [
            {"value": "sonnet", "resolvedModel": "claude-sonnet-test"},
            {"displayName": "missing value"},
          ],
        },
      );

      expect(catalog.commands, isEmpty);
      expect(catalog.providers.providers.single.defaultModelID, "sonnet");
      expect(catalog.providers.providers.single.models.single.name, "claude-sonnet-test");
    });

    test("returns agents but no provider for an empty model catalog", () {
      final catalog = repository.map(handshake: const {});

      expect(catalog.agents.map((agent) => agent.name), ["Default", "Plan"]);
      expect(catalog.agents.every((agent) => agent.model == null), isTrue);
      expect(catalog.providers.providers, isEmpty);
      expect(catalog.commands, isEmpty);
    });
  });
}
