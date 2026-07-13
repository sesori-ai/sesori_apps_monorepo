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

    Map<String, dynamic> catalogResult() => {
      "sessionId": "s1",
      "configOptions": [
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

    setUp(() {
      fake = FakeAcpProcess();
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
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
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
      expect(agents.map((a) => a.name), ["agent", "plan", "ask"]);
      expect(agents.map((a) => a.description), ["Agent", "Plan", "Ask"]);
      // Mode agents omit model so mobile mode switches preserve model/effort.
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
        (await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID,
        "sonnet-4.6",
        reason: "session/new's currentValue is the new-session default, even when it isn't the first model",
      );
    });

    test("a session/load (or probe) does not overwrite the new-session default", () async {
      plugin.captureSessionConfig(modelCatalog("gpt-5.4"), sessionId: "new-1", fromNewSession: true);
      expect((await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID, "gpt-5.4");

      plugin.captureSessionConfig(modelCatalog("sonnet-4.6"), sessionId: "old");
      plugin.captureSessionConfig(modelCatalog("sonnet-4.6"));

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
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {}); // model sonnet
      await respond("session/set_config_option", const {}); // effort high again
      await second;

      final effortSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort")
          .map((p) => p["value"])
          .toList();
      expect(effortSets, ["high", "high"],
          reason: "the same effort string must be re-pushed after a model change");

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
      expect(sets.where((s) => s["configId"] == "model"), isEmpty,
          reason: "unknown model is never pushed");
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
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {}); // model=gpt-5.4
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
      await respond("session/set_config_option", const {});
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
      await respond("session/set_config_option", const {}); // model
      await respond("session/set_config_option", const {}); // effort re-applied
      await b;

      final aAgain = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: null,
        variant: null,
        agent: null,
      );
      await respond("session/set_config_option", const {}); // model
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
      await respond("session/set_config_option", const {});
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
        await respond("session/set_config_option", const {});
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
      final providers = await plugin.getProviders(projectId: "/repo");
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

      final providers = await plugin.getProviders(projectId: "/repo");
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(provider.defaultModelID, "gpt-5.4");
    });
  });
}
