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
    late FakeAcpProcess catalogFake;
    late CopilotPlugin plugin;
    late List<Map<String, String>> launchEnvironments;
    late Set<Map<String, dynamic>> handledFrames;

    setUp(() {
      fake = FakeAcpProcess();
      catalogFake = FakeAcpProcess();
      handledFrames = {};
      launchEnvironments = [];
      var spawnCount = 0;
      plugin = CopilotPlugin(
        binaryPath: "/opt/copilot",
        launchDirectory: "/repo",
        catalogConfigDirectory: "/state/catalog",
        environment: const {"COPILOT_HOME": "/state/copilot"},
        processFactory: (spec) async {
          launchEnvironments.add(spec.environment);
          return spawnCount++ == 0 ? fake : catalogFake;
        },
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
      await catalogFake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

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
      expect(plugin.launchSpec.command, "/opt/copilot");
      expect(plugin.launchSpec.args, ["--no-auto-update", "--acp"]);
      expect(plugin.launchSpec.cwd, "/repo");
      expect(plugin.launchSpec.environment, const {"COPILOT_HOME": "/state/copilot"});
    });

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
      await completeHandshake(process: catalogFake);
      final newSession = await waitForFrame(process: catalogFake, method: "session/new");
      catalogFake.emit({
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
      catalogFake.emit({
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
      final closeSession = await waitForFrame(process: catalogFake, method: "session/close");
      catalogFake.emit({"jsonrpc": "2.0", "id": closeSession["id"], "result": <String, dynamic>{}});

      expect((await discovering).map((agent) => agent.name), ["Agent", "Plan"]);
      expect(launchEnvironments.last["COPILOT_HOME"], "/state/catalog");
      expect(fake.written.where((frame) => frame["method"] == "session/new"), isEmpty);
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
      expect(await plugin.getQueuedPrompts(sessionId: "session"), isEmpty);
    });

    test("retains local Copilot login guidance after authentication failure", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake, rejectAuthentication: true);

      expect(await connecting, isFalse);
      expect(plugin.authenticationFailureActionHint, contains("copilot login"));
    });

    test("legacy option getters surface isolated discovery failures", () async {
      final connecting = plugin.ensureConnected();
      await completeHandshake(process: fake);
      expect(await connecting, isTrue);

      final agents = plugin.getAgents(projectId: "/repo");
      await completeHandshake(process: catalogFake, rejectAuthentication: true);
      await expectLater(
        agents,
        throwsA(
          isA<PluginOperationException>().having(
            (error) => error.cause,
            "cause",
            isA<PluginAuthenticationRequiredException>(),
          ),
        ),
      );
    });
  });
}
