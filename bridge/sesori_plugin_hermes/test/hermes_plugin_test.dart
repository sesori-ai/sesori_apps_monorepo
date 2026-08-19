import "dart:async";

import "package:acp_plugin/acp_plugin.dart"
    show AcpModelInfo, AcpNewSessionResult, AcpSessionModelState;
import "package:acp_plugin/acp_testing.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// The `initialize` result Hermes actually advertises (verified 2026-08-15
/// against Hermes Agent 0.20.1): load/list/resume/fork session capabilities,
/// image prompt support, and no `closeSession`. The base must therefore
/// never call `session/close`. Auth mirrors `build_auth_methods()`: the
/// configured provider as an agent method first, then a terminal-setup
/// method.
const Map<String, dynamic> hermesInitializeResult = {
  "protocolVersion": 1,
  "agentCapabilities": {
    "loadSession": true,
    "promptCapabilities": {"image": true},
    "sessionCapabilities": {
      "fork": <String, dynamic>{},
      "list": <String, dynamic>{},
      "resume": <String, dynamic>{},
    },
  },
  "authMethods": [
    {
      "id": "opencode-go",
      "name": "opencode-go runtime credentials",
      "description": "Authenticate Hermes using the currently configured opencode-go runtime credentials.",
    },
    {
      "type": "terminal",
      "id": "hermes-setup",
      "name": "Configure Hermes provider",
      "description": "Open Hermes' interactive model/provider setup in a terminal.",
    },
  ],
};

