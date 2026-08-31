// Phase 4 write-path integration tests: createSession, sendPrompt,
// abortSession round-trip against an in-memory fake WS, plus the
// notification → BridgeSseEvent pipeline.
// ignore_for_file: cast_nullable_to_non_nullable, prefer_foreach, avoid_dynamic_calls

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("CodexPlugin write path", () {
    late Directory codexHome;
    late _FakeAppServer fake;
    late _FakeAgentToolHost agentToolHost;
    late CodexPlugin plugin;
    late CodexToolOutcomeRepository toolOutcomeRepository;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-write-");
      fake = _FakeAppServer();
      agentToolHost = _FakeAgentToolHost();
      toolOutcomeRepository = createMemoryCodexToolOutcomeRepository();
      const serverUrl = "ws://127.0.0.1:0";
      plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => fake.channel,
        ),
        keepaliveInterval: const Duration(seconds: 30),
        agentToolHost: agentToolHost,
        toolOutcomeRepository: toolOutcomeRepository,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      expect(agentToolHost.disposed, isTrue);
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<void> connectWithPendingPermission({required String threadId}) async {
      fake.respondInOrder([const _Response(result: _initOk)]);
      await plugin.healthCheck();
      fake.pushNotification("thread/started", {
        "thread": {
          "id": threadId,
          "cwd": "/work/sample",
          "createdAt": 1700000000,
          "updatedAt": 1700000000,
        },
      });
      await Future<void>.delayed(Duration.zero);

      final asked = plugin.events
          .where((event) => event is BridgeSsePermissionAsked)
          .cast<BridgeSsePermissionAsked>()
          .first;
      fake.pushServerRequest(
        id: 99,
        method: "item/commandExecution/requestApproval",
        params: {
          "threadId": threadId,
          "turnId": "turn-1",
          "itemId": "item-1",
          "command": "ls",
        },
      );
      await asked.timeout(const Duration(seconds: 1));
      expect(plugin.currentWorkState, PluginWorkState.busy);
    }

    test("thread/start registers exactly the native Device Canvas tools", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-tools"},
          },
        ),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("thread/start")["dynamicTools"], [
        for (final definition in pluginAgentToolDefinitions)
          {
            "type": "function",
            "name": definition.tool.wireName,
            "description": definition.description,
            "inputSchema": definition.inputSchema,
            "deferLoading": false,
          },
      ]);
    });

    test("createSession preserves a Default turn when no model resolves", () async {
      // Respond to: initialize, thread/start, turn/start.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-new",
              "cwd": "/work/sample",
              "createdAt": 1700000000,
              "updatedAt": 1700000005,
              "name": null,
            },
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      final session = await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "hello codex")],
        userVisibleText: "hello codex",
        variant: null,
        agent: "Agent",
        model: null,
      );

      expect(session.id, equals("t-new"));
      expect(session.directory, equals("/work/sample"));
      expect(session.projectID, equals("/work/sample"));

      // Inspect sent frames.
      final methods = fake.sentMethods;
      expect(methods, equals(["initialize", "thread/start", "turn/start"]));
      final turnStartParams = fake.sentParamsFor("turn/start");
      expect(turnStartParams["threadId"], equals("t-new"));
      expect((turnStartParams["input"] as List).first["text"], equals("hello codex"));
      expect(turnStartParams.containsKey("collaborationMode"), isFalse);
      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("createSession forwards inline image data to Codex turn input", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-image",
              "cwd": "/work/sample",
              "createdAt": 1700000000,
              "updatedAt": 1700000005,
              "name": null,
            },
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-image"},
          },
        ),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [
          PluginPromptPart.text(text: "describe this"),
          PluginPromptPart.fileData(
            mime: "image/png",
            base64: "AQID",
            filename: "shot.png",
          ),
        ],
        userVisibleText: "describe this",
        variant: null,
        agent: "Agent",
        model: null,
      );

      final input = fake.sentParamsFor("turn/start")["input"] as List;
      expect(input[1], {
        "type": "image",
        "url": "data:image/png;base64,AQID",
      });
    });

    test("sendPrompt rejects malformed and oversized inline image data", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);
      await plugin.initialize();
      fake.respondInOrder([
        const _Response(
          result: {
            "thread": {"id": "t-invalid-image"},
          },
        ),
        for (var index = 0; index < 3; index++)
          const _Response(
            result: {
              "turn": {"id": "u-invalid-image"},
            },
          ),
      ]);

      final invalidParts = <PluginPromptPart>[
        const PluginPromptPart.fileData(
          mime: "data:image/png",
          base64: "AQID",
          filename: "bad-mime.png",
        ),
        const PluginPromptPart.fileData(
          mime: "image/png",
          base64: "not base64",
          filename: "bad-data.png",
        ),
        const PluginPromptPart.fileData(
          mime: "image/png",
          base64: "",
          filename: "empty.png",
        ),
        PluginPromptPart.fileData(
          mime: "image/png",
          base64: base64Encode(Uint8List(shared.maxInlineMessageAttachmentBytes + 1)),
          filename: "too-large.png",
        ),
      ];

      for (final part in invalidParts) {
        await expectLater(
          plugin.sendPrompt(
            promptId: "prompt-1",
            sessionId: "t-invalid-image",
            parts: [part],
            variant: null,
            agent: null,
            model: null,
          ),
          throwsA(isA<Exception>()),
        );
      }

      expect(fake.sentMethods, ["initialize", "thread/resume"]);
    });

    test("lists skills, invokes them with dollar syntax, and compacts natively", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "cwd": "/work/sample",
                "skills": [
                  {
                    "name": "review",
                    "description": "Review changes",
                    "shortDescription": null,
                    "interface": null,
                    "enabled": true,
                  },
                ],
              },
            ],
          },
        ),
        const _Response(
          result: {
            "thread": {"id": "t-existing", "cwd": "/work/sample"},
            "model": "gpt-5.4",
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-skill"},
          },
        ),
        const _Response(result: {}),
      ]);

      final commands = await plugin.getCommands(projectId: "/work/sample");
      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: "t-existing",
        command: "review",
        arguments: "staged changes",
        userVisibleArguments: "staged changes",
        variant: null,
        agent: "Plan",
        model: null,
      );
      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: "t-existing",
        command: "compact",
        arguments: "",
        userVisibleArguments: null,
        variant: null,
        agent: null,
        model: null,
      );

      expect(commands.map((command) => command.name), ["review", "compact"]);
      expect(fake.sentMethods, [
        "initialize",
        "skills/list",
        "thread/resume",
        "turn/start",
        "thread/compact/start",
      ]);
      expect(fake.sentParamsFor("skills/list"), {
        "cwds": ["/work/sample"],
      });
      final input = fake.sentParamsFor("turn/start")["input"] as List;
      expect(input.single["text"], r"$review staged changes");
      expect(fake.sentParamsFor("turn/start")["collaborationMode"], {
        "mode": "plan",
        "settings": {
          "model": "gpt-5.4",
          "reasoning_effort": "medium",
        },
      });
    });

    test("native compaction clears pending turn evidence", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-compact", "cwd": "/work/sample"},
          },
        ),
        const _Response(result: {}),
      ]);

      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: "t-compact",
        command: "compact",
        arguments: "",
        userVisibleArguments: null,
        variant: null,
        agent: null,
        model: null,
      );
      final idle = plugin.events.firstWhere(
        (event) =>
            event is BridgeSseSessionStatus && shared.SessionStatus.fromJson(event.status) is shared.SessionStatusIdle,
      );
      fake.pushNotification("thread/status/changed", {
        "threadId": "t-compact",
        "status": {"type": "active"},
      });
      fake.pushNotification("thread/status/changed", {
        "threadId": "t-compact",
        "status": {"type": "idle"},
      });
      await idle.timeout(const Duration(seconds: 1));

      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("a live event emitted during the first turn is scoped to the new session's directory", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-live",
              "cwd": "/other/proj",
              "createdAt": 1700000000,
              "updatedAt": 1700000000,
              "name": null,
            },
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);
      // codex can emit a cwd-less notification while turn/start is still in
      // flight and before any rollout exists on disk — the thread directory
      // must already be recorded so the event maps to the session's real
      // project instead of the launch cwd.
      fake.onRequest = (method) {
        if (method == "turn/start") {
          fake.pushNotification("thread/name/updated", {
            "threadId": "t-live",
            "threadName": "First title",
          });
        }
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.createSession(
        directory: "/other/proj",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "go")],
        userVisibleText: "go",
        variant: null,
        agent: null,
        model: null,
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      expect(updated.info["projectID"], equals("/other/proj"));
    });

    test("renameSession keeps a fresh non-launch session on its own project before the rollout is flushed", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-sub",
              "cwd": "/work/sample/packages/core",
              "createdAt": 1700000000,
              "updatedAt": 1700000000,
              "name": null,
            },
          },
        ),
        const _Response(result: {}),
      ]);

      final created = await plugin.createSession(
        directory: "/work/sample/packages/core",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      expect(created.projectID, equals("/work/sample/packages/core"));

      // codexHome is empty — no rollout has been flushed — yet the rename
      // response must still attribute the session to its real project rather
      // than the launch cwd, proving the in-memory thread→directory map is
      // consulted before the disk rollout.
      final renamed = await plugin.renameSession(sessionId: "t-sub", title: "Renamed");
      expect(renamed.projectID, equals("/work/sample/packages/core"));
      expect(renamed.directory, equals("/work/sample/packages/core"));
    });

    test("renameSession retries beyond the initial rollout flush window", () async {
      const emptyRolloutResponse = _Response(
        error: {
          "code": -32603,
          "message":
              "failed to set thread name: Fatal error: failed to update thread metadata "
              "t-empty-rollout: thread-store internal error: failed to read session metadata "
              "/tmp/rollout-t-empty-rollout.jsonl: rollout at "
              "/tmp/rollout-t-empty-rollout.jsonl is empty",
        },
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-empty-rollout"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        const _Response(result: {}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "start")],
        userVisibleText: "start",
        variant: null,
        agent: null,
        model: null,
      );
      final renamed = await plugin.renameSession(
        sessionId: "t-empty-rollout",
        title: "Renamed",
      );

      expect(renamed.title, equals("Renamed"));
      expect(fake.sentMethods.where((method) => method == "thread/name/set"), hasLength(7));
    });

    test("renameSession does not retry unrelated RPC failures", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          error: {
            "code": -32603,
            "message": "failed to set thread name: state database is unavailable",
          },
        ),
        const _Response(result: {}),
      ]);

      await expectLater(
        plugin.renameSession(sessionId: "t-failed", title: "Renamed"),
        throwsA(
          isA<CodexRpcException>().having(
            (error) => error.message,
            "message",
            contains("state database is unavailable"),
          ),
        ),
      );

      expect(fake.sentMethods.where((method) => method == "thread/name/set"), hasLength(1));
    });

    test("renameSession bounds a stalled retry by the rollout deadline", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          error: {
            "code": -32603,
            "message":
                "failed to read session metadata /tmp/rollout.jsonl: "
                "rollout at /tmp/rollout.jsonl is empty",
          },
        ),
        const _Response(respond: false),
      ]);
      final stopwatch = Stopwatch()..start();

      await expectLater(
        plugin.renameSession(sessionId: "t-stalled", title: "Renamed").timeout(const Duration(seconds: 4)),
        throwsA(isA<TimeoutException>()),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test("archiveSession keeps Codex rollout history available", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(result: {}),
      ]);

      await plugin.archiveSession(sessionId: "t-archive");

      expect(fake.sentMethods, isEmpty);
    });

    test("sendPrompt resumes a thread from a prior run before the turn", () async {
      // `t-existing` was never started in this plugin instance, so the
      // app-server has not loaded it — the plugin must resume it on demand
      // before turn/start, or codex would answer "thread not found".
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-existing"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-existing",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );

      final methods = fake.sentMethods;
      expect(methods, equals(["initialize", "thread/resume", "turn/start"]));
      expect(
        fake.sentParamsFor("thread/resume"),
        {"threadId": "t-existing"},
        reason: "Codex restores tools persisted at thread/start and accepts no dynamicTools resume override",
      );
      expect(fake.sentParamsFor("turn/start")["threadId"], equals("t-existing"));
      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("sendPrompt treats an omitted agent as Default so it replaces Plan mode", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-default-mode"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-default"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-default-mode",
        parts: const [PluginPromptPart.text(text: "implement it")],
        variant: null,
        agent: null,
        model: null,
      );

      final params = fake.sentParamsFor("turn/start");
      expect(params.containsKey("model"), isFalse);
      expect(params.containsKey("effort"), isFalse);
      expect(params["collaborationMode"], {
        "mode": "default",
        "settings": {
          "model": "gpt-5.4-mini",
        },
      });
    });

    test("sendPrompt names the user message so codex echoes the prompt id", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-client-id"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-client-id"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prm_1",
        sessionId: "t-client-id",
        parts: const [PluginPromptPart.text(text: "implement it")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start")["clientUserMessageId"], equals("prm_1"));
    });

    test("collaboration mode stamps live messages with its resolved rollout model", () async {
      const sessionId = "019a0000-1111-2222-3333-eeeeeeeeeeee";
      File(p.join(codexHome.path, "config.toml")).writeAsStringSync(
        'model = "gpt-global"\nmodel_provider = "openai"\n',
      );
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/07/24/rollout-2026-07-24T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-07-24T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
          },
        })}\n"
        "${jsonEncode({
          "type": "turn_context",
          "payload": {"model": "gpt-session"},
        })}\n",
      );
      final resolvedFake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      final resolvedPlugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => resolvedFake.channel,
        ),
        keepaliveInterval: const Duration(seconds: 30),
      );
      addTearDown(resolvedPlugin.dispose);
      resolvedFake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId, "modelProvider": "openai"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-resolved"},
          },
        ),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = resolvedPlugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      await resolvedPlugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "plan this")],
        variant: null,
        agent: "Plan",
        model: null,
      );
      resolvedFake.pushNotification("item/completed", {
        "threadId": sessionId,
        "turnId": "u-resolved",
        "item": {
          "type": "agentMessage",
          "id": "i-resolved",
          "text": "The plan",
        },
      });
      await Future<void>.delayed(Duration.zero);

      final messageEvent = events.whereType<BridgeSseMessageUpdated>().single;
      final message = shared.Message.fromJson(messageEvent.info) as shared.MessageAssistant;
      expect(message.modelID, "gpt-session");
    });

    test("sendCommand marks an accepted turn busy before notifications arrive", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-command"},
          },
        ),
      ]);

      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: "t-command",
        command: "review",
        arguments: "recent changes",
        userVisibleArguments: null,
        variant: null,
        agent: null,
        model: null,
      );

      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("forced interruption includes an accepted command before turn/started arrives", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command-force"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-command-force"},
          },
        ),
        const _Response(result: null),
      ]);
      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: "t-command-force",
        command: "review",
        arguments: "recent changes",
        userVisibleArguments: null,
        variant: null,
        agent: null,
        model: null,
      );
      var interruptionCompleted = false;

      final interruption = plugin
          .interruptActiveWork(budget: const Duration(seconds: 2))
          .whenComplete(() => interruptionCompleted = true);
      for (var attempt = 0; attempt < 100 && !fake.sentMethods.contains("turn/interrupt"); attempt++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(fake.sentMethods, contains("turn/interrupt"));
      expect(fake.sentParamsFor("turn/interrupt"), {
        "threadId": "t-command-force",
        "turnId": "u-command-force",
      });
      expect(interruptionCompleted, isFalse);

      fake.pushNotification("turn/completed", {
        "threadId": "t-command-force",
        "turn": {"id": "u-command-force"},
      });

      expect(await interruption, {"t-command-force"});
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("turn/start rejection does not mark the plugin busy", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);
      await plugin.initialize();
      expect(plugin.currentWorkState, PluginWorkState.idle);
      fake.respondInOrder([
        const _Response(
          result: {
            "thread": {"id": "t-rejected"},
          },
        ),
        const _Response(error: {"code": -32000, "message": "turn rejected"}),
      ]);

      await expectLater(
        plugin.sendPrompt(
          promptId: "prompt-1",
          sessionId: "t-rejected",
          parts: const [PluginPromptPart.text(text: "go on")],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<CodexThreadRequestException>()),
      );

      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("accepted turn remains busy through delayed start and clears on completion", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-delayed"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-delayed"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-delayed",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);

      fake.pushNotification("turn/started", {
        "threadId": "t-delayed",
        "turn": {"id": "u-delayed"},
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {"threadId": "t-delayed"});
      await idle.timeout(const Duration(seconds: 1));
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("completion received before turn/start response prevents stale provisional busy", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-early-complete"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-early-complete"},
          },
        ),
      ]);
      fake.onRequest = (method) {
        if (method == "turn/start") {
          fake.pushNotification("turn/completed", {"threadId": "t-early-complete"});
        }
      };

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-early-complete",
        parts: const [PluginPromptPart.text(text: "quick task")],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.workState.firstWhere((state) => state == PluginWorkState.idle).timeout(const Duration(seconds: 1));

      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("delete invalidates an in-flight turn response until the backend recreates the thread", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-deleted"},
          },
        ),
      ]);
      fake.holdNextResponse("turn/start");
      final turnStarted = Completer<void>();
      fake.onRequest = (method) {
        if (method == "turn/start" && !turnStarted.isCompleted) {
          turnStarted.complete();
        }
      };

      final send = plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-deleted",
        parts: const [PluginPromptPart.text(text: "quick task")],
        variant: null,
        agent: null,
        model: null,
      );
      await turnStarted.future;
      await plugin.deleteSession("t-deleted");

      fake.respondToHeld(
        "turn/start",
        const _Response(
          result: {
            "turn": {"id": "u-deleted"},
          },
        ),
      );
      await send;
      expect(plugin.currentWorkState, PluginWorkState.idle);

      fake.respondInOrder([
        const _Response(
          result: {
            "thread": {"id": "t-deleted"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-recreated"},
          },
        ),
      ]);
      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "new lifecycle")],
        userVisibleText: "new lifecycle",
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("deleting a thread rejects its pending approval and clears work state", () async {
      await connectWithPendingPermission(threadId: "t-delete-pending");

      await plugin.deleteSession("t-delete-pending");
      await Future<void>.delayed(Duration.zero);

      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(await plugin.getPendingPermissions(sessionId: "t-delete-pending"), isEmpty);
      expect(fake.serverResponseFor(99)["result"], {"decision": "decline"});
    });

    test("a closed thread rejects its pending approval and clears work state", () async {
      await connectWithPendingPermission(threadId: "t-close-pending");
      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);

      fake.pushNotification("thread/closed", {"threadId": "t-close-pending"});

      await idle.timeout(const Duration(seconds: 1));
      expect(await plugin.getPendingPermissions(sessionId: "t-close-pending"), isEmpty);
      expect(fake.serverResponseFor(99)["result"], {"decision": "decline"});
    });

    test("terminal error sequence clears busy and emits the failure message", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-terminal"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-terminal"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-terminal",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      final visibleError = plugin.events
          .where((event) => event is BridgeSseMessageUpdated)
          .cast<BridgeSseMessageUpdated>()
          .map((event) => shared.Message.fromJson(event.info))
          .where((message) => message is shared.MessageError)
          .cast<shared.MessageError>()
          .first;
      fake.pushNotification("error", {
        "threadId": "t-terminal",
        "turnId": "u-terminal",
        "error": {"message": "turn failed"},
        "willRetry": false,
      });
      fake.pushNotification("turn/completed", {
        "threadId": "t-terminal",
        "turn": {
          "id": "u-terminal",
          "status": "failed",
          "error": {"message": "turn failed"},
        },
      });

      await idle.timeout(const Duration(seconds: 1));
      final error = await visibleError.timeout(const Duration(seconds: 1));
      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(error.id, "u-terminal");
      expect(error.errorMessage, "turn failed");
    });

    test("sendPrompt does not re-resume a thread created in this run", () async {
      // createSession (no parts) loads the thread; a follow-up turn must reuse
      // it without a redundant resume round-trip.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-fresh"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-fresh",
        parts: const [PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentMethods, isNot(contains("thread/resume")));
    });

    test("turn/start 'thread not found' triggers a resume and one retry", () async {
      // A thread the plugin believes is loaded but the app-server has dropped:
      // the first turn/start fails, then resume + retry must recover it.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-dropped"},
          },
        ),
        const _Response(error: {"code": -32600, "message": "thread not found"}),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-dropped"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-2"},
          },
        ),
      ]);

      // createSession with no parts marks t-dropped as loaded.
      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-dropped",
        parts: const [PluginPromptPart.text(text: "are you there")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(
        fake.sentMethods,
        equals(["initialize", "thread/start", "turn/start", "thread/resume", "turn/start"]),
      );
    });

    test("abortSession calls turn/interrupt on the active turn", () async {
      // First the connection + a sendPrompt that triggers turn/started
      // notification, so the plugin knows the turn id to abort. `t-1` is
      // unknown to this run, so the prompt resumes it before the turn.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-1"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-active"},
          },
        ),
        const _Response(result: null),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-1",
        parts: const [PluginPromptPart.text(text: "long task")],
        variant: null,
        agent: null,
        model: null,
      );

      // Simulate codex emitting turn/started so the plugin captures the turn id.
      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-active"},
      });
      // Give the event subscription a microtask to process.
      await Future<void>.delayed(Duration.zero);

      await plugin.abortSession(sessionId: "t-1");

      expect(fake.sentMethods, contains("turn/interrupt"));
      final params = fake.sentParamsFor("turn/interrupt");
      expect(params["threadId"], equals("t-1"));
      expect(params["turnId"], equals("u-active"));
    });

    test("forced interruption includes an accepted turn before turn/started arrives", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-force", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-force"},
          },
        ),
        const _Response(result: null),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-force",
        parts: const [PluginPromptPart.text(text: "long task")],
        variant: null,
        agent: null,
        model: null,
      );
      var interruptionCompleted = false;

      final interruption = plugin
          .interruptActiveWork(budget: const Duration(seconds: 2))
          .whenComplete(() => interruptionCompleted = true);
      for (var attempt = 0; attempt < 100 && !fake.sentMethods.contains("turn/interrupt"); attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(fake.sentMethods, contains("turn/interrupt"));
      expect(interruptionCompleted, isFalse);

      fake.pushNotification("turn/completed", {
        "threadId": "t-force",
        "turn": {"id": "u-force"},
      });

      expect(await interruption, {"t-force"});
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("delayed prior terminal notifications preserve a newer accepted turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-overlap", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-prior"},
          },
        ),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-overlap",
        parts: const [PluginPromptPart.text(text: "first task")],
        variant: null,
        agent: null,
        model: null,
      );
      final firstIdle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {
        "threadId": "t-overlap",
        "turn": {"id": "u-prior"},
      });
      await firstIdle.timeout(const Duration(seconds: 1));

      fake.respondInOrder([
        const _Response(
          result: {
            "turn": {"id": "u-current"},
          },
        ),
        const _Response(result: null),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-overlap",
        parts: const [PluginPromptPart.text(text: "second task")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);

      fake.pushNotification("turn/completed", {
        "threadId": "t-overlap",
        "turn": {"id": "u-prior"},
      });
      fake.pushNotification("thread/status/changed", {
        "threadId": "t-overlap",
        "status": {"type": "idle"},
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(plugin.currentWorkState, PluginWorkState.busy);
      final interruption = plugin.interruptActiveWork(budget: const Duration(seconds: 2));
      for (var attempt = 0; attempt < 100 && !fake.sentMethods.contains("turn/interrupt"); attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(fake.sentParamsFor("turn/interrupt"), {
        "threadId": "t-overlap",
        "turnId": "u-current",
      });

      fake.pushNotification("turn/completed", {
        "threadId": "t-overlap",
        "turn": {"id": "u-current"},
      });
      expect(await interruption, {"t-overlap"});
    });

    test("steered turn response cannot hide the active turn completion", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-steered", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-active"},
          },
        ),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-steered",
        parts: const [PluginPromptPart.text(text: "first task")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-steered",
        "turn": {"id": "u-active"},
      });
      await Future<void>.delayed(Duration.zero);

      fake.respondInOrder([
        const _Response(
          result: {
            // Codex <=0.147 returned the submission id even though it steered
            // this input into u-active.
            "turn": {"id": "u-submission"},
          },
        ),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: "t-steered",
        parts: const [PluginPromptPart.text(text: "follow up")],
        variant: null,
        agent: null,
        model: null,
      );

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {
        "threadId": "t-steered",
        "turn": {"id": "u-active"},
      });
      await idle.timeout(const Duration(seconds: 1));

      expect((await plugin.getSessionStatuses())["t-steered"], isA<PluginSessionStatusIdle>());
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      await plugin.abortSession(sessionId: "t-steered");
      expect(fake.sentMethods.where((method) => method == "turn/interrupt"), isEmpty);
    });

    test("authoritative turn start replaces a provisional submission id", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-provisional", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-submission"},
          },
        ),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-provisional",
        parts: const [PluginPromptPart.text(text: "continue active work")],
        variant: null,
        agent: null,
        model: null,
      );

      fake.pushNotification("turn/started", {
        "threadId": "t-provisional",
        "turn": {"id": "u-active"},
      });
      await Future<void>.delayed(Duration.zero);
      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {
        "threadId": "t-provisional",
        "turn": {"id": "u-active"},
      });
      await idle.timeout(const Duration(seconds: 1));

      expect((await plugin.getSessionStatuses())["t-provisional"], isA<PluginSessionStatusIdle>());
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("a fresh turn start replaces a stale active turn before its response", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-stale-active", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-stale"},
          },
        ),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-stale-active",
        parts: const [PluginPromptPart.text(text: "first task")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-stale-active",
        "turn": {"id": "u-stale"},
      });
      await Future<void>.delayed(Duration.zero);

      fake.holdNextResponse("turn/start");
      final secondPrompt = plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: "t-stale-active",
        parts: const [PluginPromptPart.text(text: "fresh task")],
        variant: null,
        agent: null,
        model: null,
      );
      for (
        var attempt = 0;
        attempt < 100 && fake.sentMethods.where((method) => method == "turn/start").length < 2;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      fake.pushNotification("thread/status/changed", {
        "threadId": "t-stale-active",
        "status": {"type": "active"},
      });
      fake.pushNotification("turn/started", {
        "threadId": "t-stale-active",
        "turn": {"id": "u-fresh"},
      });
      await Future<void>.delayed(Duration.zero);
      fake.respondToHeld(
        "turn/start",
        const _Response(
          result: {
            "turn": {"id": "u-fresh"},
          },
        ),
      );
      await secondPrompt;

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {
        "threadId": "t-stale-active",
        "turn": {"id": "u-fresh"},
      });
      await idle.timeout(const Duration(seconds: 1));

      expect((await plugin.getSessionStatuses())["t-stale-active"], isA<PluginSessionStatusIdle>());
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("abort reconciles an already-idle Codex turn", () async {
      const sessionId = "019a0000-1111-2222-3333-cccccccccccc";
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/07/23/"
          "rollout-2026-07-23T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-07-23T08:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-07-23T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
            "cli_version": "0.146.0",
          },
        })}\n",
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId, "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-stale"},
          },
        ),
        const _Response(error: {"code": -32600, "message": "no active turn to interrupt"}),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "task")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": sessionId,
        "turn": {"id": "u-stale"},
      });
      await Future<void>.delayed(Duration.zero);
      final idleEvent = plugin.events
          .where((event) => event is BridgeSseSessionIdle)
          .cast<BridgeSseSessionIdle>()
          .first;
      final terminalTool = plugin.events
          .where(
            (event) =>
                event is BridgeSseMessagePartUpdated &&
                event.part.messageID == "call-abort" &&
                event.part.state.status == PluginToolStatus.error,
          )
          .cast<BridgeSseMessagePartUpdated>()
          .first;
      final emittedEvents = <BridgeSseEvent>[];
      final eventSubscription = plugin.events.listen(emittedEvents.add);
      rollout.writeAsStringSync(
        "${jsonEncode(_toolCall(
          id: "fc-abort",
          callId: "call-abort",
          name: "exec_command",
          arguments: '{"cmd":"sleep 30"}',
          turnId: "u-stale",
        ))}\n",
        mode: FileMode.append,
      );

      await plugin.abortSession(sessionId: sessionId);

      expect((await terminalTool.timeout(const Duration(seconds: 1))).part.state.status, PluginToolStatus.error);
      expect((await idleEvent).sessionID, sessionId);
      expect((await plugin.getSessionStatuses())[sessionId], isA<PluginSessionStatusIdle>());
      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(emittedEvents.whereType<BridgeSseSessionUpdated>(), hasLength(1));
      await eventSubscription.cancel();
    });

    test("already-idle reconciliation emits a drained rollout failure", () async {
      const sessionId = "019a0000-1111-2222-3333-dddddddddddd";
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/08/20/"
          "rollout-2026-08-20T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-08-20T08:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-08-20T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
            "cli_version": "0.146.0",
          },
        })}\n",
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId, "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-failed"},
          },
        ),
        const _Response(error: {"code": -32600, "message": "no active turn to interrupt"}),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "task")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": sessionId,
        "turn": {"id": "u-failed"},
      });
      await Future<void>.delayed(Duration.zero);
      final emittedEvents = <BridgeSseEvent>[];
      final eventSubscription = plugin.events.listen(emittedEvents.add);
      final idle = plugin.events.firstWhere((event) => event is BridgeSseSessionIdle);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-08-20T08:00:05Z",
          "type": "event_msg",
          "payload": {
            "type": "task_complete",
            "turn_id": "u-failed",
            "error": {"message": "You've hit your usage limit."},
          },
        })}\n",
        mode: FileMode.append,
      );

      await plugin.abortSession(sessionId: sessionId);
      await idle;

      final errorIndex = emittedEvents.indexWhere(
        (event) =>
            event is BridgeSseMessageUpdated &&
            switch (shared.Message.fromJson(event.info)) {
              shared.MessageError(errorMessage: "You've hit your usage limit.") => true,
              _ => false,
            },
      );
      final idleIndex = emittedEvents.indexWhere((event) => event is BridgeSseSessionIdle);
      expect(errorIndex, greaterThanOrEqualTo(0));
      expect(idleIndex, greaterThan(errorIndex));
      final error = shared.Message.fromJson((emittedEvents[errorIndex] as BridgeSseMessageUpdated).info);
      expect(error.id, "u-failed");
      expect(
        error.time,
        shared.MessageTime(
          created: DateTime.utc(2026, 8, 20, 8, 0, 5).millisecondsSinceEpoch,
          completed: null,
        ),
      );
      await eventSubscription.cancel();
    });

    test("stale abort reconciliation preserves a newer external turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-abort-race", "cwd": "/work/sample"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-old"},
          },
        ),
        const _Response(error: {"code": -32600, "message": "no active turn to interrupt"}),
      ]);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-abort-race",
        parts: const [PluginPromptPart.text(text: "old work")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-abort-race",
        "turn": {"id": "u-old"},
      });
      await Future<void>.delayed(Duration.zero);
      final interruptRequested = Completer<void>();
      fake.onRequest = (method) {
        if (method == "turn/interrupt") interruptRequested.complete();
      };
      final emittedEvents = <BridgeSseEvent>[];
      final eventSubscription = plugin.events.listen(emittedEvents.add);

      final abort = plugin.abortSession(sessionId: "t-abort-race");
      await interruptRequested.future;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      fake.pushNotification("turn/started", {
        "threadId": "t-abort-race",
        "turn": {"id": "u-new"},
      });
      await abort;

      expect((await plugin.getSessionStatuses())["t-abort-race"], isA<PluginSessionStatusBusy>());
      expect(plugin.currentWorkState, PluginWorkState.busy);
      expect(plugin.getActiveSessionsSummary().single.activeSessions.single.id, "t-abort-race");
      expect(emittedEvents.whereType<BridgeSseSessionIdle>(), isEmpty);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {
        "threadId": "t-abort-race",
        "turn": {"id": "u-new"},
      });
      await idle.timeout(const Duration(seconds: 1));
      await eventSubscription.cancel();
    });

    test("turn/start rejects a whitespace-only nested turn id", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-whitespace"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "   "},
          },
        ),
      ]);

      await expectLater(
        plugin.sendPrompt(
          promptId: "prompt-1",
          sessionId: "t-whitespace",
          parts: const [PluginPromptPart.text(text: "continue")],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            "message",
            "turn/start response missing turn.id",
          ),
        ),
      );
    });

    test("error waits for terminal rollout history before reporting idle", () async {
      const sessionId = "019a0000-1111-2222-3333-bbbbbbbbbbbb";
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/07/23/"
          "rollout-2026-07-23T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-07-23T08:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-07-23T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
            "cli_version": "0.144.1",
          },
        })}\n",
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-error"},
          },
        ),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "run a tool")],
        variant: null,
        agent: null,
        model: null,
      );
      final record = jsonEncode(
        _toolCall(
          id: "fc-error",
          callId: "call-error",
          name: "exec_command",
          arguments: '{"cmd":"sleep 1"}',
        ),
      );
      final split = record.length ~/ 2;
      rollout.writeAsStringSync(record.substring(0, split), mode: FileMode.append);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      final failedTool = plugin.events.firstWhere(
        (event) =>
            event is BridgeSseMessagePartUpdated &&
            event.part.messageID == "call-error" &&
            event.part.state.status == PluginToolStatus.error,
      );
      fake.pushNotification("error", {
        "threadId": sessionId,
        "error": {"message": "turn failed"},
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(plugin.currentWorkState, PluginWorkState.busy);

      rollout.writeAsStringSync("${record.substring(split)}\n", mode: FileMode.append);
      await idle.timeout(const Duration(seconds: 1));
      await failedTool.timeout(const Duration(seconds: 1));
      expect(
        events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part.messageID),
        contains("call-error"),
      );
      expect(
        events
            .whereType<BridgeSseMessagePartUpdated>()
            .lastWhere((event) => event.part.messageID == "call-error")
            .part
            .state
            .status,
        PluginToolStatus.error,
      );
    });

    test("notification stream is mapped into bridge events", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);

      // Subscribe BEFORE the connection so buffered events flow.
      final events = <BridgeSseEvent>[];
      final terminalActivityUpdate = Completer<void>();
      var projectUpdates = 0;
      final subscription = plugin.events.listen((event) {
        events.add(event);
        if (event is BridgeSseProjectUpdated) {
          projectUpdates++;
          if (projectUpdates == 2) terminalActivityUpdate.complete();
        }
      });

      // Trigger _ensureConnected.
      await plugin.healthCheck();

      fake.pushNotification("thread/started", {
        "thread": {
          "id": "t-1",
          "cwd": "/work/sample",
          "createdAt": 1700000000,
          "updatedAt": 1700000000,
        },
      });
      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-1", "startedAt": 1700000005},
      });
      await Future<void>.delayed(Duration.zero);

      final running = plugin.getActiveSessionsSummary();
      expect(running, hasLength(1));
      expect(running.single.id, "/work/sample");
      expect(running.single.activeSessions.single.id, "t-1");
      expect(running.single.activeSessions.single.mainAgentRunning, isTrue);

      fake.pushNotification("item/agentMessage/delta", {
        "threadId": "t-1",
        "turnId": "u-1",
        "itemId": "i-1",
        "delta": "Hi",
      });
      fake.pushNotification("turn/completed", {
        "threadId": "t-1",
        "turn": {"id": "u-1", "completedAt": 1700000010},
      });

      // A terminal notification may briefly wait for Codex to create/finish
      // its rollout file. Await the activity invalidation emitted after idle
      // instead of assuming the ordered async event pipeline is synchronous.
      await terminalActivityUpdate.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(
        events.map((e) => e.runtimeType.toString()).toList(),
        containsAllInOrder([
          "BridgeSseSessionUpdated",
          "BridgeSseSessionStatus",
          "BridgeSseProjectUpdated",
          "BridgeSseMessagePartDelta",
          "BridgeSseSessionUpdated",
          "BridgeSseSessionIdle",
          "BridgeSseProjectUpdated",
        ]),
      );

      // Active session status is tracked from the notifications.
      final statuses = await plugin.getSessionStatuses();
      expect(statuses["t-1"], isA<PluginSessionStatusIdle>());
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("live rollout tools converge exactly with reloaded history", () async {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/07/23/"
          "rollout-2026-07-23T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-07-23T08:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-07-23T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
            "cli_version": "0.144.1",
          },
        })}\n",
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-live"},
          },
        ),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "run the live event fixture")],
        variant: null,
        agent: null,
        model: null,
      );

      final records = <Map<String, Object?>>[
        _toolCall(
          id: "fc-immediate",
          callId: "call-immediate",
          name: "exec_command",
          arguments: '{"cmd":"printf \'LIVE-EVENT-TEST immediate-complete\\\\n\'"}',
          turnId: "u-live",
        ),
        _toolOutput(
          callId: "call-immediate",
          output: _processOutput(
            chunkId: "immediate",
            exitCode: 0,
            output: "LIVE-EVENT-TEST immediate-complete\n",
          ),
        ),
        _customToolCall(
          id: "ct-exec-1",
          callId: "call-exec-1",
          turnId: "u-live",
          input:
              'const r = await tools.exec_command({cmd:"sleep 5"}); '
              "text(r.output);",
        ),
        _customToolOutput(
          callId: "call-exec-1",
          output:
              "Script running with cell ID 1\n"
              "Wall time: 0.01 seconds\n"
              "Output:\n",
        ),
        _toolCall(
          id: "fc-wait-1",
          callId: "call-wait-1",
          name: "wait",
          arguments: '{"cell_id":"1","yield_time_ms":10000,"max_tokens":20000}',
          turnId: "u-live",
        ),
        _toolOutput(
          callId: "call-wait-1",
          output:
              "Script completed with exit code 0\n"
              "Final output:\n",
        ),
        _customToolCall(
          id: "ct-exec-2",
          callId: "call-exec-2",
          turnId: "u-live",
          input:
              'const r = await tools.exec_command({cmd:"sleep 2"}); '
              "text(r.output);",
        ),
        _customToolOutputWithImage(
          callId: "call-exec-2",
          output:
              "Script running with cell ID 2\n"
              "Wall time: 0.01 seconds\n"
              "Output:\n",
          imageUrl: "data:image/png;base64,AA==",
        ),
        _toolCall(
          id: "fc-wait-2",
          callId: "call-wait-2",
          name: "wait",
          arguments: '{"cell_id":"2","yield_time_ms":10000,"max_tokens":20000}',
          turnId: "u-live",
        ),
        _toolOutput(
          callId: "call-wait-2",
          output:
              "Script completed with exit code 0\n"
              "Final output:\n",
        ),
        _toolCall(
          id: "fc-failed",
          callId: "call-failed",
          name: "exec_command",
          arguments: '{"cmd":"/usr/bin/false"}',
        ),
        _toolOutput(
          callId: "call-failed",
          output: _processOutput(
            chunkId: "failed",
            exitCode: 1,
            output: "",
          ),
        ),
        _toolCall(
          id: "fc-recovery",
          callId: "call-recovery",
          name: "exec_command",
          arguments: '{"cmd":"printf \'LIVE-EVENT-TEST recovery-complete\\\\n\'"}',
        ),
        _toolOutput(
          callId: "call-recovery",
          output: _processOutput(
            chunkId: "recovery",
            exitCode: 0,
            output: "LIVE-EVENT-TEST recovery-complete\n",
          ),
        ),
        _customToolCall(
          id: "ct-image-wrapper",
          callId: "call-image-wrapper",
          turnId: "u-live",
          input: "await tools.image_gen__generate({prompt: 'private'});",
        ),
        _customToolOutput(
          callId: "call-image-wrapper",
          output: "internal image wrapper output",
        ),
        {
          "timestamp": "2026-07-23T08:00:03Z",
          "type": "response_item",
          "payload": {
            "type": "image_generation_call",
            "id": "image-before-start",
            "status": "completed",
            "revised_prompt": "private prompt",
            "result": "AA==",
          },
        },
        {
          "timestamp": "2026-07-23T08:00:03Z",
          "type": "response_item",
          "payload": {
            "type": "image_generation_call",
            "id": "image-live",
            "status": "completed",
            "revised_prompt": "private prompt",
            "result": "AA==",
          },
        },
        {
          "timestamp": "2026-07-23T08:00:04Z",
          "type": "event_msg",
          "payload": {
            "type": "image_generation_end",
            "call_id": "image-live",
            "status": "completed",
            "revised_prompt": "private prompt",
            "result": "AA==",
            "saved_path": "/private/generated/final.png",
          },
        },
      ];
      final encodedRecords = records.map(jsonEncode).toList();
      final finalRecord = encodedRecords.removeLast();
      final finalRecordSplit = finalRecord.length ~/ 2;
      rollout.writeAsStringSync(
        "${encodedRecords.join("\n")}\n"
        "${finalRecord.substring(0, finalRecordSplit)}",
        mode: FileMode.append,
      );

      fake.pushNotification("item/started", {
        "threadId": sessionId,
        "turnId": "u-live",
        "item": {
          "type": "imageGeneration",
          "id": "image-before-start",
          "status": "in_progress",
          "revisedPrompt": null,
          "result": "",
          "savedPath": null,
        },
      });
      fake
        ..pushNotification("item/started", {
          "threadId": sessionId,
          "turnId": "u-live",
          "item": {
            "type": "commandExecution",
            "id": "exec-immediate",
            "command": "/bin/zsh -lc \"printf 'LIVE-EVENT-TEST immediate-complete\\n'\"",
            "status": "inProgress",
          },
        })
        ..pushNotification("item/completed", {
          "threadId": sessionId,
          "turnId": "u-live",
          "item": {
            "type": "commandExecution",
            "id": "exec-immediate",
            "command": "/bin/zsh -lc \"printf 'LIVE-EVENT-TEST immediate-complete\\n'\"",
            "aggregatedOutput": "LIVE-EVENT-TEST immediate-complete\n",
            "exitCode": 1,
            "status": "failed",
          },
        });

      fake.pushNotification("turn/completed", {
        "threadId": sessionId,
        "turn": {"id": "u-live"},
      });
      // Complete the final output after turn/completed has observed its partial
      // suffix. The terminal drain must still deliver it before session.idle.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      rollout.writeAsStringSync(
        "${finalRecord.substring(finalRecordSplit)}\n",
        mode: FileMode.append,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final finalLiveParts = <String, PluginMessagePart>{};
      for (final event in events.whereType<BridgeSseMessagePartUpdated>()) {
        final part = event.part;
        if (part.type == PluginMessagePartType.tool) {
          finalLiveParts[part.messageID] = part;
        }
      }
      final history = await plugin.getSessionMessages(sessionId);

      expect(finalLiveParts.keys, {
        "call-immediate",
        "call-exec-1",
        "call-exec-2",
        "call-failed",
        "call-recovery",
        "image-before-start",
        "image-live",
      });
      expect(finalLiveParts, isNot(contains("exec-immediate")));
      expect(finalLiveParts, isNot(contains("call-image-wrapper")));
      expect(
        finalLiveParts["call-immediate"]?.state.status,
        PluginToolStatus.error,
      );
      expect(
        await toolOutcomeRepository.readStatuses(sessionId: sessionId),
        {"call-immediate": PluginToolStatus.error},
      );
      expect(history, hasLength(finalLiveParts.length));
      for (final message in history) {
        final historicalPart = message.parts.single;
        final livePart = finalLiveParts[message.info.id];
        expect(livePart, isNotNull, reason: message.info.id);
        expect(livePart?.id, historicalPart.id);
        expect(livePart?.tool, historicalPart.tool);
        expect(livePart?.state.title, historicalPart.state.title);
        expect(livePart?.state.status, historicalPart.state.status);
        expect(livePart?.state.output, historicalPart.state.output);
        expect(livePart?.state.error, historicalPart.state.error);
        expect(livePart?.state.attachments, historicalPart.state.attachments);
      }
      expect(finalLiveParts["call-exec-2"]?.state.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(finalLiveParts["image-live"]?.state.attachments.single, isA<PluginMessageAttachmentInlineImage>());
      expect(
        (finalLiveParts["image-live"]?.state.attachments.single as PluginMessageAttachmentInlineImage).filename,
        "final.png",
      );
      expect(
        finalLiveParts["call-immediate"]?.state.title,
        r"printf 'LIVE-EVENT-TEST immediate-complete\n'",
      );
      expect(finalLiveParts["call-exec-1"]?.state.title, "sleep 5");
      expect(
        finalLiveParts["call-failed"]?.state.status,
        PluginToolStatus.error,
      );
      expect(
        finalLiveParts["call-failed"]?.state.output,
        contains("Process exited with code 1"),
      );
      expect(
        events.lastIndexWhere((event) => event is BridgeSseMessagePartUpdated),
        lessThan(events.lastIndexWhere((event) => event is BridgeSseSessionIdle)),
      );

      await subscription.cancel();
    });

    test("keepalive sends local RPCs while connected, stops on dispose", () async {
      final kaFake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      final kaPlugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => kaFake.channel,
        ),
        keepaliveInterval: const Duration(milliseconds: 20),
      );
      kaFake.respondInOrder([
        const _Response(result: _initOk),
        ...List<_Response>.filled(6, const _Response(result: {"data": <Object>[]})),
      ]);

      await kaPlugin.healthCheck(); // connect → starts keepalive
      await Future<void>.delayed(const Duration(milliseconds: 90));

      final firedWhileConnected = kaFake.sentMethods.where((m) => m == "thread/loaded/list").length;
      expect(firedWhileConnected, greaterThanOrEqualTo(2));
      expect(kaFake.sentRequestHasParams("thread/loaded/list"), isTrue);
      expect(kaFake.sentMethods, isNot(contains("model/list")));

      await kaPlugin.dispose();
      final afterDispose = kaFake.sentMethods.where((m) => m == "thread/loaded/list").length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // No further keepalives once disposed.
      expect(
        kaFake.sentMethods.where((m) => m == "thread/loaded/list").length,
        equals(afterDispose),
      );
    });

    test("getProviders returns codex's full model/list catalog (hidden excluded)", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "id": "gpt-5.5",
                "displayName": "GPT-5.5",
                "hidden": false,
                "isDefault": true,
                "defaultReasoningEffort": "medium",
                "supportedReasoningEfforts": [
                  {"reasoningEffort": "low", "description": "Fast"},
                  {"reasoningEffort": "medium", "description": "Balanced"},
                  {"reasoningEffort": "high", "description": "Deep"},
                  {"reasoningEffort": "xhigh", "description": "Deepest"},
                ],
              },
              {"id": "gpt-5.4-mini", "displayName": "GPT-5.4 mini", "hidden": false, "isDefault": false},
              {"id": "internal", "displayName": "Internal", "hidden": true, "isDefault": false},
            ],
          },
        ),
      ]);

      await plugin.healthCheck(); // connect so model/list can be called
      final result = await plugin.getProviders(projectId: "/work/sample");

      expect(result.providers, hasLength(1));
      final provider = result.providers.single;
      expect(
        provider.models.map((m) => m.id).toList(),
        equals(["gpt-5.5", "gpt-5.4-mini"]),
      );
      expect(provider.models.first.name, equals("GPT-5.5"));
      expect(provider.defaultModelID, equals("gpt-5.5"));
      // Reasoning efforts surface as variants, default ("medium") moved first so
      // the mobile picker's auto-first-on-switch lands on codex's own default.
      expect(
        provider.models.first.variants,
        equals(["medium", "low", "high", "xhigh"]),
      );
      // A model without supportedReasoningEfforts exposes no variants.
      expect(provider.models[1].variants, isEmpty);
      expect(fake.sentMethods, contains("model/list"));
    });

    test("getAgents uses the live catalog to expose Plan without local model metadata", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "id": "gpt-5.5",
                "displayName": "GPT-5.5",
                "hidden": false,
                "isDefault": true,
              },
            ],
          },
        ),
      ]);

      await plugin.healthCheck();
      final agents = await plugin.getAgents(projectId: "/work/sample");

      expect(agents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(agents.every((agent) => agent.model?.modelID == "gpt-5.5"), isTrue);
    });

    test("getSessionOptions delegates one coherent aggregate with one model/list", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "id": "gpt-5.5",
                "displayName": "GPT-5.5",
                "hidden": false,
                "isDefault": true,
              },
            ],
          },
        ),
        const _Response(
          result: {
            "data": [
              {
                "cwd": "/work/sample",
                "skills": [
                  {
                    "name": "review",
                    "description": "Review changes",
                    "shortDescription": null,
                    "interface": null,
                    "enabled": true,
                  },
                ],
              },
            ],
          },
        ),
      ]);

      final result = await plugin.getSessionOptions(
        projectId: "/work/sample",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );

      final options = (result as PluginSessionOptionsDiscoveryObserved).options;
      expect(options.completeness, PluginSessionOptionsCompleteness.complete);
      expect(options.providers.providers.single.models.single.id, "gpt-5.5");
      expect(options.agents.map((agent) => agent.name), ["Agent", "Plan"]);
      expect(options.commands.map((command) => command.name), ["review", "compact"]);
      expect(fake.sentMethods.where((method) => method == "model/list"), hasLength(1));
    });

    test("getProviders preselects the project's own latest rollout model over codex's live default", () async {
      // The selected project's newest rollout used gpt-5.4-mini, while codex's
      // live catalog marks gpt-5.5 as the global default — the project-scoped
      // model must win the picker preselection.
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/06/01/rollout-2026-06-01T10-00-00-019a0000-1111-2222-3333-dddddddddddd.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "type": "session_meta",
          "payload": {
            "id": "019a0000-1111-2222-3333-dddddddddddd",
            "timestamp": "2026-06-01T10:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
          },
        })}\n"
        "${jsonEncode({
          "type": "turn_context",
          "payload": {"model": "gpt-5.4-mini"},
        })}\n",
      );
      final scopedFake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      final scopedPlugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => scopedFake.channel,
        ),
        keepaliveInterval: const Duration(seconds: 30),
      );
      addTearDown(scopedPlugin.dispose);
      scopedFake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {"id": "gpt-5.5", "displayName": "GPT-5.5", "hidden": false, "isDefault": true},
              {"id": "gpt-5.4-mini", "displayName": "GPT-5.4 mini", "hidden": false, "isDefault": false},
            ],
          },
        ),
      ]);

      await scopedPlugin.healthCheck(); // connect so model/list can be called
      final result = await scopedPlugin.getProviders(projectId: "/work/sample");

      expect(result.providers.single.defaultModelID, equals("gpt-5.4-mini"));
    });

    test("sendPrompt forwards the selected variant in Plan mode settings", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-effort"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-effort",
        parts: const [PluginPromptPart.text(text: "think hard")],
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
        model: null,
      );

      final params = fake.sentParamsFor("turn/start");
      expect(params.containsKey("effort"), isFalse);
      expect(params["collaborationMode"], {
        "mode": "plan",
        "settings": {
          "model": "gpt-5.5",
          "reasoning_effort": "high",
        },
      });
    });

    test("sendPrompt without a variant sends no effort (codex uses its default)", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-default"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: "t-default",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start").containsKey("effort"), isFalse);
    });

    test("legacy codex agent selects Default mode on the first turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "thread": {"id": "t-new"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "u-1"},
          },
        ),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "start low")],
        userVisibleText: "start low",
        variant: const PluginSessionVariant(id: "low"),
        agent: "codex",
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentParamsFor("turn/start")["collaborationMode"], {
        "mode": "default",
        "settings": {
          "model": "gpt-5.5",
          "reasoning_effort": "low",
        },
      });
    });
  });
}

