import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:hermes_plugin/src/api/hermes_acp_api.dart";
import "package:hermes_plugin/src/repositories/hermes_catalog_repository.dart";
import "package:hermes_plugin/src/services/hermes_session_options_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// The `initialize` result Hermes actually advertises (verified 2026-08-20
/// against Hermes Agent 0.20.4): load/list/resume/fork session capabilities,
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
      plugin = _plugin(fake: fake);
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
      // terminal-setup method; with authMethodId null the handshake picks the
      // first non-terminal method.
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

    test("uses the stock ACP policies plus stop-and-send follow-ups", () {
      expect(plugin.authMethodId, isNull, reason: "Hermes provider ids are dynamic");
      expect(plugin.initializeCapabilityMeta, isNull);
      expect(plugin.supportsFormElicitation, isFalse, reason: "no elicitation/create on Hermes");
      expect(plugin.serializesPromptsProcessWide, isFalse);
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      expect(plugin.failsTurnOnSelectionError, isTrue);
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

    test("a busy follow-up cancels the active turn before replacement dispatch", () async {
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
      await respond(method: "session/new", result: const {"sessionId": "s-follow-up"});
      final session = await creating;

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final firstPrompt = await waitForFrame(method: "session/prompt");

      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "replace it")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame(method: "session/cancel");
      expect(cancel["params"], {"sessionId": session.id});
      expect(fake.written.where((frame) => frame["method"] == "session/prompt"), hasLength(1));
      expect((await plugin.getQueuedPrompts(sessionId: session.id)).single.id, "prompt-2");

      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "result": {"stopReason": "cancelled"},
      });
      final replacement = await waitForFrame(method: "session/prompt");
      final replacementParams = (replacement["params"] as Map).cast<String, dynamic>();
      expect(replacementParams["sessionId"], session.id);
      expect(((replacementParams["prompt"] as List).single as Map)["text"], "replace it");
      expect(await plugin.getQueuedPrompts(sessionId: session.id), isEmpty);
      expect(events.whereType<BridgeSseSessionIdle>(), isEmpty);

      fake.emit({
        "jsonrpc": "2.0",
        "id": replacement["id"],
        "result": {"stopReason": "end_turn"},
      });
      for (var i = 0; i < 10 && events.whereType<BridgeSseSessionIdle>().isEmpty; i++) {
        await pump();
      }
      expect(events.whereType<BridgeSseSessionIdle>(), hasLength(1));
      expect(events.whereType<BridgeSseSessionError>(), isEmpty);
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

    test("a selected catalog model is applied before session creation completes", () async {
      await connect();

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: const (
          providerID: "opencode-go",
          modelID: "opencode-go:gpt-5",
        ),
      );
      await respond(
        method: "session/new",
        result: const {
          "sessionId": "s1",
          "models": {
            "currentModelId": "opencode-go:deepseek-v4-flash",
            "availableModels": [
              {
                "modelId": "opencode-go:deepseek-v4-flash",
                "name": "OpenCode Go · deepseek-v4-flash",
                "description": "Provider: OpenCode Go • current",
              },
              {
                "modelId": "opencode-go:gpt-5",
                "name": "OpenCode Go · GPT-5",
                "description": "Provider: OpenCode Go",
              },
            ],
          },
        },
      );

      final setModelFrame = await waitForFrame(method: "session/set_model");
      expect(
        (setModelFrame["params"] as Map).cast<String, dynamic>(),
        {"sessionId": "s1", "modelId": "opencode-go:gpt-5"},
      );
      fake.emit({
        "jsonrpc": "2.0",
        "id": setModelFrame["id"],
        "result": <String, dynamic>{},
      });

      expect((await creating).id, "s1");
    });

    test("a rejected model switch fails the turn before session/prompt", () async {
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
      await respond(
        method: "session/new",
        result: const {
          "sessionId": "s1",
          "models": {
            "currentModelId": "opencode-go:deepseek-v4-flash",
            "availableModels": [
              {
                "modelId": "opencode-go:deepseek-v4-flash",
                "name": "OpenCode Go · deepseek-v4-flash",
                "description": "Provider: OpenCode Go • current",
              },
              {
                "modelId": "opencode-go:gpt-5",
                "name": "OpenCode Go · GPT-5",
                "description": "Provider: OpenCode Go",
              },
            ],
          },
        },
      );
      await creating;
      final failedTurn = plugin.events.where((event) => event is BridgeSseSessionError).first;

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: const (
          providerID: "opencode-go",
          modelID: "opencode-go:gpt-5",
        ),
      );
      final setModelFrame = await waitForFrame(method: "session/set_model");
      fake.emit({
        "jsonrpc": "2.0",
        "id": setModelFrame["id"],
        "error": {
          "code": -32603,
          "message": "Internal error",
        },
      });

      await failedTurn.timeout(const Duration(seconds: 1));
      expect(
        fake.written.where((frame) => frame["method"] == "session/prompt"),
        isEmpty,
      );
    });
  });
}

HermesPlugin _plugin({
  required FakeAcpProcess fake,
  String? configuredModelId,
  String? configuredProviderId,
}) {
  final configurationTracker = AcpSessionConfigurationTracker()
    ..setProcessDefaults(
      modelId: configuredModelId,
      providerId: configuredProviderId,
    );
  final commandTracker = AcpCommandTracker();
  final childSessionTracker = AcpChildSessionTracker();
  final repository = HermesCatalogRepository(
    api: HermesAcpApi(
      binaryPath: HermesBinary.defaultBinary,
      processFactory: (_) async => throw StateError("scratch discovery not expected"),
      commandExecutor: const _UnusedCommandExecutor(),
      environment: const {},
    ),
  );
  final optionsService = HermesSessionOptionsService(
    repository: repository,
    configurationTracker: configurationTracker,
    commandTracker: commandTracker,
    launchDirectory: "/repo",
    pluginId: "hermes",
    agentDisplayName: "Hermes Agent",
    discoveryTimeout: const Duration(seconds: 2),
  );
  return HermesPlugin(
    launchSpec: HermesBinary.launchSpec(
      binary: HermesBinary.defaultBinary,
      cwd: "/repo",
      environment: const {},
    ),
    launchDirectory: "/repo",
    childSessionTracker: childSessionTracker,
    eventMapper: AcpEventMapper(
      launchDirectory: "/repo",
      pluginId: "hermes",
      configurationTracker: configurationTracker,
      childSessions: childSessionTracker,
    ),
    commandTracker: commandTracker,
    sessionOptionsService: AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: "hermes",
      agentDisplayName: "Hermes Agent",
    ),
    processFactory: (_) async => fake,
    hermesSessionOptionsService: optionsService,
  );
}

class const _UnusedCommandExecutor() implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) => throw StateError("command execution not expected");
}
