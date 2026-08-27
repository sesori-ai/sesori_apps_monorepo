import "dart:async";

import "package:acp_plugin/acp_testing.dart";
import "package:copilot_plugin/copilot_plugin.dart";
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
    late CopilotPlugin plugin;
    late Set<Object?> handledFrameIds;

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = CopilotPlugin(
        binaryPath: "/opt/copilot",
        launchDirectory: "/repo",
        environment: const {"COPILOT_HOME": "/state/copilot"},
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Future<Map<String, dynamic>> waitForFrame({required String method}) async {
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

    test("owns the stable Copilot identity and launch arguments", () {
      expect(CopilotPluginIdentity.id, "copilot");
      expect(CopilotPluginIdentity.displayName, "GitHub Copilot");
      expect(plugin.id, CopilotPluginIdentity.id);
      expect(plugin.launchSpec.command, "/opt/copilot");
      expect(plugin.launchSpec.args, ["--no-auto-update", "--acp"]);
      expect(plugin.launchSpec.cwd, "/repo");
      expect(plugin.launchSpec.environment, const {"COPILOT_HOME": "/state/copilot"});
    });

    test("keeps stock ACP policies except Copilot auth and stop-and-send", () {
      expect(plugin.authMethodId, CopilotBinary.acpAuthMethodId);
      expect(plugin.initializeCapabilityMeta, isNull);
      expect(plugin.supportsFormElicitation, isFalse);
      expect(plugin.serializesPromptsProcessWide, isFalse);
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      expect(plugin.failsTurnOnSelectionError, isTrue);
    });

    test("completes Copilot's standard ACP handshake", () async {
      final connecting = plugin.ensureConnected();
      final initialize = await waitForFrame(method: "initialize");
      final initializeParams = (initialize["params"] as Map).cast<String, dynamic>();
      final clientCapabilities = (initializeParams["clientCapabilities"] as Map).cast<String, dynamic>();
      expect(clientCapabilities, isNot(contains("elicitation")));
      fake.emit({"jsonrpc": "2.0", "id": initialize["id"], "result": _copilotInitializeResult});

      final authenticate = await waitForFrame(method: "authenticate");
      expect(
        (authenticate["params"] as Map).cast<String, dynamic>()["methodId"],
        CopilotBinary.acpAuthMethodId,
      );
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});

      expect(await connecting, isTrue);
      expect(await plugin.getAgents(projectId: "/repo"), hasLength(1));
    });
  });
}