const Map<String, dynamic> _initOk = {
  "userAgent": "codex-cli/0.121.0",
  "codexHome": "/Users/test/.codex",
  "platformOs": "macos",
  "platformFamily": "unix",
};

class const _Response({final Object? result, final Map<String, dynamic>? error, final bool respond = true});

Map<String, Object?> _toolCall({
  required String id,
  required String callId,
  required String name,
  required String arguments,
  String? turnId,
}) => {
  "timestamp": "2026-07-23T08:00:01Z",
  "type": "response_item",
  "payload": {
    "type": "function_call",
    "id": id,
    "call_id": callId,
    "name": name,
    "arguments": arguments,
    if (turnId != null)
      "internal_chat_message_metadata_passthrough": {
        "turn_id": turnId,
      },
  },
};

Map<String, Object?> _customToolCall({
  required String id,
  required String callId,
  required String input,
  String? turnId,
}) => {
  "timestamp": "2026-07-23T08:00:01Z",
  "type": "response_item",
  "payload": {
    "type": "custom_tool_call",
    "id": id,
    "call_id": callId,
    "name": "exec",
    "input": input,
    if (turnId != null)
      "internal_chat_message_metadata_passthrough": {
        "turn_id": turnId,
      },
  },
};

Map<String, Object?> _toolOutput({
  required String callId,
  required String output,
}) => {
  "timestamp": "2026-07-23T08:00:02Z",
  "type": "response_item",
  "payload": {
    "type": "function_call_output",
    "call_id": callId,
    "output": output,
  },
};

