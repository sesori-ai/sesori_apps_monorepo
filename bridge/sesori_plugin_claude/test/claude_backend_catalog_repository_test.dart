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
            {
              "value": "opus[1m]",
              "resolvedModel": "claude-opus-test",
              "displayName": "Opus (1M context)",
              "supportsEffort": true,
              "supportedEffortLevels": ["low", "medium", "future", "high", "xhigh", "max"],
            },
          ],
          "account": {"email": "private@example.com"},
        },
      );

      expect(catalog.agents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(catalog.agents.every((agent) => agent.model?.modelID == "opus[1m]"), isTrue);
      expect(catalog.agents.every((agent) => agent.model?.variant == "high"), isTrue);
      final provider = catalog.providers.providers.single;
      expect(provider.id, "anthropic");
      expect(provider.name, "Anthropic");
      expect(provider.authType, PluginProviderAuthType.oauth);
      expect(provider.defaultModelID, "opus[1m]");
      expect(provider.models.map((model) => model.id), ["opus[1m]", "haiku"]);
      expect(provider.models.first.variants, ["max", "xhigh", "high", "medium", "low"]);
      expect(provider.models.first.defaultVariant, "high");
      expect(provider.models.last.variants, isEmpty);
      expect(provider.models.last.defaultVariant, isNull);
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

    test("maps API model names back to picker ids, exactly or by bare name", () {
      final catalog = repository.map(
        handshake: {
          "models": [
            {"value": "default", "resolvedModel": "claude-opus-5[1m]"},
            {"value": "opus[1m]", "resolvedModel": "claude-opus-5[1m]"},
            {"value": "fable", "resolvedModel": "claude-fable-5-1"},
            {"value": "haiku"},
          ],
        },
      );

      expect(catalog.catalogModelId(apiModel: "claude-fable-5-1"), "fable");
      expect(catalog.catalogModelId(apiModel: "claude-opus-5[1m]"), "opus[1m]");
      expect(catalog.catalogModelId(apiModel: "claude-opus-5"), "opus[1m]");
      expect(catalog.catalogModelId(apiModel: "claude-haiku-5"), isNull);
      expect(catalog.catalogModelId(apiModel: "opus[1m]"), isNull);
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

      expect(catalog.agents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(catalog.agents.every((agent) => agent.model == null), isTrue);
      expect(catalog.providers.providers, isEmpty);
      expect(catalog.commands, isEmpty);
    });
  });
}
