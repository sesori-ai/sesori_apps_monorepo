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
      ],
    };

    setUp(() {
      fake = FakeAcpProcess();
      plugin = CursorPlugin(
        projectCwd: "/repo",
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

    test("captureSessionConfig populates providers, mode variants, and agents", () async {
      plugin.captureSessionConfig(catalogResult());

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, hasLength(1));
      final provider = providers.providers.single;
      expect(provider.id, "cursor");
      expect(provider.models, hasLength(2));
      expect(provider.defaultModelID, "gpt-5.4");
      // Every model exposes Cursor's modes as variants, default mode first.
      expect(provider.models.first.variants, ["agent", "plan", "ask"]);

      final agents = await plugin.getAgents(projectId: "/repo");
      expect(agents.single.model?.modelID, "gpt-5.4");
      expect(agents.single.model?.providerID, "cursor");
    });

    test("applyTurnSelection drives model + mode set_config_option calls", () async {
      plugin.captureSessionConfig(catalogResult());

      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "plan"),
      );
      await respond("session/set_config_option", const {}); // model
      await respond("session/set_config_option", const {}); // mode
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets, hasLength(2));
      expect(sets[0]["configId"], "model");
      expect(sets[0]["value"], "sonnet-4.6");
      expect(sets[1]["configId"], "mode");
      expect(sets[1]["value"], "plan");

      // The same model on a follow-up turn is not re-pushed (cursor persists it).
      final again = plugin.applyTurnSelection(
        client: client,
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "plan"),
      );
      await again;
      final setsAfter = fake.written.where((f) => f["method"] == "session/set_config_option");
      expect(setsAfter, hasLength(2), reason: "unchanged model+mode are not re-applied");

      await client.dispose();
    });

    test("applyTurnSelection never pushes an unknown model", () async {
      plugin.captureSessionConfig(catalogResult());
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
      );
      // A null variant resolves to the default mode (agent) and is asserted, so
      // the session is guaranteed in a known mode; the unknown model is dropped.
      await respond("session/set_config_option", const {}); // mode=agent
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets.where((s) => s["configId"] == "model"), isEmpty,
          reason: "unknown model is never pushed");
      expect(sets.where((s) => s["configId"] == "mode" && s["value"] == "agent"), hasLength(1));

      await client.dispose();
    });

    test("a default (null) model is re-applied when another model is active", () async {
      // Cursor's model selection is process-global: if one session selects a
      // non-default model, a later turn that uses the default must push it back,
      // or it silently runs on the other session's model.
      plugin.captureSessionConfig(catalogResult()); // default gpt-5.4
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      // Session A explicitly selects sonnet-4.6 (and the default mode).
      final selecting = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
      );
      await respond("session/set_config_option", const {}); // model=sonnet-4.6
      await respond("session/set_config_option", const {}); // mode=agent
      await selecting;

      // Session B uses the default (null) model — must reset the process-global
      // selection back to gpt-5.4 rather than inherit sonnet-4.6.
      final defaulting = plugin.applyTurnSelection(
        client: client,
        sessionId: "sB",
        model: null,
        variant: null,
      );
      await respond("session/set_config_option", const {}); // model=gpt-5.4 (reapplied)
      await defaulting;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4"],
          reason: "the default model is re-pushed when a different one was left active");

      await client.dispose();
    });

    test("a session's null-model turn re-applies its own model, not the global default", () async {
      // Interleaved sessions: sA selected sonnet-4.6, sB selected gpt-5.4. A
      // later null-model turn on sA must re-apply sonnet-4.6 (sA's own model),
      // not fall back to the process-global default and run on gpt-5.4.
      plugin.captureSessionConfig(catalogResult()); // default gpt-5.4
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      // sA -> sonnet-4.6 (model + default mode).
      final a = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
      );
      await respond("session/set_config_option", const {}); // model sonnet-4.6
      await respond("session/set_config_option", const {}); // mode agent
      await a;

      // sB -> gpt-5.4, leaving the process-global selection on gpt-5.4.
      final b = plugin.applyTurnSelection(
        client: client,
        sessionId: "sB",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
      );
      await respond("session/set_config_option", const {}); // model gpt-5.4
      await b;

      // sA again with a null model -> must push sonnet-4.6 back.
      final aAgain = plugin.applyTurnSelection(
        client: client,
        sessionId: "sA",
        model: null,
        variant: null,
      );
      await respond("session/set_config_option", const {}); // model sonnet-4.6 (reapplied)
      await aAgain;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4", "sonnet-4.6"],
          reason: "sA's null-model turn re-applies its own model, not the global default");

      await client.dispose();
    });

    test("a rejected model switch stamps the model actually in effect", () async {
      plugin.captureSessionConfig(catalogResult()); // default gpt-5.4
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
      );
      // The agent rejects the model switch and keeps its current model.
      final modelFrame = await waitForFrame("session/set_config_option");
      fake.emit({
        "jsonrpc": "2.0",
        "id": modelFrame["id"],
        "error": {"code": -32000, "message": "rejected"},
      });
      await pump();
      await respond("session/set_config_option", const {}); // mode agent still applies
      await applying;

      // The session is stamped with the model actually in effect (the default),
      // not the rejected sonnet-4.6.
      expect(plugin.eventMapper.modelForSession("s1"), "gpt-5.4");

      await client.dispose();
    });

    test("onConnectionReset re-applies model+mode after an agent respawn", () async {
      // Cursor's set_config_option is process-global; a respawned agent has
      // applied nothing. The applied-cache must be cleared on reset or the
      // redundant-call guard skips re-pushing and the turn runs on the fresh
      // process's defaults instead of the user's selection.
      plugin.captureSessionConfig(catalogResult());
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
          variant: const PluginSessionVariant(id: "plan"),
        );
        await respond("session/set_config_option", const {}); // model
        await respond("session/set_config_option", const {}); // mode
        await applying;
      }

      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(2),
      );

      // Simulate the agent process exiting and being torn down for a respawn.
      plugin.onConnectionReset();

      // The same model+mode must be pushed again to the fresh agent.
      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(4),
        reason: "the applied-cache is cleared on reset, so the selection is re-pushed",
      );

      await client.dispose();
    });

    test("getProviders tolerates a malformed model option and derives a safe default", () async {
      // No currentValue, and the first option has a non-string value: the old
      // `_models.first["value"] as String?` default would have thrown.
      plugin.captureSessionConfig({
        "sessionId": "s1",
        "configOptions": [
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
      expect(provider.models.map((m) => m.id), ["gpt-5.4"],
          reason: "the malformed entry is dropped, not force-cast");
      expect(provider.defaultModelID, "gpt-5.4");
    });

    test("getProviders is empty before any session/catalog", () async {
      final providers = plugin.getProviders(projectId: "/repo");
      // _ensureCatalog connects and probes; the agent reports no list capability
      // and no sessions, so the catalog stays empty.
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect((await providers).providers, isEmpty);
    });
  });
}