Map<String, Object?> _customToolOutput({
  required String callId,
  required String output,
}) => {
  "timestamp": "2026-07-23T08:00:02Z",
  "type": "response_item",
  "payload": {
    "type": "custom_tool_call_output",
    "call_id": callId,
    "output": [
      {"type": "input_text", "text": output},
    ],
  },
};

Map<String, Object?> _customToolOutputWithImage({
  required String callId,
  required String output,
  required String imageUrl,
}) => {
  "timestamp": "2026-07-23T08:00:02Z",
  "type": "response_item",
  "payload": {
    "type": "custom_tool_call_output",
    "call_id": callId,
    "output": [
      {"type": "input_text", "text": output},
      {"type": "input_image", "image_url": imageUrl},
    ],
  },
};

String _processOutput({
  required String chunkId,
  required int exitCode,
  required String output,
}) =>
    "Chunk ID: $chunkId\n"
    "Wall time: 0.01 seconds\n"
    "Process exited with code $exitCode\n"
    "Original token count: 3\n"
    "Final output:\n"
    "$output";

/// Fake app-server that records every method/params it received and
/// replies in the order [respondInOrder] queued. Lets us push
/// server-originated notifications via [pushNotification].
class _FakeAppServer() {
  this {
    _clientToServer = StreamController<Object?>.broadcast();
    _serverToClient = StreamController<Object?>.broadcast();
    channel = _StubChannel(
      stream: _serverToClient.stream,
      sink: _SinkAdapter(_clientToServer),
    );
    _clientToServer.stream.listen(_onClientFrame);
  }

