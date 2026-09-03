import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:grok_plugin/grok_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const List<Map<String, dynamic>> _availableModels = [
  {
    "modelId": "synthetic:model-alpha",
    "name": "Model Alpha",
    "description": null,
    "_meta": {
      "supportsReasoningEffort": true,
      "reasoningEffort": "high",
      "reasoningEfforts": [
        {"value": "low", "default": false},
        {"value": "high", "default": true},
      ],
    },
  },
  {
    "modelId": "opaque/provider:model-beta",
    "name": "Model Beta",
    "description": null,
    "_meta": {
      "supportsReasoningEffort": true,
      "reasoningEffort": "max",
      "reasoningEfforts": [
        {"value": "max", "default": true},
      ],
    },
  },
];

const Map<String, dynamic> _modelState = {
  "currentModelId": "synthetic:model-alpha",
  "availableModels": _availableModels,
};

const Map<String, dynamic> _betaModelState = {
  "currentModelId": "opaque/provider:model-beta",
  "availableModels": _availableModels,
};

const Map<String, dynamic> _initializeResult = {
  "protocolVersion": 1,
  "agentCapabilities": {
    "loadSession": true,
    "sessionCapabilities": {
      "list": <String, dynamic>{},
      "resume": <String, dynamic>{},
      "close": <String, dynamic>{},
    },
  },
  "authMethods": [
    {"id": "grok.com", "name": "Interactive login"},
    {"id": "cached_token", "name": "Cached token"},
  ],
  "_meta": {
    "grokShell": true,
    "agentVersion": "1.0.5",
    "modelState": _modelState,
  },
};

