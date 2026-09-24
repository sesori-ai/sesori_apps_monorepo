import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ClaudeBackendCatalogRepository", () {
    const repository = ClaudeBackendCatalogRepository();

    test("maps models, effort variants, commands, and the default agent", () {
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
              "supportsFastMode": true,
            },
          ],
          "account": {"email": "private@example.com"},
        },
      );

      expect(catalog.agents.map((agent) => agent.name), ["Agent"]);
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
        provider.models.first.fastMode,
        const PluginFastModeSupport.available(promptCacheTtlSeconds: 3600),
        reason: "a handshake without fast_mode_disabled_reason leaves fast mode available",
      );
      expect(provider.models.last.fastMode, isNull, reason: "the CLI omits supportsFastMode when unsupported");
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

    group("fast mode availability", () {
      PluginFastModeSupport? fastModeFor({required Object? disabledReason}) => repository
          .map(
            handshake: {
              "models": [
                {"value": "opus", "supportsFastMode": true},
              ],
              "fast_mode_disabled_reason": disabledReason,
            },
          )
          .providers
          .providers
          .single
          .models
          .single
          .fastMode;

      test("treats the SDK opt-in requirement as available, since the bridge opts in", () {
        expect(
          fastModeFor(disabledReason: "sdk_opt_in_required"),
          const PluginFastModeSupport.available(promptCacheTtlSeconds: 3600),
        );
      });

      test("maps account reasons to the closed reason set", () {
        const expected = {
          "extra_usage_disabled": PluginFastModeUnavailableReason.extraUsageDisabled,
          "out_of_credits": PluginFastModeUnavailableReason.outOfCredits,
          "preference": PluginFastModeUnavailableReason.disabledByOrganization,
          "model_not_allowed": PluginFastModeUnavailableReason.disabledByOrganization,
          "org_level_disabled": PluginFastModeUnavailableReason.disabledByOrganization,
          "org_spend_cap_reached": PluginFastModeUnavailableReason.spendLimitReached,
          "member_zero_credit_limit": PluginFastModeUnavailableReason.spendLimitReached,
          "not_first_party": PluginFastModeUnavailableReason.unknown,
          "a_future_reason": PluginFastModeUnavailableReason.unknown,
        };
        for (final MapEntry(key: raw, value: reason) in expected.entries) {
          expect(
            fastModeFor(disabledReason: raw),
            PluginFastModeSupport.unavailable(reason: reason),
            reason: raw,
          );
        }
      });
    });

    test("declares no default effort when effort support is off, even with levels listed", () {
      final catalog = repository.map(
        handshake: {
          "models": [
            {
              "value": "haiku",
              "supportsEffort": false,
              "supportedEffortLevels": ["low", "high"],
            },
          ],
        },
      );

      final model = catalog.providers.providers.single.models.single;
      expect(model.variants, isEmpty);
      expect(model.defaultVariant, isNull);
    });

    test("maps resolved and short API model names back to picker ids", () {
      final catalog = repository.map(
        handshake: {
          "models": [
            {"value": "default", "resolvedModel": "claude-opus-5[1m]"},
            {"value": "opus[1m]", "resolvedModel": "claude-opus-5[1m]"},
            {"value": "claude-fable-5-1[1m]", "resolvedModel": "claude-fable-5-1"},
            {"value": "haiku"},
          ],
        },
      );

      expect(catalog.providers.providers.single.models.map((model) => model.id), [
        "claude-fable-5-1[1m]",
        "opus[1m]",
        "haiku",
      ]);
      expect(catalog.catalogModelId(apiModel: "claude-fable-5-1"), "claude-fable-5-1[1m]");
      expect(catalog.catalogModelId(apiModel: "fable[1m]"), "claude-fable-5-1[1m]");
      expect(catalog.catalogModelId(apiModel: "claude-opus-5[1m]"), "opus[1m]");
      expect(catalog.catalogModelId(apiModel: "claude-opus-5"), "opus[1m]");
      expect(catalog.catalogModelId(apiModel: "opus[1m]"), "opus[1m]");
      expect(catalog.catalogModelId(apiModel: "claude-haiku-5"), isNull);
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

    test("omits the native /fast command owned by the fast-mode selection", () {
      final catalog = repository.map(
        handshake: {
          "commands": [
            {"name": "fast", "description": "Toggle fast mode", "argumentHint": "[on|off]"},
            {"name": "review", "description": "Review changes"},
          ],
        },
      );

      expect(catalog.commands.map((command) => command.name), ["review"]);
    });

    test("returns agents but no provider for an empty model catalog", () {
      final catalog = repository.map(handshake: const {});

      expect(catalog.agents.map((agent) => agent.name), ["Agent"]);
      expect(catalog.agents.every((agent) => agent.model == null), isTrue);
      expect(catalog.providers.providers, isEmpty);
      expect(catalog.commands, isEmpty);
    });
  });
}