  late final StreamController<Object?> _clientToServer;
  late final StreamController<Object?> _serverToClient;
  late final WebSocketChannel channel;

  final List<_SentFrame> _sent = [];
  final List<_Response> _pending = [];
  final Set<String> _responsesToHold = {};
  final Map<String, Object> _heldRequestIds = {};
  final Map<Object, Map<String, dynamic>> _serverResponses = {};

  /// Invoked with each request method BEFORE the canned response is sent —
  /// lets a test emit server notifications mid-request (e.g. codex pushing
  /// `thread/name/updated` while `turn/start` is still in flight).
  void Function(String method)? onRequest;

  List<String> get sentMethods => _sent.map((f) => f.method).toList(growable: false);

  Map<String, dynamic> sentParamsFor(String method) {
    final frame = _sent.firstWhere((f) => f.method == method);
    return frame.params ?? const {};
  }

  bool sentRequestHasParams(String method) => _sent.firstWhere((frame) => frame.method == method).params != null;

  Map<String, dynamic> serverResponseFor(Object id) =>
      _serverResponses[id] ?? (throw StateError("no response for $id"));

  void respondInOrder(List<_Response> responses) {
    _pending
      ..clear()
      ..addAll(responses);
  }

  void holdNextResponse(String method) {
    _responsesToHold.add(method);
  }

