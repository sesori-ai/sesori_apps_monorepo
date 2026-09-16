import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:grok_plugin/grok_plugin.dart";
import "package:grok_plugin/src/api/grok_acp_api.dart";
import "package:grok_plugin/src/api/models/grok_session_notification_dto.dart";
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

    Future<Map<String, dynamic>> startPrompt({required String sessionId}) async {
      plugin.primeSessionDirectory(sessionId: sessionId, directory: "/repo");
      await plugin.sendPrompt(
        promptId: "prompt-$sessionId",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "Work")],
        variant: null,
        agent: null,
        model: null,
      );
      await respond(method: AcpMethods.sessionLoad, result: {"sessionId": sessionId, "models": _modelState});
      return await waitForFrame(method: AcpMethods.sessionPrompt);
    }

    Future<void> spawnChild({required String parentSessionId, required String childSessionId}) async {
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": parentSessionId,
          "update": {
            "sessionUpdate": "subagent_spawned",
            "subagent_id": childSessionId,
            "child_session_id": childSessionId,
            "description": "Child $childSessionId",
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> finishChild({required String parentSessionId, required String childSessionId}) async {
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": parentSessionId,
          "update": {
            "sessionUpdate": "subagent_finished",
            "subagent_id": childSessionId,
            "child_session_id": childSessionId,
            "status": "cancelled",
            "will_wake": false,
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
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
    });

    test("deleting running child work fails without forgetting its live state", () async {
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

      for (final sessionId in ["child", "root"]) {
        await expectLater(
          plugin.deleteSession(sessionId),
          throwsA(
            isA<PluginOperationException>().having(
              (error) => error.message,
              "message",
              contains("must finish or be stopped"),
            ),
          ),
        );
      }

      expect(plugin.childSessionTracker.isChild(sessionId: "child"), isTrue);
      expect((await plugin.getSessionStatuses())["child"], const PluginSessionStatus.busy());

      plugin.childSessionTracker.finishAndHoldRoot(
        childSessionId: "child",
        holdId: "wake-child",
        status: PluginToolStatus.completed,
        output: null,
        error: null,
      );
      await expectLater(plugin.deleteSession("child"), throwsA(isA<PluginOperationException>()));
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "root"), isTrue);

      plugin.childSessionTracker
        ..releaseRootHold(rootSessionId: "root", holdId: "wake-child")
        ..spawn(
          sessionId: "root",
          spawn: const AcpChildSpawn(
            childSessionId: "sibling",
            description: "Still running",
            agent: "general-purpose",
            prompt: null,
            isBackground: false,
          ),
          directory: "/repo",
        );
      await plugin.deleteSession("child");
      expect(plugin.childSessionTracker.isChild(sessionId: "child"), isFalse);
      expect(plugin.childSessionTracker.isChild(sessionId: "sibling"), isTrue);
    });

    test("persisted children survive a restart and merge with live ones", () async {
      final home = Directory.systemTemp.createTempSync("grok-home-");
      addTearDown(() => home.deleteSync(recursive: true));
      final rootDir = Directory("${home.path}/.grok/sessions/${Uri.encodeComponent("/repo")}/root")
        ..createSync(recursive: true);
      File("${rootDir.path}/updates.jsonl").writeAsStringSync(
        jsonEncode({
          "method": "_x.ai/session/update",
          "params": {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "subagent_spawned",
              "subagent_id": "persisted",
              "child_session_id": "persisted",
              "subagent_type": "general-purpose",
              "description": "Persisted child",
            },
          },
        }),
      );
      File("${home.path}/.grok/sessions/${Uri.encodeComponent("/repo")}/persisted/summary.json")
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            "info": {"id": "persisted", "cwd": "/repo"},
            "session_kind": "subagent",
          }),
        );
      final restarted = GrokPlugin(
        binaryPath: "grok",
        launchDirectory: "/repo",
        environment: {"HOME": home.path},
        processFactory: (_) async => fake,
      );
      addTearDown(restarted.dispose);
      restarted.childSessionTracker.spawn(
        sessionId: "root",
        spawn: const AcpChildSpawn(
          childSessionId: "live",
          description: "Live child",
          agent: "general-purpose",
          prompt: null,
          isBackground: false,
        ),
        directory: "/repo",
      );

      final children = await restarted.getChildSessions("root");
      expect(children.map((session) => session.id), ["persisted", "live"]);
      expect(
        children.map((session) => session.parentID),
        everyElement("root"),
        reason: "persisted parentage resolves without the live tracker",
      );
    });

    test("full ACP enumeration augments an outside-launch root with its persisted child", () async {
      final home = Directory.systemTemp.createTempSync("grok-enumeration-home-");
      addTearDown(() => home.deleteSync(recursive: true));
      await plugin.dispose();
      plugin = GrokPlugin(
        binaryPath: "grok",
        launchDirectory: "/repo",
        environment: {"HOME": home.path},
        processFactory: (_) async => fake,
      );
      const outside = "/outside-launch-directory";
      final rootDir = Directory("${home.path}/.grok/sessions/${Uri.encodeComponent(outside)}/root")
        ..createSync(recursive: true);
      File("${rootDir.path}/summary.json").writeAsStringSync(
        jsonEncode({
          "info": {"id": "root", "cwd": outside},
        }),
      );
      File("${rootDir.path}/updates.jsonl").writeAsStringSync(
        jsonEncode({
          "method": "_x.ai/session/update",
          "params": {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "subagent_spawned",
              "subagent_id": "child",
              "child_session_id": "child",
              "parent_session_id": "root",
              "description": "Persisted child",
            },
          },
        }),
      );
      File("${home.path}/.grok/sessions/${Uri.encodeComponent(outside)}/child/summary.json")
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            "info": {"id": "child", "cwd": outside},
            "session_kind": "subagent",
          }),
        );
      await connect();

      final listing = plugin.listAllSessions(knownDirectories: const {});
      final bare = await waitForFrame(method: AcpMethods.sessionList);
      expect((bare["params"] as Map<String, dynamic>)["cwd"], isNull);
      fake.emit({
        "jsonrpc": "2.0",
        "id": bare["id"],
        "result": {
          "sessions": [
            {"sessionId": "root", "title": "Root"},
          ],
        },
      });
      final launchScoped = await waitForFrame(method: AcpMethods.sessionList);
      expect((launchScoped["params"] as Map<String, dynamic>)["cwd"], "/repo");
      fake.emit({
        "jsonrpc": "2.0",
        "id": launchScoped["id"],
        "result": {"sessions": const <Object?>[]},
      });

      final sessions = await listing;
      expect(sessions.map((session) => session.id), ["root", "child"]);
      expect(sessions.first.directory, outside, reason: "the persisted tree repairs the bare-list fallback");
      expect(plugin.directoryForSession(sessionId: "root"), outside, reason: "resume routing uses the same repair");
      expect(plugin.directoryForSession(sessionId: "child"), outside, reason: "child events share root attribution");
      expect(sessions.last.parentID, "root");
      expect(sessions.last.directory, outside);
    });

    test("bare enumeration fallback preserves an existing session directory", () async {
      await connect();
      const storedDirectory = "/stored-project";
      plugin.primeSessionDirectory(sessionId: "root", directory: storedDirectory);

      final listing = plugin.listAllSessions(knownDirectories: const {});
      final bare = await waitForFrame(method: AcpMethods.sessionList);
      expect((bare["params"] as Map<String, dynamic>)["cwd"], isNull);
      fake.emit({
        "jsonrpc": "2.0",
        "id": bare["id"],
        "result": {
          "sessions": [
            {"sessionId": "root", "title": "Root"},
          ],
        },
      });
      final launchScoped = await waitForFrame(method: AcpMethods.sessionList);
      expect((launchScoped["params"] as Map<String, dynamic>)["cwd"], "/repo");
      fake.emit({
        "jsonrpc": "2.0",
        "id": launchScoped["id"],
        "result": {"sessions": const <Object?>[]},
      });
      final storedScoped = await waitForFrame(method: AcpMethods.sessionList);
      expect((storedScoped["params"] as Map<String, dynamic>)["cwd"], storedDirectory);
      fake.emit({
        "jsonrpc": "2.0",
        "id": storedScoped["id"],
        "result": {"sessions": const <Object?>[]},
      });

      final sessions = await listing;
      expect(sessions.single.directory, storedDirectory);
      expect(plugin.directoryForSession(sessionId: "root"), storedDirectory);
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

    test("resume load suppresses replayed Grok lifecycle while later extension updates remain live", () async {
      await connect();
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      await plugin.sendPrompt(
        promptId: "p1",
        sessionId: "stored",
        parts: const [PluginPromptPart.text(text: "Continue")],
        variant: null,
        agent: null,
        model: null,
      );
      final load = await waitForFrame(method: AcpMethods.sessionLoad);
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.updateMethod,
        "params": {
          "sessionId": "stored",
          "update": {
            "sessionUpdate": "subagent_spawned",
            "subagent_id": "historical-child",
            "child_session_id": "historical-child",
            "description": "Historical child",
          },
        },
      });
      fake.emit({"jsonrpc": "2.0", "id": load["id"], "result": const <String, dynamic>{}});
      final prompt = await waitForFrame(method: AcpMethods.sessionPrompt);
      expect(plugin.childSessionTracker.isChild(sessionId: "historical-child"), isFalse);

      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": "stored",
          "update": {
            "sessionUpdate": "subagent_spawned",
            "subagent_id": "live-child",
            "child_session_id": "live-child",
            "description": "Live child",
          },
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": "stored",
          "update": {
            "sessionUpdate": "subagent_finished",
            "subagent_id": "live-child",
            "child_session_id": "live-child",
            "status": "completed",
            "will_wake": true,
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "stored"), isTrue);
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.updateMethod,
        "params": {
          "sessionId": "stored",
          "update": {
            "sessionUpdate": "turn_completed",
            "prompt_id": "subagent-completed-live-child",
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "stored"), isFalse);
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

    test("scoped confirm and unsupported keep reject without side effects", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "child");

      for (final policy in [PluginAbortSubAgentPolicy.confirm, PluginAbortSubAgentPolicy.keep]) {
        final before = fake.written.length;
        final result = await plugin.abortSession(
          sessionId: "root",
          subAgents: policy,
          useAtomicStop: true,
          knownSubAgentSessionIds: const {"child"},
        );
        expect(
          result,
          isA<PluginAbortRejectedSubAgentsRunning>()
              .having((value) => value.runningSubAgentCount, "child count", 1)
              .having((value) => value.mainAgentRunning, "main running", true)
              .having((value) => value.mainAgentOnlySupported, "main-only support", false),
        );
        expect(fake.written, hasLength(before));
      }

      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await Future<void>.delayed(Duration.zero);
      final beforeKeep = fake.written.length;
      final idleRootKeep = await plugin.abortSession(
        sessionId: "root",
        subAgents: PluginAbortSubAgentPolicy.keep,
        useAtomicStop: true,
        knownSubAgentSessionIds: const {"child"},
      );
      expect(
        idleRootKeep,
        isA<PluginAbortAccepted>()
            .having((value) => value.workKept, "child kept", true)
            .having((value) => value.subAgentsHandled, "handled", true),
      );
      expect(fake.written, hasLength(beforeKeep));
      expect(plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"child"});
      await finishChild(parentSessionId: "root", childSessionId: "child");
    });

    test("keep retains a terminal child's autonomous root hold", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "child");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await Future<void>.delayed(Duration.zero);
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": "root",
          "update": {
            "sessionUpdate": "subagent_finished",
            "subagent_id": "child",
            "child_session_id": "child",
            "status": "completed",
            "will_wake": true,
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.childSessionTracker.busyChildIds(sessionId: "root"), isEmpty);
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "root"), isTrue);

      final beforeKeep = fake.written.length;
      final result = await plugin.abortSession(
        sessionId: "root",
        subAgents: PluginAbortSubAgentPolicy.keep,
        useAtomicStop: true,
        knownSubAgentSessionIds: const {"child"},
      );
      expect(
        result,
        isA<PluginAbortAccepted>()
            .having((value) => value.workKept, "hold kept", true)
            .having((value) => value.subAgentsHandled, "handled", true),
      );
      expect(fake.written, hasLength(beforeKeep));
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "root"), isTrue);

      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.updateMethod,
        "params": {
          "sessionId": "root",
          "update": {
            "sessionUpdate": "turn_completed",
            "prompt_id": "${GrokSessionProtocol.autonomousTurnPromptPrefix}child",
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.childSessionTracker.hasRootHold(sessionId: "root"), isFalse);
      expect((await plugin.getSessionStatuses())["root"], const PluginSessionStatus.idle());
    });

    test("named child stop is exact and lifecycle remains settlement authority", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "child");
      await spawnChild(parentSessionId: "root", childSessionId: "sibling");

      final stopping = plugin.abortSession(
        sessionId: "child",
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: true,
        knownSubAgentSessionIds: const {},
      );
      final cancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      expect(cancel["params"], {"subagentId": "child"});
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionCancel), isEmpty);
      fake.emit({
        "jsonrpc": "2.0",
        "id": cancel["id"],
        "result": {
          "result": {
            "subagentId": "child",
            "cancelled": true,
            "outcome": {"kind": "cancelled"},
          },
        },
      });
      expect(
        await stopping,
        isA<PluginAbortAccepted>()
            .having((value) => value.workKept, "kept", false)
            .having((value) => value.subAgentsHandled, "atomic authority", false),
      );
      expect(plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"child", "sibling"});

      await finishChild(parentSessionId: "root", childSessionId: "child");
      expect(plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"sibling"});
      await finishChild(parentSessionId: "root", childSessionId: "sibling");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("current atomic opt-in fans out but returns false authority", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "first");
      await spawnChild(parentSessionId: "root", childSessionId: "second");

      final stopping = plugin.abortSession(
        sessionId: "root",
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: true,
        knownSubAgentSessionIds: const {"first", "second"},
      );
      final rootCancel = await waitForFrame(method: AcpMethods.sessionCancel);
      final firstCancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      final secondCancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      expect(
        [firstCancel, secondCancel].map((frame) => (frame["params"] as Map)["subagentId"]),
        unorderedEquals(["first", "second"]),
      );
      expect(fake.written.indexOf(rootCancel), lessThan(fake.written.indexOf(firstCancel)));
      expect(fake.written.indexOf(rootCancel), lessThan(fake.written.indexOf(secondCancel)));

      for (final frame in [firstCancel, secondCancel]) {
        final childId = (frame["params"] as Map)["subagentId"] as String;
        fake.emit({
          "jsonrpc": "2.0",
          "id": frame["id"],
          "result": {
            "result": {
              "subagentId": childId,
              "cancelled": childId == "first",
              "outcome": {
                "kind": childId == "first" ? "cancelled" : "already_finished",
                if (childId == "second") "status": "completed",
              },
            },
          },
        });
      }
      expect(
        await stopping,
        isA<PluginAbortAccepted>()
            .having((value) => value.workKept, "kept", false)
            .having((value) => value.subAgentsHandled, "atomic authority", false),
      );
      expect(plugin.childSessionTracker.busyChildIds(sessionId: "root"), {"first", "second"});

      await finishChild(parentSessionId: "root", childSessionId: "first");
      await finishChild(parentSessionId: "root", childSessionId: "second");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "cancelled"},
      });
    });

    test("partial child failure still attempts and waits for full snapshot", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "first");
      await spawnChild(parentSessionId: "root", childSessionId: "second");
      var completed = false;
      final stopping = plugin
          .abortSession(
            sessionId: "root",
            subAgents: PluginAbortSubAgentPolicy.stop,
            useAtomicStop: true,
            knownSubAgentSessionIds: const {"first", "second"},
          )
          .whenComplete(() => completed = true);
      final failure = expectLater(stopping, throwsA(isA<PluginOperationException>()));
      await waitForFrame(method: AcpMethods.sessionCancel);
      final firstCancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      final secondCancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstCancel["id"],
        "error": {"code": -32603, "message": "cancel failed"},
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      final secondId = (secondCancel["params"] as Map)["subagentId"] as String;
      fake.emit({
        "jsonrpc": "2.0",
        "id": secondCancel["id"],
        "result": {
          "result": {
            "subagentId": secondId,
            "cancelled": true,
            "outcome": {"kind": "cancelled"},
          },
        },
      });
      await failure;
      expect(
        fake.written.where((frame) => frame["method"] == GrokAcpApi.subagentCancelMethod),
        hasLength(2),
      );

      await finishChild(parentSessionId: "root", childSessionId: "first");
      await finishChild(parentSessionId: "root", childSessionId: "second");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "cancelled"},
      });
    });

    test("released-client opt-out preserves root-only cancellation", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "child");

      final result = await plugin.abortSession(
        sessionId: "root",
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: false,
        knownSubAgentSessionIds: const {"child"},
      );
      expect(result, isA<PluginAbortAccepted>().having((value) => value.subAgentsHandled, "handled", false));
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionCancel), hasLength(1));
      expect(fake.written.where((frame) => frame["method"] == GrokAcpApi.subagentCancelMethod), isEmpty);

      await finishChild(parentSessionId: "root", childSessionId: "child");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
        "result": {"stopReason": "cancelled"},
      });
    });

    test("named stop preserves sibling pending permission and unrelated queued turn", () async {
      await connect();
      final rootPrompt = await startPrompt(sessionId: "root");
      await spawnChild(parentSessionId: "root", childSessionId: "child");
      await spawnChild(parentSessionId: "root", childSessionId: "sibling");
      plugin.primeSessionDirectory(sessionId: "unrelated", directory: "/repo");
      await plugin.sendPrompt(
        promptId: "queued-unrelated",
        sessionId: "unrelated",
        parts: const [PluginPromptPart.text(text: "Queued work")],
        variant: null,
        agent: null,
        model: null,
      );
      final unrelatedLoad = await waitForFrame(method: AcpMethods.sessionLoad);
      for (final entry in const [(id: 901, sessionId: "child"), (id: 902, sessionId: "sibling")]) {
        fake.emit({
          "jsonrpc": "2.0",
          "id": entry.id,
          "method": AcpMethods.sessionRequestPermission,
          "params": {
            "sessionId": entry.sessionId,
            "toolCall": {"toolCallId": "tool-${entry.sessionId}", "title": "Run", "kind": "execute"},
            "options": [
              {"optionId": "allow", "name": "Allow", "kind": "allow_once"},
              {"optionId": "reject", "name": "Reject", "kind": "reject_once"},
            ],
          },
        });
      }
      await Future<void>.delayed(Duration.zero);
      final siblingPermission = (await plugin.getPendingPermissions(sessionId: "sibling")).single;

      final stopping = plugin.abortSession(
        sessionId: "child",
        subAgents: PluginAbortSubAgentPolicy.stop,
        useAtomicStop: true,
        knownSubAgentSessionIds: const {},
      );
      final cancel = await waitForFrame(method: GrokAcpApi.subagentCancelMethod);
      fake.emit({
        "jsonrpc": "2.0",
        "id": cancel["id"],
        "result": {
          "result": {
            "subagentId": "child",
            "cancelled": true,
            "outcome": {"kind": "cancelled"},
          },
        },
      });
      await stopping;
      expect(await plugin.getPendingPermissions(sessionId: "child"), isEmpty);
      expect(await plugin.getPendingPermissions(sessionId: "sibling"), hasLength(1));
      expect(fake.written.singleWhere((frame) => frame["id"] == 901)["result"], {
        "outcome": {"outcome": "cancelled"},
      });
      expect(fake.written.where((frame) => frame["id"] == 902), isEmpty);

      await plugin.replyToPermission(
        requestId: siblingPermission.id,
        sessionId: "sibling",
        reply: PluginPermissionReply.once,
      );
      fake.emit({"jsonrpc": "2.0", "id": unrelatedLoad["id"], "result": const <String, dynamic>{}});
      final unrelatedPrompt = await waitForFrame(method: AcpMethods.sessionPrompt);
      expect((unrelatedPrompt["params"] as Map)["sessionId"], "unrelated");
      fake.emit({
        "jsonrpc": "2.0",
        "id": unrelatedPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await finishChild(parentSessionId: "root", childSessionId: "child");
      await finishChild(parentSessionId: "root", childSessionId: "sibling");
      fake.emit({
        "jsonrpc": "2.0",
        "id": rootPrompt["id"],
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

    test("direct child history uses inherited session/load and replays its own transcript", () async {
      plugin.primeSessionDirectory(sessionId: "child", directory: "/repo");

      final replaying = plugin.getSessionMessages("child");
      await respond(method: AcpMethods.initialize, result: _initializeResult);
      final authenticate = await waitForFrame(method: AcpMethods.authenticate);
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      final load = await waitForFrame(method: AcpMethods.sessionLoad);
      expect(load["params"], {"sessionId": "child", "cwd": "/repo", "mcpServers": <Object>[]});
      fake
        ..emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "user_message_chunk",
              "content": {"type": "text", "text": "Child prompt"},
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "read",
              "title": "Read file",
              "status": "completed",
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "shell",
              "title": "Run tests",
              "status": "completed",
              "rawInput": {"command": "dart test"},
              "_meta": {
                "x.ai/tool": {"name": "run_terminal_command", "kind": "execute"},
              },
              "content": [
                {
                  "type": "content",
                  "content": {"type": "text", "text": "All tests passed"},
                },
              ],
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "Child response"},
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "id": load["id"],
          "result": const {"sessionId": "child", "models": _modelState},
        });

      final messages = await replaying;
      expect(messages.map((message) => message.info.sessionID), everyElement("child"));
      expect(messages.expand((message) => message.parts).whereType<PluginMessagePartText>(), hasLength(2));
      final tools = messages.expand((message) => message.parts).whereType<PluginMessagePartTool>().toList();
      expect(tools, hasLength(2));
      expect(tools.first.state.shellCommand, isNull);
      expect(tools.last.state.shellCommand, "dart test");
      expect(tools.last.state.output, "All tests passed");
    });

    test("root history maps persisted child context and drains late lifecycle without live state", () async {
      final home = Directory.systemTemp.createTempSync("grok-history-home-");
      addTearDown(() => home.deleteSync(recursive: true));
      await plugin.dispose();
      fake = FakeAcpProcess();
      handledFrameIds.clear();
      plugin = GrokPlugin(
        binaryPath: "grok",
        launchDirectory: "/fallback",
        environment: {"HOME": home.path},
        processFactory: (_) async => fake,
      );
      final project = "${home.path}/.grok/sessions/${Uri.encodeComponent("/repo")}";
      final rootDirectory = Directory("$project/root")..createSync(recursive: true);
      final childDirectory = Directory("$project/child")..createSync(recursive: true);
      File("${rootDirectory.path}/summary.json").writeAsStringSync(
        jsonEncode({
          "info": {"id": "root", "cwd": "/repo"},
        }),
      );
      File("${rootDirectory.path}/updates.jsonl").writeAsStringSync(
        jsonEncode({
          "method": "_x.ai/session/update",
          "params": {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "subagent_spawned",
              "subagent_id": "child",
              "child_session_id": "child",
              "subagent_type": "general-purpose",
              "description": "Child task",
            },
          },
        }),
      );
      File("${childDirectory.path}/updates.jsonl").writeAsStringSync(
        jsonEncode({
          "method": "session/update",
          "params": {
            "sessionId": "child",
            "update": {
              "sessionUpdate": "user_message_chunk",
              "content": {"type": "text", "text": "Child-owned prompt"},
            },
          },
        }),
      );
      plugin.primeSessionDirectory(sessionId: "root", directory: "/repo");

      final replaying = plugin.getSessionMessages("root");
      await respond(method: AcpMethods.initialize, result: _initializeResult);
      final authenticate = await waitForFrame(method: AcpMethods.authenticate);
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      final load = await waitForFrame(method: AcpMethods.sessionLoad);
      fake
        ..emit({
          "jsonrpc": "2.0",
          "method": AcpMethods.sessionUpdate,
          "params": {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "tool_call",
              "toolCallId": "spawn",
              "_meta": {
                "x.ai/tool": {"name": "spawn_subagent", "kind": "task"},
              },
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "method": GrokSessionProtocol.updateMethod,
          "params": {
            "sessionId": "root",
            "update": {
              "sessionUpdate": "subagent_spawned",
              "subagent_id": "child",
              "child_session_id": "child",
              "subagent_type": "general-purpose",
              "description": "Child task",
            },
          },
        })
        ..emit({
          "jsonrpc": "2.0",
          "id": load["id"],
          "result": const {"sessionId": "root", "models": _betaModelState},
        });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fake.emit({
        "jsonrpc": "2.0",
        "method": GrokSessionProtocol.notificationMethod,
        "params": {
          "sessionId": "root",
          "update": {
            "sessionUpdate": "subagent_finished",
            "subagent_id": "child",
            "child_session_id": "child",
            "status": "completed",
            "output": "Child result",
            "will_wake": false,
          },
        },
      });

      final messages = await replaying;
      expect(messages, hasLength(1));
      final tile = messages.single.parts.single as PluginMessagePartSubtask;
      expect(tile.prompt, "Child-owned prompt");
      expect(tile.childSessionID, "child");
      expect(tile.taskState!.status, PluginToolStatus.completed);
      expect(tile.taskState!.output, "Child result");
      expect((messages.single.info as PluginMessageAssistant).modelID, "opaque/provider:model-beta");
      expect(plugin.childSessionTracker.isChild(sessionId: "child"), isFalse);
      expect((await plugin.getSessionStatuses()).containsKey("child"), isFalse);
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