void main() {
  group("GrokPlugin", () {
    late FakeAcpProcess fake;
    late GrokPlugin plugin;
    late Set<Object?> handledFrameIds;

    setUp(() {
      fake = FakeAcpProcess();
      handledFrameIds = {};
      plugin = GrokPlugin(
        binaryPath: "grok",
        launchDirectory: "/repo",
        environment: const {},
        processFactory: (_) async => fake,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<Map<String, dynamic>> waitForFrame({required String method}) async {
      for (var attempt = 0; attempt < 400; attempt++) {
        final matches = fake.written.where(
          (frame) => frame["method"] == method && !handledFrameIds.contains(frame["id"]),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrameIds.add(frame["id"]);
          return frame;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never received '$method'");
    }

    Future<void> respond({required String method, required Map<String, dynamic> result}) async {
      final frame = await waitForFrame(method: method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      await respond(method: AcpMethods.initialize, result: _initializeResult);
      final authenticate = await waitForFrame(method: AcpMethods.authenticate);
      expect(authenticate["params"], {"methodId": "cached_token"});
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      expect(await connecting, isTrue);
    }

    test("child sessions and parentage come from the live sub-agent tracker", () async {
      plugin.childSessionTracker.spawn(
        sessionId: "root",
        spawn: const AcpChildSpawn(
          childSessionId: "child",
          description: "Synthetic child",
          agent: "general-purpose",
          prompt: null,
          isBackground: false,
        ),
        directory: "/repo",
      );

      final children = await plugin.getChildSessions("root");
      expect(children.single.id, "child");
      expect(children.single.parentID, "root");
      expect(children.single.directory, "/repo");
      expect(children.single.title, "Synthetic child");
      expect(await plugin.getChildSessions("child"), isEmpty);

      const child = AcpSessionInfo(sessionId: "child", cwd: "/repo", title: null, updatedAtMs: null);
      const root = AcpSessionInfo(sessionId: "root", cwd: "/repo", title: null, updatedAtMs: null);
      expect(plugin.sessionParentId(child), "root");
      expect(plugin.sessionParentId(root), isNull);
    });

    test("uses Grok identity, headless auth policy, and stop-and-send", () {
      expect(plugin.id, "grok");
      expect(plugin.authMethodId, isNull);
      expect(plugin.authMethodAllowlist, {"xai.api_key", "cached_token"});
      expect(plugin.supportsFormElicitation, isFalse);
      expect(plugin.cancelsActiveTurnForQueuedInput, isTrue);
      expect(plugin.failsTurnOnSelectionError, isTrue);
    });

    test("initialize captures one Grok provider without a scratch process", () async {
      await connect();

      final providers = await plugin.getProviders(projectId: "/repo");
      expect(providers.providers.single.id, "grok");
      expect(providers.providers.single.defaultModelID, "synthetic:model-alpha");
      expect(providers.providers.single.models.first.variants, ["high", "low"]);
    });

    test("a process exit resets and reconnects Grok without losing the plugin", () async {
      await connect();
      final exited = fake;
      exited.exit(1);
      await plugin.resetConnectionAfterExit();
      fake = FakeAcpProcess();
      handledFrameIds.clear();
      addTearDown(exited.close);

      await connect();
      expect((await plugin.getProviders(projectId: "/repo")).providers.single.id, "grok");
    });

    test("disposal is idempotent and reaps the owned Grok process", () async {
      await connect();
      final exitCode = fake.exitCode;

      await plugin.dispose();
      await plugin.dispose();

      expect(await exitCode, -15);
    });

    test("a non-Grok ACP peer is rejected during initialize validation", () async {
      final connecting = plugin.ensureConnected();
      await respond(
        method: AcpMethods.initialize,
        result: {
          ..._initializeResult,
          "authMethods": const <Object?>[],
          "_meta": const {"grokShell": false, "modelState": _modelState},
        },
      );

      expect(await connecting, isFalse);
    });

    test("interactive-only authentication is rejected before authenticate", () async {
      final connecting = plugin.ensureConnected();
      await respond(
        method: AcpMethods.initialize,
        result: {
          ..._initializeResult,
          "authMethods": const [
            {"id": "grok.com", "name": "Interactive login"},
          ],
        },
      );

      expect(await connecting, isFalse);
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.authenticate), isEmpty);
    });

    test("selected model and reasoning effort are applied before create completes", () async {
      await connect();
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: const PluginSessionVariant(id: "low"),
        agent: "grok",
        model: const (providerID: "grok", modelID: "synthetic:model-alpha"),
      );
      await respond(
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      final selection = await waitForFrame(method: GrokAcpApi.sessionSetModelMethod);
      expect(selection["params"], {
        "sessionId": "s1",
        "modelId": "synthetic:model-alpha",
        "_meta": {"reasoningEffort": "low"},
      });
      fake.emit({"jsonrpc": "2.0", "id": selection["id"], "result": <String, dynamic>{}});

      expect((await creating).id, "s1");
    });

    test("effort-only selection waits for the loaded session model before tuple validation", () async {
      await connect();
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");

      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "stored",
        parts: const [PluginPromptPart.text(text: "Continue")],
        variant: const PluginSessionVariant(id: "max"),
        agent: null,
        model: null,
      );
      await respond(
        method: AcpMethods.sessionLoad,
        result: const {"sessionId": "stored", "models": _betaModelState},
      );
      final selection = await waitForFrame(method: GrokAcpApi.sessionSetModelMethod);
      expect(selection["params"], {
        "sessionId": "stored",
        "modelId": "opaque/provider:model-beta",
        "_meta": {"reasoningEffort": "max"},
      });
      fake.emit({"jsonrpc": "2.0", "id": selection["id"], "result": <String, dynamic>{}});
      final prompt = await waitForFrame(method: AcpMethods.sessionPrompt);
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("two sessions dispatch independently through the shared ACP lanes", () async {
      await connect();
      final creatingFirst = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond(
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creatingFirst;
      final creatingSecond = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond(
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s2", "models": _modelState},
      );
      await creatingSecond;

      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        promptId: "p2",
        sessionId: "s2",
        parts: const [PluginPromptPart.text(text: "second")],
        variant: null,
        agent: null,
        model: null,
      );
      final first = await waitForFrame(method: AcpMethods.sessionPrompt);
      final second = await waitForFrame(method: AcpMethods.sessionPrompt);
      expect({(first["params"] as Map)["sessionId"], (second["params"] as Map)["sessionId"]}, {"s1", "s2"});
      fake.emit({
        "jsonrpc": "2.0",
        "id": first["id"],
        "result": {"stopReason": "end_turn"},
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": second["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("a busy follow-up cancels before replacement prompt dispatch", () async {
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
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creating;

      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final first = await waitForFrame(method: AcpMethods.sessionPrompt);
      await plugin.sendPrompt(
        promptId: "p2",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "replacement")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame(method: AcpMethods.sessionCancel);
      expect(cancel["params"], {"sessionId": "s1"});
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt), hasLength(1));

      fake.emit({
        "jsonrpc": "2.0",
        "id": first["id"],
        "result": {"stopReason": "cancelled"},
      });
      final replacement = await waitForFrame(method: AcpMethods.sessionPrompt);
      expect(((replacement["params"] as Map)["prompt"] as List).single, {"type": "text", "text": "replacement"});
      fake.emit({
        "jsonrpc": "2.0",
        "id": replacement["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("standard reasoning, tools, and permissions stay phone-mediated", () async {
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
      await respond(
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creating;
      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "Inspect")],
        variant: null,
        agent: null,
        model: null,
      );
      final prompt = await waitForFrame(method: AcpMethods.sessionPrompt);
      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "agent_thought_chunk",
            "content": {"type": "text", "text": "Thinking"},
          },
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": "s1",
          "update": {"sessionUpdate": "tool_call", "toolCallId": "t1", "kind": "execute", "status": "pending"},
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": 90,
        "method": AcpMethods.sessionRequestPermission,
        "params": {
          "sessionId": "s1",
          "toolCall": {"toolCallId": "t1", "title": "Run tests", "kind": "execute"},
          "options": [
            {"optionId": "allow", "name": "Allow", "kind": "allow_once"},
            {"optionId": "reject", "name": "Reject", "kind": "reject_once"},
          ],
        },
      });
      await Future<void>.delayed(Duration.zero);

      final partTypes = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part.type);
      expect(partTypes, containsAll([PluginMessagePartType.reasoning, PluginMessagePartType.tool]));
      final pending = (await plugin.getPendingPermissions(sessionId: "s1")).single;
      expect(pending.tool, "execute");
      await plugin.replyToPermission(requestId: pending.id, sessionId: "s1", reply: PluginPermissionReply.once);
      expect(((fake.written.last["result"] as Map)["outcome"] as Map)["optionId"], "allow");
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("deletion closes only the resident process session", () async {
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
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creating;

      final deleting = plugin.deleteSession("s1");
      final close = await waitForFrame(method: AcpMethods.sessionClose);
      expect(close["params"], {"sessionId": "s1"});
      fake.emit({"jsonrpc": "2.0", "id": close["id"], "result": <String, dynamic>{}});
      await deleting;
    });

    test("stale agent, provider, model, and effort fail before turn acceptance", () async {
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
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creating;
      final staleSelections =
          <({String? agent, ({String providerID, String modelID})? model, PluginSessionVariant? variant})>[
            (agent: "removed-agent", model: null, variant: null),
            (
              agent: null,
              model: const (providerID: "removed-provider", modelID: "synthetic:model-alpha"),
              variant: null,
            ),
            (agent: null, model: const (providerID: "grok", modelID: "removed-model"), variant: null),
            (agent: null, model: null, variant: const PluginSessionVariant(id: "removed-effort")),
          ];

      for (final selection in staleSelections) {
        await expectLater(
          plugin.sendPrompt(
            promptId: "stale-${staleSelections.indexOf(selection)}",
            sessionId: "s1",
            parts: const [PluginPromptPart.text(text: "Hello")],
            variant: selection.variant,
            agent: selection.agent,
            model: selection.model,
          ),
          throwsA(
            isA<PluginStaleOptionsException>().having(
              (error) => error.operation,
              "operation",
              "sendPrompt",
            ),
          ),
        );
      }
      expect(fake.written.where((frame) => frame["method"] == GrokAcpApi.sessionSetModelMethod), isEmpty);
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt), isEmpty);
    });

    test("history replay stamps the loaded selection without replacing live defaults", () async {
      await connect();
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      expect((await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID, "synthetic:model-alpha");

      fake = FakeAcpProcess();
      handledFrameIds.clear();
      final replaying = plugin.getSessionMessages("stored");
      await respond(
        method: AcpMethods.initialize,
        result: {
          ..._initializeResult,
          "_meta": const {
            "grokShell": true,
            "agentVersion": "1.0.5",
            "modelState": _betaModelState,
          },
        },
      );
      final authenticate = await waitForFrame(method: AcpMethods.authenticate);
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      final load = await waitForFrame(method: AcpMethods.sessionLoad);
      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": "stored",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "replayed",
            "content": {"type": "text", "text": "Replayed response"},
          },
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": load["id"],
        "result": const {"sessionId": "stored", "models": _betaModelState},
      });

      final assistant = (await replaying).single.info as PluginMessageAssistant;
      expect(assistant.agent, "grok");
      expect(assistant.modelID, "opaque/provider:model-beta");
      expect(assistant.providerID, "grok");
      expect(assistant.variant, "max");
      expect((await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID, "synthetic:model-alpha");
    });

    test("a rejected selection fails the accepted turn before prompt dispatch", () async {
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
        method: AcpMethods.sessionNew,
        result: const {"sessionId": "s1", "models": _modelState},
      );
      await creating;
      final failed = plugin.events.where((event) => event is BridgeSseSessionError).first;

      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "Hello")],
        variant: null,
        agent: null,
        model: const (providerID: "grok", modelID: "opaque/provider:model-beta"),
      );
      final selection = await waitForFrame(method: GrokAcpApi.sessionSetModelMethod);
      fake.emit({
        "jsonrpc": "2.0",
        "id": selection["id"],
        "error": {"code": -32603, "message": "Rejected"},
      });

      await failed.timeout(const Duration(seconds: 1));
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionPrompt), isEmpty);
    });
  });
}