  void respondToHeld(String method, _Response response) {
    final id = _heldRequestIds.remove(method);
    if (id == null) throw StateError("no held request for $method");
    _sendResponse(id, response);
  }

  void pushNotification(String method, Map<String, dynamic> params) {
    _serverToClient.add(
      jsonEncode({"jsonrpc": "2.0", "method": method, "params": params}),
    );
  }

  void pushServerRequest({required Object id, required String method, required Map<String, dynamic> params}) {
    _serverToClient.add(
      jsonEncode({"jsonrpc": "2.0", "id": id, "method": method, "params": params}),
    );
  }

  void _onClientFrame(Object? frame) {
    final raw = frame as String;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final method = decoded["method"] as String?;
    if (method == null) {
      final id = decoded["id"] as Object?;
      if (id != null) _serverResponses[id] = decoded;
      return;
    }
    _sent.add(
      _SentFrame(
        method: method,
        params: (decoded["params"] as Map?)?.cast<String, dynamic>(),
      ),
    );
    onRequest?.call(method);
    final id = decoded["id"] as Object?;
    if (id == null) return; // notification from client (none today)
    if (_responsesToHold.remove(method)) {
      _heldRequestIds[method] = id;
      return;
    }
    if (_pending.isEmpty) {
      _serverToClient.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "id": id,
          "error": {
            "code": -32603,
            "message": "no canned response for ${decoded["method"]}",
          },
        }),
      );
      return;
    }
    final response = _pending.removeAt(0);
    if (!response.respond) return;
    _sendResponse(id, response);
  }

  void _sendResponse(Object id, _Response response) {
    final envelope = <String, dynamic>{"jsonrpc": "2.0", "id": id};
    if (response.error != null) {
      envelope["error"] = response.error;
    } else {
      envelope["result"] = response.result;
    }
    _serverToClient.add(jsonEncode(envelope));
  }
}

class _SentFrame({required final String method, required final Map<String, dynamic>? params});

class _FakeAgentToolHost() implements PluginAgentToolHost {
  bool disposed = false;

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async => const {"outcome": "internalError"};

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) => throw UnimplementedError();

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) => throw UnimplementedError();

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _StubChannel({@override required final Stream<dynamic> stream, @override required final WebSocketSink sink})
    implements WebSocketChannel {
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SinkAdapter(final StreamController<Object?> _controller) implements WebSocketSink {
  @override
  void add(Object? data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) async {
    await for (final item in stream) {
      _controller.add(item);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> get done => _controller.done;
}
