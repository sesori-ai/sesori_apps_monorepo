import "dart:async";

import "package:acp_plugin/acp_testing.dart";
import "package:copilot_plugin/copilot_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const Map<String, dynamic> _copilotInitializeResult = {
  "protocolVersion": 1,
  "agentCapabilities": {
    "loadSession": true,
    "mcpCapabilities": {"http": true, "sse": true},
    "promptCapabilities": {"image": true, "audio": false, "embeddedContext": true},
    "sessionCapabilities": {
      "close": <String, dynamic>{},
      "list": <String, dynamic>{},
    },
  },
  "authMethods": [
    {
      "id": "copilot-login",
      "name": "Log in with Copilot CLI",
      "description": "Run `copilot login` in the terminal",
      "_meta": {
        "terminal-auth": {
          "command": "/opt/copilot",
          "args": ["login"],
          "label": "Copilot Login",
        },
      },
    },
  ],
  "agentInfo": {"name": "Copilot", "title": "Copilot", "version": "1.0.80"},
};

void main() {
  group("CopilotPlugin", () {
    late FakeAcpProcess fake;
    late List<FakeAcpProcess> catalogFakes;
    late CopilotPlugin plugin;
    late List<Map<String, String>> launchEnvironments;
    late Set<Map<String, dynamic>> handledFrames;

    setUp(() {
      fake = FakeAcpProcess();
      catalogFakes = [FakeAcpProcess(), FakeAcpProcess()];
      handledFrames = {};
      launchEnvironments = [];
      var spawnCount = 0;
      plugin = CopilotPlugin(
        binaryPath: "/opt/copilot",
        launchDirectory: "/repo",
        environment: const {"COPILOT_HOME": "/state/copilot"},
        processFactory: (spec) async {
          launchEnvironments.add(spec.environment);
          final index = spawnCount++;
          return index == 0 ? fake : catalogFakes[index - 1];
        },
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
      await Future.wait(catalogFakes.map((catalogFake) => catalogFake.close()));
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Map<String, dynamic> catalogResult({required String model, required List<String> reasoningLevels}) => {
      "sessionId": "catalog-session",
      "configOptions": [
        {
          "id": "model",
          "category": "model",
          "currentValue": model,
          "options": [
            {"value": "gpt-5.4"},
            {"value": "claude-sonnet-4.5"},
            {"value": "gemini-3-pro"},
          ],
        },
        {
          "id": "reasoning_effort",
          "category": "thought_level",
          "currentValue": reasoningLevels.first,
          "options": [
            for (final level in reasoningLevels) {"value": level},
          ],
        },
      ],
    };

    Future<Map<String, dynamic>> waitForFrame({
      required FakeAcpProcess process,
      required String method,
    }) async {
      for (var i = 0; i < 50; i++) {
        final matches = process.written.where(
          (frame) => frame["method"] == method && !handledFrames.contains(frame),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrames.add(frame);
          return frame;
        }
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> completeHandshake({
      required FakeAcpProcess process,
      bool rejectAuthentication = false,
    }) async {
      final initialize = await waitForFrame(process: process, method: "initialize");
      process.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": _copilotInitializeResult});
      final authenticate = await waitForFrame(process: process, method: "authenticate");
      process.emit({
        "jsonrpc": "2.0",
        "id": authenticate["id"],
        if (rejectAuthentication)
          "error": {"code": -32000, "message": "authentication required"}
        else
          "result": <String, dynamic>{},
      });
    }

    test("owns the stable Copilot identity and launch arguments", () {
      expect(CopilotPluginIdentity.id, "copilot");
      expect(CopilotPluginIdentity.displayName, "GitHub Copilot");
      expect(plugin.id, CopilotPluginIdentity.id);
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      expect(plugin.launchSpec.command, "/opt/copilot");
      expect(plugin.launchSpec.args, ["--no-auto-update", "--acp"]);
      expect(plugin.launchSpec.cwd, "/repo");
      expect(plugin.launchSpec.environment, const {"COPILOT_HOME": "/state/copilot"});
    });

    Future<void> completeCatalogDiscovery({required FakeAcpProcess process}) async {
      await completeHandshake(process: process);
      final newSession = await waitForFrame(process: process, method: "session/new");
      process.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "catalog-session",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": <Map<String, dynamic>>[],
          },
        },
      });
      process.emit({
        "jsonrpc": "2.0",
        "id": newSession["id"],
        "result": {
          "sessionId": "catalog-session",
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
          ],
        },
      });
      final closeSession = await waitForFrame(process: process, method: "session/close");
      process.emit({"jsonrpc": "2.0", "id": closeSession["id"], "result": <String, dynamic>{}});
    }

    Future<void> completeReasoningDiscovery({
      required FakeAcpProcess process,
      required String selectedModel,
      required List<String> reasoningLevels,
    }) async {
      await completeHandshake(process: process);
      final newSession = await waitForFrame(process: process, method: "session/new");
      process.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "catalog-session",
          "update": {"sessionUpdate": "available_commands_update", "availableCommands": <Object>[]},
        },
      });
      process.emit({
        "jsonrpc": "2.0",
        "id": newSession["id"],
        "result": catalogResult(model: "gpt-5.4", reasoningLevels: const ["low", "high"]),
      });
      final selectModel = await waitForFrame(process: process, method: "session/set_config_option");
      expect((selectModel["params"] as Map)["value"], selectedModel);
      process.emit({
        "jsonrpc": "2.0",
        "id": selectModel["id"],
        "result": catalogResult(model: selectedModel, reasoningLevels: reasoningLevels),
      });
      final closeSession = await waitForFrame(process: process, method: "session/close");
      process.emit({"jsonrpc": "2.0", "id": closeSession["id"], "result": <String, dynamic>{}});
    }

    test("completes Copilot's standard ACP handshake", () async {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(process: fake, method: "initialize");
      final initializeParams = (initialize["params"] as Map).cast<String, dynamic>();
      final clientCapabilities = (initializeParams["clientCapabilities"] as Map).cast<String, dynamic>();
      expect(clientCapabilities, isNot(contains("elicitation")));
      fake.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": _copilotInitializeResult});

      final authenticate = await waitForFrame(process: fake, method: "authenticate");
      expect(
        (authenticate["params"] as Map).cast<String, dynamic>()["methodId"],
        CopilotBinary.acpAuthMethodId,
      );
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});

      expect(await connecting, isTrue);

      final discovering = plugin.getAgents(projectId: "/repo");
      await completeCatalogDiscovery(process: catalogFakes.first);

      expect((await discovering).map((agent) => agent.name), ["Agent", "Plan"]);
      expect(launchEnvironments.last["COPILOT_HOME"], "/state/copilot");
      expect(fake.written.where((frame) => frame["method"] == "session/new"), isEmpty);
      plugin.onConnectionReset();
      final refreshing = plugin.validateTurnSelection(
        operation: "sendPrompt",
        model: null,
        variant: null,
        agent: "Plan",
      );
      await completeCatalogDiscovery(process: catalogFakes.last);
      await refreshing;
      await expectLater(
        plugin.sendPrompt(
          sessionId: "session",
          promptId: "stale-selection",
          parts: const [PluginPromptPart.text(text: "hello")],
          variant: null,
          agent: "Removed mode",
          model: null,
        ),
        throwsA(isA<PluginStaleOptionsException>()),
      );
    });

    test("serializes reasoning refreshes for different selected models", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake);
      await connecting;
      final claude = plugin.validateTurnSelection(
        operation: "sendPrompt",
        model: (providerID: "copilot", modelID: "claude-sonnet-4.5"),
        variant: const PluginSessionVariant(id: "high"),
        agent: null,
      );
      final gemini = plugin.validateTurnSelection(
        operation: "sendPrompt",
        model: (providerID: "copilot", modelID: "gemini-3-pro"),
        variant: const PluginSessionVariant(id: "high"),
        agent: null,
      );
      await completeReasoningDiscovery(
        process: catalogFakes.first,
        selectedModel: "claude-sonnet-4.5",
        reasoningLevels: const ["low", "high"],
      );
      await claude;
      await completeReasoningDiscovery(
        process: catalogFakes.last,
        selectedModel: "gemini-3-pro",
        reasoningLevels: const ["low"],
      );
      await expectLater(gemini, throwsA(isA<PluginStaleOptionsException>()));
    });

    test("retains local Copilot login guidance after authentication failure", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake, rejectAuthentication: true);

      expect(await connecting, isFalse);
      expect(plugin.authenticationFailureActionHint, contains("copilot login"));
    });

    test("catalog authentication failures remain typed", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake);
      await connecting;
      final agents = plugin.getAgents(projectId: "/repo");
      await completeHandshake(process: catalogFakes.first, rejectAuthentication: true);
      await expectLater(
        agents,
        throwsA(
          isA<PluginAuthenticationRequiredException>().having(
            (error) => error.actionHint,
            "action hint",
            contains("copilot login"),
          ),
        ),
      );
    });

    test("a busy follow-up cancels before replacement prompt dispatch", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake);
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final sessionNew = await waitForFrame(process: fake, method: "session/new");
      fake.emit({
        "jsonrpc": "2.0",
        "id": sessionNew["id"],
        "result": {"sessionId": "session-1"},
      });
      await creating;

      await plugin.sendPrompt(
        sessionId: "session-1",
        promptId: "prompt-1",
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final first = await waitForFrame(process: fake, method: "session/prompt");
      await plugin.sendPrompt(
        sessionId: "session-1",
        promptId: "prompt-2",
        parts: const [PluginPromptPart.text(text: "replacement")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame(process: fake, method: "session/cancel");
      expect(cancel["params"], {"sessionId": "session-1"});
      expect(fake.written.where((frame) => frame["method"] == "session/prompt"), hasLength(1));

      fake.emit({
        "jsonrpc": "2.0",
        "id": first["id"],
        "result": {"stopReason": "cancelled"},
      });
      final replacement = await waitForFrame(process: fake, method: "session/prompt");
      expect(((replacement["params"] as Map)["prompt"] as List).single, {
        "type": "text",
        "text": "replacement",
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": replacement["id"],
        "result": {"stopReason": "end_turn"},
      });
    });
  });
}