void main() {
  group("HermesPlugin", () {
    late FakeAcpProcess fake;
    late HermesPlugin plugin;
    late Set<Object?> handledFrameIds;

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = HermesPlugin(
        binaryPath: HermesBinary.defaultBinary,
        launchDirectory: "/repo",
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

    Future<void> respond({
      required String method,
      required Map<String, dynamic> result,
    }) async {
      final frame = await waitForFrame(method: method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      await respond(method: "initialize", result: hermesInitializeResult);
      // Hermes advertises the configured provider method first, then a
      // terminal-setup method; the handshake authenticates against the first
      // advertised method because authMethodId is null.
      final authFrame = await waitForFrame(method: "authenticate");
      expect(
        (authFrame["params"] as Map).cast<String, dynamic>()["methodId"],
        "opencode-go",
        reason: "the plugin must authenticate against the configured provider, not the setup method",
      );
      fake.emit({"jsonrpc": "2.0", "id": authFrame["id"], "result": <String, dynamic>{}});
      expect(await connecting, isTrue);
    }

    test("id is hermes", () {
      expect(plugin.id, "hermes");
    });

    test("the default binary is the Hermes CLI and the launch spec drives `hermes acp`", () {
      expect(HermesBinary.defaultBinary, "hermes");
      final spec = HermesBinary.launchSpec(
        binary: HermesBinary.defaultBinary,
        cwd: "/repo",
        environment: const {},
      );
      expect(spec.command, "hermes");
      expect(spec.args, ["acp"]);
    });

    test("declares the neutral ACP policies for a stock v1 server", () {
      expect(plugin.clientName, "sesori-bridge");
      expect(plugin.clientVersion, "0.0.0");
      expect(plugin.authMethodId, isNull, reason: "Hermes provider ids are dynamic");
      expect(plugin.initializeCapabilityMeta, isNull);
      expect(plugin.supportsFormElicitation, isFalse, reason: "no elicitation/create on Hermes");
      expect(plugin.serializesPromptsProcessWide, isFalse);
      expect(plugin.failsTurnOnSelectionError, isFalse);
      expect(plugin.sessionCloseSettlementTimeout, const Duration(seconds: 5));
    });

    test("handshake succeeds against Hermes's advertised capabilities", () async {
      await connect();
    });

    test("terminal-only setup authentication keeps the plugin blocked", () async {
      final connecting = plugin.ensureConnected();
      await respond(
        method: "initialize",
        result: {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": [
            {
              "type": "terminal",
              "id": "hermes-setup",
              "name": "Configure Hermes provider",
            },
          ],
        },
      );

      expect(fake.written.where((frame) => frame["method"] == "authenticate"), isEmpty);
      expect(await connecting, isFalse);
    });

    test("a prompt turn streams text chunks into part delta events", () async {
      await connect();
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond(method: "session/new", result: const {"sessionId": "s1"});
      final session = await creating;
      expect(session.id, "s1");

      final prompting = plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: null,
      );
      final promptFrame = await waitForFrame(method: "session/prompt");
      final params = (promptFrame["params"] as Map).cast<String, dynamic>();
      expect(params["sessionId"], "s1");
      final prompt = params["prompt"] as List;
      expect(
        (prompt.single as Map)["text"],
        "Hello",
        reason: "the prompt part must reach the agent verbatim",
      );
      fake.emit({"jsonrpc": "2.0", "id": promptFrame["id"], "result": <String, dynamic>{}});
      await prompting;

      // Hermes streams assistant output as session/update agent_message_chunk
      // notifications (same shape the base mapper expects).
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "Hello"},
          },
        },
      });
      await pump();

      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "Hello");
    });

    test("deleteSession never calls session/close when closeSession is not advertised", () async {
      await connect();

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond(method: "session/new", result: const {"sessionId": "s1"});
      await creating;

      await plugin.deleteSession("s1");
      await pump();

      expect(
        fake.written.where((frame) => frame["method"] == "session/close"),
        isEmpty,
        reason: "Hermes does not advertise closeSession, so deletion must be local-only",
      );
    });
  });

  group("HermesPlugin model surface", () {
    late FakeAcpProcess fake;
    late HermesPlugin plugin;
    late Set<Object?> handledFrameIds;

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = HermesPlugin(
        binaryPath: HermesBinary.defaultBinary,
        launchDirectory: "/repo",
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

    Future<void> respond({
      required String method,
      required Map<String, dynamic> result,
    }) async {
      final frame = await waitForFrame(method: method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      await respond(method: "initialize", result: hermesInitializeResult);
      final authFrame = await waitForFrame(method: "authenticate");
      fake.emit({"jsonrpc": "2.0", "id": authFrame["id"], "result": <String, dynamic>{}});
      expect(await connecting, isTrue);
    }

    const availableModels = [
      AcpModelInfo(
        modelId: "opencode-go:deepseek-v4-flash",
        name: "opencode-go · deepseek-v4-flash",
      ),
      AcpModelInfo(
        modelId: "opencode-go:gpt-5",
        name: "opencode-go · GPT-5",
      ),
    ];

    AcpNewSessionResult modelsResult({required String currentModelId}) {
      return AcpNewSessionResult(
        sessionId: "s1",
        modes: const [],
        configOptions: const [],
        models: AcpSessionModelState(
          availableModels: availableModels,
          currentModelId: currentModelId,
        ),
        raw: const {},
      );
    }

    test("captureSessionConfig surfaces the active model in the picker", () async {
      await connect();

      plugin.captureSessionConfig(
        modelsResult(currentModelId: "opencode-go:deepseek-v4-flash"),
        sessionId: "s1",
        fromNewSession: true,
      );

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, hasLength(1));
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), contains("opencode-go:deepseek-v4-flash"));
      expect(provider.defaultModelID, "opencode-go:deepseek-v4-flash");
    });

    test("captureSessionConfig with no models field leaves the picker empty", () async {
      await connect();

      plugin.captureSessionConfig(
        const AcpNewSessionResult(
          sessionId: "s1",
          modes: [],
          configOptions: [],
          models: null,
          raw: {},
        ),
        sessionId: "s1",
        fromNewSession: true,
      );

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers, isEmpty);
    });

    test("applyTurnSelection issues session/set_model for a user-selected model", () async {
      await connect();

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: const (providerID: "opencode-go", modelID: "opencode-go:gpt-5"),
      );
      await respond(method: "session/new", result: const {"sessionId": "s1"});

      final setModelFrame = await waitForFrame(method: "session/set_model");
      final params = (setModelFrame["params"] as Map).cast<String, dynamic>();
      expect(params["sessionId"], "s1");
      expect(params["modelId"], "opencode-go:gpt-5");
      fake.emit({
        "jsonrpc": "2.0",
        "id": setModelFrame["id"],
        "result": <String, dynamic>{},
      });
      await creating;
    });
  });
}
