import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorModelProbe", () {
    final session = AcpNewSessionResult.fromJson({
      "sessionId": "s1",
      "configOptions": [
        {"id": "verbosity", "category": "other"},
        {
          "id": "mode-picker",
          "category": "mode",
          "currentValue": "agent",
          "options": [
            {"value": "agent", "name": "Agent"},
            {"value": "plan", "name": "Plan"},
          ],
        },
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

    test("finds a config by category, not by id", () {
      final model = CursorModelProbe.findConfig(session, "model");
      expect(model, isNotNull);
      expect(model!["id"], "model-picker");
      expect(CursorModelProbe.currentValue(model), "gpt-5.4");
      expect(CursorModelProbe.options(model), hasLength(2));

      final mode = CursorModelProbe.findConfig(session, "mode");
      expect(mode!["id"], "mode-picker");
      expect(CursorModelProbe.currentValue(mode), "agent");
    });

    test("findModelConfig + hasModel back-compat helpers", () {
      final config = CursorModelProbe.findModelConfig(session)!;
      expect(CursorModelProbe.models(config), hasLength(2));
      expect(CursorModelProbe.hasModel(CursorModelProbe.models(config), "sonnet-4.6"), isTrue);
      expect(CursorModelProbe.hasModel(CursorModelProbe.models(config), "nope"), isFalse);
    });

    test("returns null when the category is absent", () {
      final none = AcpNewSessionResult.fromJson({"sessionId": "s", "configOptions": <Object?>[]});
      expect(CursorModelProbe.findModelConfig(none), isNull);
      expect(CursorModelProbe.findConfig(none, "mode"), isNull);
    });

    test("findThoughtLevelConfig prefers multi-level reasoning over effort", () {
      final thoughtSession = AcpNewSessionResult.fromJson({
        "sessionId": "s",
        "configOptions": [
          {
            "id": "thinking",
            "category": "thought_level",
            "currentValue": "true",
            "options": [
              {"value": "true", "name": "On"},
              {"value": "false", "name": "Off"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
          {
            "id": "reasoning",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      });
      final config = CursorModelProbe.findThoughtLevelConfig(thoughtSession)!;
      expect(config["id"], "reasoning");
    });

    test("findThoughtLevelConfig ignores binary thought toggles", () {
      final thoughtSession = AcpNewSessionResult.fromJson({
        "sessionId": "s",
        "configOptions": [
          {
            "id": "reasoning",
            "category": "thought_level",
            "currentValue": "on",
            "options": [
              {"value": "on", "name": "On"},
              {"value": "off", "name": "Off"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "true",
            "options": [
              {"value": "true", "name": "On"},
              {"value": "false", "name": "Off"},
            ],
          },
        ],
      });

      expect(CursorModelProbe.findThoughtLevelConfig(thoughtSession), isNull);
    });

    test("resolveModeId matches by value or display name", () {
      final modes = [
        {"value": "agent", "name": "Agent"},
        {"value": "plan", "name": "Plan"},
      ];
      expect(CursorModelProbe.resolveModeId(modes, "plan"), "plan");
      expect(CursorModelProbe.resolveModeId(modes, "Plan"), "plan");
      expect(CursorModelProbe.resolveModeId(modes, "nope"), isNull);
    });

    test("options flattens grouped select options", () {
      final grouped = AcpNewSessionResult.fromJson({
        "sessionId": "s",
        "configOptions": [
          {
            "id": "model-picker",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {
                "group": "openai",
                "name": "OpenAI",
                "options": [
                  {"value": "gpt-5.4", "name": "GPT-5.4"},
                ],
              },
              {
                "group": "anthropic",
                "name": "Anthropic",
                "options": [
                  {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
                  {"value": "opus-4.8", "name": "Opus 4.8"},
                ],
              },
            ],
          },
        ],
      });
      final config = CursorModelProbe.findModelConfig(grouped)!;
      final options = CursorModelProbe.options(config);
      expect(options.map((o) => o["value"]), ["gpt-5.4", "sonnet-4.6", "opus-4.8"]);
      expect(CursorModelProbe.hasOption(options, "opus-4.8"), isTrue);
    });
  });

  group("CursorPlugin", () {
    late FakeAcpProcess fake;
    late CursorPlugin plugin;
    late Set<Object?> handledFrameIds;

    Map<String, dynamic> catalogResult() => {
      "sessionId": "s1",
      "configOptions": [
        {
          "id": "mode",
          "category": "mode",
          "currentValue": "agent",
          "options": [
            {
              "value": "agent",
              "name": "Agent",
              "description": "Works autonomously",
            },
            {
              "value": "plan",
              "name": "Plan",
              "description": "Plans before editing",
            },
            {
              "value": "ask",
              "name": "Ask",
              "description": "Answers without editing",
            },
          ],
        },
        {
          "id": "model",
          "category": "model",
          "currentValue": "gpt-5.4",
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        {
          "id": "effort",
          "category": "thought_level",
          "currentValue": "medium",
          "options": [
            {"value": "low", "name": "Low"},
            {"value": "medium", "name": "Medium"},
            {"value": "high", "name": "High"},
          ],
        },
      ],
    };

    Map<String, dynamic> effortModelSelectionResult({required String modelId}) => {
      "configOptions": [
        {
          "id": "model",
          "category": "model",
          "currentValue": modelId,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        {
          "id": "effort",
          "category": "thought_level",
          "currentValue": "medium",
          "options": [
            {"value": "low", "name": "Low"},
            {"value": "medium", "name": "Medium"},
            {"value": "high", "name": "High"},
          ],
        },
      ],
    };

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = CursorPlugin(
        launchDirectory: "/repo",
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where(
          (frame) => frame["method"] == method && !handledFrameIds.contains(frame["id"]),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrameIds.add(frame["id"]);
          return frame;
        }
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    // getProviders now warms the catalog before returning (so a fresh session's
    // effort pill is populated up front). That needs the ACP handshake. For a
    // test that only reads back a directly-captured catalog, service a
    // no-capability agent (no session list) so the warm-up probe is an instant
    // no-op, then return the providers. Use only for the FIRST fetch on a
    // plugin — afterward the probe-completed latch skips warm-up, so there is no
    // initialize frame to answer.
    Future<PluginProvidersResult> providersAfterWarmup() async {
      final future = plugin.getProviders(projectId: "/repo");
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      return future;
    }

    test("id is cursor", () {
      expect(plugin.id, "cursor");
    });

    test("the default binary is the official Cursor CLI name", () {
      expect(CursorBinary.defaultBinary, "agent");
      final spec = CursorBinary.launchSpec(cwd: "/repo");
      expect(spec.command, "agent");
      expect(spec.args, ["acp"]);
    });

    test("captureSessionConfig populates providers, effort variants, and mode agents", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, hasLength(1));
      final provider = providers.providers.single;
      expect(provider.id, "cursor");
      expect(provider.models, hasLength(2));
      expect(provider.defaultModelID, "gpt-5.4");
      // Effort levels are per-model variants, default effort first. Sibling
      // models get a provisional copy so the first providers response is complete.
      expect(provider.models.first.variants, ["medium", "low", "high"]);
      expect(provider.models.last.variants, ["medium", "low", "high"]);

      final agents = await plugin.getAgents(projectId: "/repo");
      expect(agents.map((a) => a.name), ["Agent", "Plan", "Ask"]);
      expect(
        agents.map((a) => a.description),
        ["Works autonomously", "Plans before editing", "Answers without editing"],
      );
      expect(agents.every((a) => a.model == null), isTrue);
    });

    Map<String, dynamic> modelCatalog(String currentValue, {bool includeMode = true}) => {
      "sessionId": "s",
      "configOptions": [
        if (includeMode)
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
              {"value": "plan", "name": "Plan"},
              {"value": "ask", "name": "Ask"},
            ],
          },
        {
          "id": "model",
          "category": "model",
          "currentValue": currentValue,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
      ],
    };

    test("a session/new capture seeds the new-session default model", () async {
      plugin.captureSessionConfig(modelCatalog("sonnet-4.6"), sessionId: "new-1", fromNewSession: true);
      expect(
        (await providersAfterWarmup()).providers.single.defaultModelID,
        "sonnet-4.6",
        reason: "session/new's currentValue is the new-session default, even when it isn't the first model",
      );
    });

    test("a session/load (or probe) does not overwrite the new-session default", () async {
      plugin.captureSessionConfig(modelCatalog("gpt-5.4"), sessionId: "new-1", fromNewSession: true);
      // First fetch warms the catalog (probe-completed latch is then set).
      expect((await providersAfterWarmup()).providers.single.defaultModelID, "gpt-5.4");

      plugin.captureSessionConfig(modelCatalog("sonnet-4.6"), sessionId: "old");
      plugin.captureSessionConfig(modelCatalog("sonnet-4.6"));

      // Latched: this fetch reads back without re-warming.
      expect(
        (await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID,
        "gpt-5.4",
        reason: "neither a load nor a probe may change the new-session default",
      );
    });

    test("applyTurnSelection drives model + mode + effort from agent and variant", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);

      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "plan",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // mode=plan
      await respond("session/set_config_option", const {}); // effort=high
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets, hasLength(3));
      expect(sets[0]["configId"], "model");
      expect(sets[0]["value"], "sonnet-4.6");
      expect(sets[1]["configId"], "mode");
      expect(sets[1]["value"], "plan");
      expect(sets[2]["configId"], "effort");
      expect(sets[2]["value"], "high");

      final again = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "plan",
      );
      await again;
      final setsAfter = fake.written.where((f) => f["method"] == "session/set_config_option");
      expect(setsAfter, hasLength(3), reason: "unchanged model+mode+effort are not re-applied");

      await client.dispose();
    });

    test("applyTurnSelection resolves mode from display name agent", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: "Ask",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode=ask
      await respond("session/set_config_option", const {}); // effort=medium
      await applying;

      final modeSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "mode")
          .map((p) => p["value"])
          .toList();
      expect(modeSets, ["ask"]);

      await client.dispose();
    });

    test("applyTurnSelection re-applies the same effort after a model switch", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final first = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort high
      await first;

      final second = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model sonnet
      await respond("session/set_config_option", const {}); // effort high again
      await second;

      final effortSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort")
          .map((p) => p["value"])
          .toList();
      expect(effortSets, ["high", "high"], reason: "the same effort string must be re-pushed after a model change");

      await client.dispose();
    });

    test("applyTurnSelection uses per-model thought_level config ids", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final first = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "reasoning",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      }); // model -> stamps reasoning for gpt
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort/reasoning high
      await first;

      final second = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "sonnet-4.6",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      }); // model -> stamps effort for sonnet
      await respond("session/set_config_option", const {}); // high on effort
      await second;

      final thoughtSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort" || p["configId"] == "reasoning")
          .map((p) => "${p["configId"]}=${p["value"]}")
          .toList();
      expect(thoughtSets, ["reasoning=high", "effort=high"]);

      await client.dispose();
    });

    test("applyTurnSelection does not reuse another model's thought config id", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
      );
      await respond(
        "session/set_config_option",
        modelCatalog("sonnet-4.6"),
      ); // model response has no thought_level option
      await respond("session/set_config_option", const {}); // mode=plan
      await applying;

      final configIds = fake.written
          .where((frame) => frame["method"] == "session/set_config_option")
          .map((frame) => frame["params"] as Map)
          .map((params) => params["configId"])
          .toList();
      expect(configIds, ["model", "mode"]);

      await client.dispose();
    });

    test("applyTurnSelection restores the selected model's default effort", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final selectingHigh = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "sonnet-4.6",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "low",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      });
      await respond("session/set_config_option", const {}); // mode=plan
      await respond("session/set_config_option", const {}); // effort=high
      await selectingHigh;

      final restoringDefault = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: "Plan",
      );
      await respond("session/set_config_option", const {}); // effort=low
      await restoringDefault;

      final effortSets = fake.written
          .where((frame) => frame["method"] == "session/set_config_option")
          .map((frame) => (frame["params"] as Map).cast<String, dynamic>())
          .where((params) => params["configId"] == "effort")
          .map((params) => params["value"])
          .toList();
      expect(effortSets, ["high", "low"]);

      await client.dispose();
    });

    test("applyTurnSelection never pushes an unknown model", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "not-a-real-model"),
        variant: null,
        agent: null,
      );
      await respond("session/set_config_option", const {}); // mode=agent
      await respond("session/set_config_option", const {}); // effort=medium
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets.where((s) => s["configId"] == "model"), isEmpty, reason: "unknown model is never pushed");
      expect(sets.where((s) => s["configId"] == "mode" && s["value"] == "agent"), hasLength(1));
      expect(sets.where((s) => s["configId"] == "effort" && s["value"] == "medium"), hasLength(1));

      await client.dispose();
    });

    test("applyTurnSelection does not push unknown effort", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "not-a-real-effort"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await applying;

      final effortSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort");
      expect(effortSets, isEmpty, reason: "unknown effort is fail-closed");

      await client.dispose();
    });

    test("a default (null) model is re-applied when another model is active", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final selecting = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort
      await selecting;

      final defaulting = plugin.applyTurnSelection(
        client: client,
        sessionId: "sB",
        model: null,
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model=gpt-5.4
      await respond("session/set_config_option", const {}); // effort re-applied after model change
      await defaulting;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4"]);

      await client.dispose();
    });

    test("a session's null-model turn re-applies its own model, not the global default", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final a = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      );
      await respond("session/set_config_option", const {});
      await respond("session/set_config_option", const {});
      await a;

      final b = plugin.applyTurnSelection(
        client: client,
        sessionId: "sB",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // effort re-applied
      await b;

      final aAgain = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: null,
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // effort re-applied
      await aAgain;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4", "sonnet-4.6"]);

      await client.dispose();
    });

    test("a rejected model switch stamps the model actually in effect", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      final modelFrame = await waitForFrame("session/set_config_option");
      fake.emit({
        "jsonrpc": "2.0",
        "id": modelFrame["id"],
        "error": {"code": -32000, "message": "rejected"},
      });
      await pump();
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort
      await applying;

      expect(plugin.eventMapper.modelForSession("s1"), "gpt-5.4");

      await client.dispose();
    });

    test("a rejected switch does not inherit another session's model", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final a = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      );
      await respond("session/set_config_option", const {});
      await respond("session/set_config_option", const {});
      await a;

      final b = plugin.applyTurnSelection(
        client: client,
        sessionId: "sB",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: null,
      );
      final modelFrame = await waitForFrame("session/set_config_option");
      fake.emit({
        "jsonrpc": "2.0",
        "id": modelFrame["id"],
        "error": {"code": -32000, "message": "rejected"},
      });
      await pump();
      await b;

      expect(plugin.eventMapper.modelForSession("sB"), "gpt-5.4");

      await client.dispose();
    });

    test("onConnectionReset re-applies model+mode+effort after an agent respawn", () async {
      plugin.captureSessionConfig(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      Future<void> applyOnce() async {
        final applying = plugin.applyTurnSelection(
          client: client,
          sessionId: "s1",
          model: (providerID: "cursor", modelID: "sonnet-4.6"),
          variant: const PluginSessionVariant(id: "high"),
          agent: "plan",
        );
        await respond(
          "session/set_config_option",
          effortModelSelectionResult(modelId: "sonnet-4.6"),
        );
        await respond("session/set_config_option", const {});
        await respond("session/set_config_option", const {});
        await applying;
      }

      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(3),
      );

      plugin.onConnectionReset();

      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(6),
        reason: "the applied-cache is cleared on reset, so the selection is re-pushed",
      );

      await client.dispose();
    });

    test("getProviders tolerates a malformed model option and derives a safe default", () async {
      plugin.captureSessionConfig({
        "sessionId": "s1",
        "configOptions": [
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
            ],
          },
          {
            "id": "model",
            "category": "model",
            "options": [
              {"value": 123, "name": "Bad"},
              {"value": "gpt-5.4", "name": "GPT-5.4"},
            ],
          },
        ],
      });
      final providers = await providersAfterWarmup();
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), ["gpt-5.4"]);
      expect(provider.defaultModelID, "gpt-5.4");
    });

    test("getProviders is empty before any session/catalog", () async {
      final providers = plugin.getProviders(projectId: "/repo");
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect((await providers).providers, isEmpty);
    });

    test("a models-only capture surfaces effort variants once thought_level is captured", () async {
      plugin.captureSessionConfig(modelCatalog("gpt-5.4", includeMode: false), fromNewSession: true);
      plugin.captureSessionConfig(catalogResult(), fromNewSession: false);
      final full = await plugin.getProviders(projectId: "/repo");
      expect(full.providers.single.models.first.variants, ["medium", "low", "high"]);
    });

    test("a grouped model catalog surfaces every nested model", () async {
      plugin.captureSessionConfig({
        "sessionId": "s1",
        "configOptions": [
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
            ],
          },
          {
            "id": "model",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {
                "group": "openai",
                "name": "OpenAI",
                "options": [
                  {"value": "gpt-5.4", "name": "GPT-5.4"},
                ],
              },
              {
                "group": "anthropic",
                "name": "Anthropic",
                "options": [
                  {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
                ],
              },
            ],
          },
        ],
      }, fromNewSession: true);

      final providers = await providersAfterWarmup();
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(provider.defaultModelID, "gpt-5.4");
    });
  });

  // The catalog warm-up walk seeds a provisional effort scale before the first
  // turn so the composer's effort pill shows for a fresh session. Cursor only
  // reveals a model's effort for a model active in a session, so the bridge
  // `session/load`s recent sessions until a reasoning one is found. These drive
  // the real getProviders -> _ensureCatalog -> probe path end to end, so the
  // probe spawns its own process — a fresh fake per spawn (not the shared one).
  group("CursorPlugin catalog warm-up", () {
    final fakes = <FakeAcpProcess>[];
    late CursorPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fakes.clear();
      plugin = CursorPlugin(
        launchDirectory: cwd,
        processFactory: (_) async {
          final fake = FakeAcpProcess();
          fakes.add(fake);
          return fake;
        },
      );
    });

    tearDown(() async {
      await plugin.dispose();
      for (final fake in fakes) {
        await fake.close();
      }
    });

    List<Map<String, dynamic>> allWritten() =>
        [for (final fake in fakes) ...fake.written];

    Map<String, dynamic> listSession(String id, {required int updatedAt}) =>
        {"sessionId": id, "cwd": cwd, "title": id, "updatedAt": updatedAt};

    // A `session/load` result carrying Cursor's model + mode config, and — only
    // for a reasoning model — a multi-level effort `thought_level`.
    Map<String, dynamic> loadResult({
      required String currentModel,
      required bool reasoning,
    }) => {
      "sessionId": "ignored",
      "configOptions": [
        {
          "id": "mode",
          "category": "mode",
          "currentValue": "agent",
          "options": [
            {"value": "agent", "name": "Agent"},
            {"value": "plan", "name": "Plan"},
          ],
        },
        {
          "id": "model",
          "category": "model",
          "currentValue": currentModel,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        if (reasoning)
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
      ],
    };

    /// Background agent answering initialize / session/list / session/load
    /// across every spawned fake until stopped.
    void Function() autoAnswer({
      required List<Map<String, dynamic>> listSessions,
      required Map<String, Map<String, dynamic>> loadResults,
      List<String>? loadOrder,
    }) {
      final answered = <(FakeAcpProcess, Object?)>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final fake in fakes.toList()) {
            for (final frame in fake.written.toList()) {
              final id = frame["id"];
              if (id == null || !answered.add((fake, id))) continue;
              final Map<String, dynamic> result;
              switch (frame["method"]) {
                case "initialize":
                  result = {
                    "protocolVersion": 1,
                    "agentCapabilities": {
                      "loadSession": true,
                      "sessionCapabilities": {"list": <String, dynamic>{}},
                    },
                    "authMethods": <Object?>[],
                  };
                case "session/list":
                  result = {"sessions": listSessions};
                case "session/load":
                  final sid = (frame["params"] as Map).cast<String, dynamic>()["sessionId"] as String;
                  loadOrder?.add(sid);
                  result = loadResults[sid] ?? const {};
                default:
                  answered.remove((fake, id));
                  continue;
              }
              fake.emit({"jsonrpc": "2.0", "id": id, "result": result});
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());
      return () => running = false;
    }

    test("seeds provisional effort when the newest session is non-reasoning but an older one is reasoning", () async {
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          listSession("s-new", updatedAt: 3000),
          listSession("s-old", updatedAt: 1000),
        ],
        loadResults: {
          // Newest session's model has no effort scale.
          "s-new": loadResult(currentModel: "gpt-5.4", reasoning: false),
          // Older session's model does.
          "s-old": loadResult(currentModel: "sonnet-4.6", reasoning: true),
        },
        loadOrder: loadOrder,
      );

      final providers = await plugin.getProviders(projectId: cwd);
      stop();

      expect(loadOrder, ["s-new", "s-old"], reason: "walked newest-first until the reasoning session seeded effort");
      final models = providers.providers.single.models;
      expect(models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(
        models.every((m) => m.variants.isNotEmpty),
        isTrue,
        reason: "every model shows the provisional effort scale so the pill renders",
      );
      // Default effort first, then the rest — the provisional scale from s-old.
      expect(models.first.variants, ["medium", "low", "high"]);
    });

    test("returns empty variants (no hang, no throwaway session) when no session is reasoning", () async {
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          listSession("s-new", updatedAt: 3000),
          listSession("s-old", updatedAt: 1000),
        ],
        loadResults: {
          "s-new": loadResult(currentModel: "gpt-5.4", reasoning: false),
          "s-old": loadResult(currentModel: "gpt-5.4", reasoning: false),
        },
        loadOrder: loadOrder,
      );

      final providers = await plugin.getProviders(projectId: cwd);

      final models = providers.providers.single.models;
      expect(models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(
        models.every((m) => m.variants.isEmpty),
        isTrue,
        reason: "no reasoning session anywhere -> no effort scale to show",
      );
      expect(
        allWritten().where((f) => f["method"] == "session/new"),
        isEmpty,
        reason: "warm-up must never create a throwaway session",
      );
      expect(loadOrder, ["s-new", "s-old"], reason: "both sessions walked (under the bound), neither reasoning");

      // A second fetch must not re-walk: the exhaustion latch holds, so no new
      // probe process is spawned.
      final fakesAfterFirst = fakes.length;
      final again = await plugin.getProviders(projectId: cwd);
      stop();
      expect(again.providers.single.models.every((m) => m.variants.isEmpty), isTrue);
      expect(
        fakes.length,
        fakesAfterFirst,
        reason: "the latch stops a re-walk, so no additional probe process spawns",
      );
    });
  });
}
