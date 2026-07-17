// Phase 4 write-path integration tests: createSession, sendPrompt,
// abortSession round-trip against an in-memory fake WS, plus the
// notification → BridgeSseEvent pipeline.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable, prefer_foreach, avoid_dynamic_calls

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("CodexPlugin write path", () {
    late Directory codexHome;
    late _FakeAppServer fake;
    late CodexPlugin plugin;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-write-");
      fake = _FakeAppServer();
      plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => fake.channel,
        ),
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample",
      );
    });

    tearDown(() async {
      await plugin.dispose();
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
    });

    test("createSession round-trips thread/start and turn/start", () async {
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
        const _Response(result: {"turnId": "u-1"}),
      ]);

      final session = await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "hello codex")],
        variant: null,
        agent: null,
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
        const _Response(result: {"turnId": "u-1"}),
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
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-existing",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );

      final methods = fake.sentMethods;
      expect(methods, equals(["initialize", "thread/resume", "turn/start"]));
      expect(fake.sentParamsFor("thread/resume")["threadId"], equals("t-existing"));
      expect(fake.sentParamsFor("turn/start")["threadId"], equals("t-existing"));
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
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        sessionId: "t-fresh",
        parts: const [PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentMethods, isNot(contains("thread/resume")));
    });

    test("sendCommand returns its turn id and sends slash text", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-command"},
          },
        ),
        const _Response(result: {"turnId": "turn-command"}),
      ]);
      fake.onRequest = (method) {
        if (method == "turn/start") {
          fake.pushNotification("turn/started", {
            "threadId": "t-command",
            "turn": {"id": "turn-command"},
          });
        }
      };

      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      final dispatch = await plugin.sendCommand(
        sessionId: "t-command",
        invocationId: "opaque-codex-invocation",
        command: "plan",
        arguments: "auth flow",
        variant: null,
        agent: null,
        model: null,
      );

      expect(dispatch.backendMessageId, "turn-command");
      expect(fake.sentMethods, equals(["initialize", "thread/resume", "turn/start"]));
      final input = fake.sentParamsFor("turn/start")["input"] as List;
      expect(input.single["text"], "/plan auth flow");
      await Future<void>.delayed(Duration.zero);
      final commandEvents = events.whereType<BridgeSseMessageUpdated>().toList();
      expect(commandEvents, hasLength(1));
      final command = commandEvents.single.info;
      expect(command["role"], "command");
      expect(command["id"], "turn-command");
      expect(command["invocationId"], "opaque-codex-invocation");
      await subscription.cancel();
    });

    test("a command is accepted after disconnect and reconnect", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final firstSocket = Completer<WebSocket>();
      final disconnected = Completer<void>();
      final methodsByConnection = <int, List<String>>{};
      var connectionNumber = 0;
      var turnNumber = 0;
      final serverSubscription = server.transform(WebSocketTransformer()).listen((socket) {
        sockets.add(socket);
        final currentConnection = ++connectionNumber;
        methodsByConnection[currentConnection] = [];
        if (currentConnection == 1) firstSocket.complete(socket);
        socket.listen((frame) {
          final request = jsonDecode(frame as String) as Map<String, dynamic>;
          final method = request["method"] as String;
          methodsByConnection[currentConnection]!.add(method);
          final result = switch (method) {
            "initialize" => _initOk,
            "thread/resume" => {
              "thread": {"id": "t-reconnect"},
            },
            "turn/start" => {"turnId": "turn-${++turnNumber}"},
            _ => throw StateError("unexpected method $method"),
          };
          socket.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": request["id"],
              "result": result,
            }),
          );
        });
      });
      final reconnectingPlugin = CodexPlugin(
        serverUrl: "ws://${server.address.address}:${server.port}",
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample",
        onDisconnected: () {
          if (!disconnected.isCompleted) disconnected.complete();
        },
      );
      addTearDown(() async {
        await reconnectingPlugin.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
        await serverSubscription.cancel();
      });

      final first = await reconnectingPlugin.sendCommand(
        sessionId: "t-reconnect",
        invocationId: "first-invocation",
        command: "plan",
        arguments: "first",
        variant: null,
        agent: null,
        model: null,
      );
      expect(first.backendMessageId, "turn-1");

      await (await firstSocket.future).close();
      await disconnected.future;

      final second = await reconnectingPlugin.sendCommand(
        sessionId: "t-reconnect",
        invocationId: "second-invocation",
        command: "review",
        arguments: "second",
        variant: null,
        agent: null,
        model: null,
      );

      expect(second.backendMessageId, "turn-2");
      expect(methodsByConnection, {
        1: ["initialize", "thread/resume", "turn/start"],
        2: ["initialize", "thread/resume", "turn/start"],
      });
    });

    test("command notifications before turn response bind to the returned turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command-race"},
          },
        ),
        const _Response(result: {"turnId": "returned-race-turn"}),
      ]);
      fake.onRequest = (method) async {
        if (method != "turn/start") return;
        fake.pushNotification("turn/started", {
          "threadId": "t-command-race",
          "turn": {"id": "returned-race-turn"},
        });
        fake.pushNotification("item/completed", {
          "threadId": "t-command-race",
          "turnId": "returned-race-turn",
          "item": {
            "type": "userMessage",
            "id": "pre-response-slash-user",
            "content": [
              {"type": "text", "text": "/plan auth"},
            ],
          },
        });
        fake.pushNotification("item/completed", {
          "threadId": "t-command-race",
          "turnId": "returned-race-turn",
          "item": {
            "type": "agentMessage",
            "id": "pre-response-result",
            "text": "the pre-response plan",
          },
        });
        await Future<void>.delayed(Duration.zero);
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendCommand(
        sessionId: "t-command-race",
        invocationId: "race-invocation",
        command: "plan",
        arguments: "auth",
        variant: null,
        agent: null,
        model: null,
      );
      await Future<void>.delayed(Duration.zero);

      final messages = events.whereType<BridgeSseMessageUpdated>().map((event) => event.info).toList();
      expect(messages.map((message) => message["role"]), ["command"]);
      expect(messages.single["id"], "returned-race-turn");
      expect(events.first, isA<BridgeSseMessageUpdated>());
      final result = events
          .whereType<BridgeSseMessagePartUpdated>()
          .singleWhere((event) => event.part.id == "returned-race-turn-result")
          .part;
      expect(result.messageID, "returned-race-turn");
      expect(result.text, "the pre-response plan");
      await subscription.cancel();
    });

    test("a second command is rejected before turn/start and leaves the first intact", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command-serialized"},
          },
        ),
        const _Response(result: {"turnId": "first-turn"}),
      ]);
      final releaseTurnStart = Completer<void>();
      final turnStartObserved = Completer<void>();
      addTearDown(() {
        if (!releaseTurnStart.isCompleted) releaseTurnStart.complete();
      });
      fake.onRequest = (method) async {
        if (method != "turn/start") return;
        fake.pushNotification("turn/started", {
          "threadId": "t-command-serialized",
          "turn": {"id": "first-turn"},
        });
        fake.pushNotification("item/completed", {
          "threadId": "t-command-serialized",
          "turnId": "first-turn",
          "item": {
            "type": "agentMessage",
            "id": "first-result",
            "text": "first remains intact",
          },
        });
        await Future<void>.delayed(Duration.zero);
        turnStartObserved.complete();
        await releaseTurnStart.future;
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      final first = plugin.sendCommand(
        sessionId: "t-command-serialized",
        invocationId: "first-invocation",
        command: "plan",
        arguments: "first",
        variant: null,
        agent: null,
        model: null,
      );
      await turnStartObserved.future;

      await expectLater(
        plugin.sendCommand(
          sessionId: "t-command-serialized",
          invocationId: "second-invocation",
          command: "review",
          arguments: "second",
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<CodexCommandAlreadyOutstandingException>()),
      );

      expect(fake.sentMethods.where((method) => method == "turn/start"), hasLength(1));
      expect(events, isEmpty);
      releaseTurnStart.complete();
      final dispatch = await first;
      await Future<void>.delayed(Duration.zero);

      expect(dispatch.backendMessageId, "first-turn");
      final command = events.whereType<BridgeSseMessageUpdated>().single.info;
      expect(command["invocationId"], "first-invocation");
      final result = events.whereType<BridgeSseMessagePartUpdated>().single.part;
      expect(result.messageID, "first-turn");
      expect(result.text, "first remains intact");
      await subscription.cancel();
    });

    test("an unrelated turn/started cannot consume a pending command", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command-order"},
          },
        ),
        const _Response(result: {"turnId": "returned-command-turn"}),
      ]);
      fake.onRequest = (method) async {
        if (method == "turn/start") {
          fake.pushNotification("turn/started", {
            "threadId": "t-command-order",
            "turn": {"id": "ordinary-turn"},
          });
          fake.pushNotification("item/completed", {
            "threadId": "t-command-order",
            "turnId": "ordinary-turn",
            "item": {
              "type": "userMessage",
              "id": "ordinary-user",
              "content": [
                {"type": "text", "text": "ordinary prompt"},
              ],
            },
          });
          await Future<void>.delayed(Duration.zero);
        }
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      final dispatch = await plugin.sendCommand(
        sessionId: "t-command-order",
        invocationId: "ordered-invocation",
        command: "plan",
        arguments: "ordering",
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-command-order",
        "turn": {"id": "returned-command-turn"},
      });
      await Future<void>.delayed(Duration.zero);

      expect(dispatch.backendMessageId, "returned-command-turn");
      final messages = events.whereType<BridgeSseMessageUpdated>().map((event) => event.info).toList();
      expect(
        messages.where((message) => message["role"] == "command"),
        hasLength(1),
      );
      expect(
        messages.singleWhere((message) => message["role"] == "command")["id"],
        "returned-command-turn",
      );
      expect(
        messages.singleWhere((message) => message["role"] == "user")["id"],
        "ordinary-user",
      );
      await subscription.cancel();
    });

    test("live command suppresses slash echo and reparents text, reasoning, and tools", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-live-command"},
          },
        ),
        const _Response(
          result: {
            "turn": {"id": "turn-live-command"},
          },
        ),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendCommand(
        sessionId: "t-live-command",
        invocationId: "invocation-live",
        command: "plan",
        arguments: "auth",
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-live-command",
        "turn": {"id": "turn-live-command"},
      });
      for (final phase in ["item/started", "item/completed"]) {
        fake.pushNotification(phase, {
          "threadId": "t-live-command",
          "turnId": "turn-live-command",
          "item": {
            "type": "userMessage",
            "id": "slash-user",
            "content": [
              {"type": "text", "text": "/plan auth"},
            ],
          },
        });
      }
      fake.pushNotification("item/started", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "item": {"type": "agentMessage", "id": "agent-result", "text": ""},
      });
      fake.pushNotification("item/agentMessage/delta", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "itemId": "agent-result",
        "delta": "the plan",
      });
      fake.pushNotification("item/completed", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "item": {"type": "agentMessage", "id": "agent-result", "text": "the plan"},
      });
      fake.pushNotification("item/started", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "item": {
          "type": "reasoning",
          "id": "reasoning-result",
          "summary": ["checking"],
        },
      });
      fake.pushNotification("item/reasoning/summaryTextDelta", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "itemId": "reasoning-result",
        "delta": " more",
      });
      fake.pushNotification("item/started", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "item": {
          "type": "commandExecution",
          "id": "tool-result",
          "command": "dart test",
          "status": "inProgress",
        },
      });
      fake.pushNotification("item/commandExecution/outputDelta", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "itemId": "tool-result",
        "delta": "running",
      });
      fake.pushNotification("item/completed", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "item": {
          "type": "commandExecution",
          "id": "tool-result",
          "command": "dart test",
          "status": "completed",
          "aggregatedOutput": "ok",
        },
      });
      fake.pushNotification("item/part/removed", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "itemId": "tool-result",
        "partId": "tool-result-tool",
      });
      fake.pushNotification("item/removed", {
        "threadId": "t-live-command",
        "turnId": "turn-live-command",
        "itemId": "tool-result",
      });
      fake.pushNotification("turn/completed", {
        "threadId": "t-live-command",
        "turn": {"id": "turn-live-command"},
      });
      await Future<void>.delayed(Duration.zero);

      final messages = events.whereType<BridgeSseMessageUpdated>().map((event) => event.info).toList();
      expect(messages, hasLength(1));
      final command = messages.single;
      expect(command["role"], "command");
      expect(command["invocationId"], "invocation-live");
      expect(command["name"], "plan");
      expect(command["arguments"], "auth");

      final deltas = events.whereType<BridgeSseMessagePartDelta>().toList();
      expect(
        deltas,
        contains(
          isA<BridgeSseMessagePartDelta>()
              .having((event) => event.messageID, "messageID", "turn-live-command")
              .having((event) => event.partID, "partID", "turn-live-command-result")
              .having((event) => event.delta, "delta", "the plan"),
        ),
      );
      expect(
        deltas,
        contains(
          isA<BridgeSseMessagePartDelta>()
              .having((event) => event.messageID, "messageID", "turn-live-command")
              .having((event) => event.partID, "partID", "tool-result-tool")
              .having((event) => event.field, "field", "state.output")
              .having((event) => event.delta, "delta", "running"),
        ),
      );
      expect(
        deltas,
        contains(
          isA<BridgeSseMessagePartDelta>()
              .having((event) => event.messageID, "messageID", "turn-live-command")
              .having((event) => event.partID, "partID", "reasoning-result-reasoning"),
        ),
      );
      final parts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
      expect(
        parts.lastWhere((part) => part.id == "turn-live-command-result").text,
        "the plan",
      );
      expect(
        parts.lastWhere((part) => part.id == "tool-result-tool"),
        isA<PluginMessagePart>()
            .having((part) => part.messageID, "messageID", "turn-live-command")
            .having((part) => part.tool, "tool", "shell"),
      );
      final removedToolParts = events.whereType<BridgeSseMessagePartRemoved>().where(
        (event) => event.messageID == "turn-live-command" && event.partID == "tool-result-tool",
      );
      expect(
        removedToolParts,
        hasLength(1),
        reason: "item removal must not remove an already removed part twice",
      );

      final history =
          CodexMessageRepository(
            rolloutReader: SessionRolloutReader(
              environment: {"CODEX_HOME": codexHome.path},
            ),
            configReader: CodexConfigReader(
              environment: {"CODEX_HOME": codexHome.path},
            ),
          ).mapHistory(
            sessionId: "t-live-command",
            records: const [
              CodexRolloutMessageRecord(
                id: "persisted-user",
                role: CodexRolloutMessageRole.user,
                timestamp: null,
                modelId: null,
                providerId: null,
                texts: ["/plan auth"],
                tool: null,
              ),
              CodexRolloutMessageRecord(
                id: "persisted-agent",
                role: CodexRolloutMessageRole.assistant,
                timestamp: null,
                modelId: "gpt-5.5",
                providerId: "openai",
                texts: ["the plan"],
                tool: null,
              ),
              CodexRolloutMessageRecord(
                id: "persisted-tool",
                role: CodexRolloutMessageRole.assistant,
                timestamp: null,
                modelId: "gpt-5.5",
                providerId: "openai",
                texts: [],
                tool: CodexRolloutToolRecord(
                  name: "shell",
                  title: "dart test",
                  status: CodexRolloutToolStatus.completed,
                  output: "ok",
                ),
              ),
            ],
            config: const CodexConfigDefaults.empty(),
            acceptedCommands: const [
              PluginCommandInvocationContext(
                invocationId: "invocation-live",
                name: "plan",
                arguments: "auth",
                acceptedAt: 1,
                backendMessageId: "turn-live-command",
              ),
            ],
            knownCommandNames: const {"plan"},
          );
      final historicalCommand = history.single.info as PluginMessageCommand;
      expect(historicalCommand.name, command["name"]);
      expect(historicalCommand.arguments, command["arguments"]);
      expect(historicalCommand.invocationId, command["invocationId"]);
      expect(historicalCommand.id, command["id"]);
      expect(
        history.single.parts.map((part) => part.type).toList(),
        [PluginMessagePartType.text, PluginMessagePartType.tool],
      );
      expect(history.single.parts.first.text, "the plan");
      await subscription.cancel();
    });

    test("a rejected command flushes held notifications as ordinary events", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-rejected"},
          },
        ),
        const _Response(
          error: {"code": -32602, "message": "command rejected"},
        ),
      ]);
      fake.onRequest = (method) async {
        if (method != "turn/start") return;
        fake.pushNotification("turn/started", {
          "threadId": "t-rejected",
          "turn": {"id": "rejected-turn"},
        });
        fake.pushNotification("item/completed", {
          "threadId": "t-rejected",
          "turnId": "rejected-turn",
          "item": {
            "type": "userMessage",
            "id": "rejected-user",
            "content": [
              {"type": "text", "text": "/plan"},
            ],
          },
        });
        await Future<void>.delayed(Duration.zero);
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await expectLater(
        plugin.sendCommand(
          sessionId: "t-rejected",
          invocationId: "rejected-invocation",
          command: "plan",
          arguments: "",
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<CodexRpcException>()),
      );
      await Future<void>.delayed(Duration.zero);

      final messages = events.whereType<BridgeSseMessageUpdated>().map((event) => event.info).toList();
      expect(messages.where((message) => message["role"] == "command"), isEmpty);
      expect(
        messages.singleWhere((message) => message["role"] == "user")["id"],
        "rejected-user",
      );
      await subscription.cancel();
    });

    test("ordinary prompt keeps separate user and assistant messages", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-prompt"},
          },
        ),
        const _Response(result: {"turnId": "turn-prompt"}),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendPrompt(
        sessionId: "t-prompt",
        parts: const [PluginPromptPart.text(text: "ordinary prompt")],
        variant: null,
        agent: null,
        model: null,
      );
      fake.pushNotification("turn/started", {
        "threadId": "t-prompt",
        "turn": {"id": "turn-prompt"},
      });
      fake.pushNotification("item/completed", {
        "threadId": "t-prompt",
        "turnId": "turn-prompt",
        "item": {
          "type": "userMessage",
          "id": "prompt-user",
          "content": [
            {"type": "text", "text": "ordinary prompt"},
          ],
        },
      });
      fake.pushNotification("item/completed", {
        "threadId": "t-prompt",
        "turnId": "turn-prompt",
        "item": {"type": "agentMessage", "id": "prompt-agent", "text": "ordinary answer"},
      });
      fake.pushNotification("turn/completed", {
        "threadId": "t-prompt",
        "turn": {"id": "turn-prompt"},
      });
      await Future<void>.delayed(Duration.zero);

      final messages = events.whereType<BridgeSseMessageUpdated>().map((event) => event.info).toList();
      expect(messages.map((message) => message["role"]), ["user", "assistant"]);
      final parts = events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part).toList();
      expect(parts.map((part) => part.messageID), ["prompt-user", "prompt-agent"]);
      await subscription.cancel();
    });

    test("prompt APIs reject inline file data before starting backend work", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);
      const inlineData = PluginPromptPart.fileData(
        mime: "image/png",
        base64: "aW1hZ2U=",
        filename: "image.png",
      );
      final unsupportedInlineData = isA<PluginOperationException>()
          .having((error) => error.statusCode, "statusCode", 400)
          .having((error) => error.message, "message", contains("inline file data"));

      await expectLater(
        plugin.sendPrompt(
          sessionId: "t-inline-data",
          parts: const [inlineData],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(unsupportedInlineData),
      );
      await expectLater(
        plugin.createSession(
          directory: "/work/sample",
          parentSessionId: null,
          parts: const [inlineData],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(unsupportedInlineData),
      );
      expect(fake.sentMethods, ["initialize"]);
    });

    test("sendPrompt updates live provider and model metadata together", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-provider"},
          },
        ),
        const _Response(result: {"turnId": "u-provider"}),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendPrompt(
        sessionId: "t-provider",
        parts: const [PluginPromptPart.text(text: "hello")],
        variant: null,
        agent: null,
        model: (providerID: "anthropic", modelID: "claude-sonnet"),
      );
      fake.pushNotification("item/completed", {
        "threadId": "t-provider",
        "turnId": "u-provider",
        "item": {"type": "agentMessage", "id": "provider-answer", "text": "hello"},
      });
      await Future<void>.delayed(Duration.zero);

      final assistant = events
          .whereType<BridgeSseMessageUpdated>()
          .map((event) => event.info)
          .singleWhere((info) => info["role"] == "assistant");
      expect(assistant["modelID"], "claude-sonnet");
      expect(assistant["providerID"], "anthropic");
      await subscription.cancel();
    });

    test("empty model selections are absent and preserve resolved context", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-default",
            "modelProvider": "openai",
            "thread": {"id": "t-empty-model"},
          },
        ),
        const _Response(result: {"turnId": "u-empty-provider"}),
        const _Response(result: {"turnId": "u-empty-model"}),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendPrompt(
        sessionId: "t-empty-model",
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: (providerID: "", modelID: "gpt-selected"),
      );
      await plugin.sendPrompt(
        sessionId: "t-empty-model",
        parts: const [PluginPromptPart.text(text: "second")],
        variant: null,
        agent: null,
        model: (providerID: "openai", modelID: ""),
      );
      expect(
        fake.sentParamsForAll("turn/start").map((params) => params.containsKey("model")),
        [false, false],
      );

      fake.pushNotification("item/completed", {
        "threadId": "t-empty-model",
        "turnId": "u-empty-model",
        "item": {"type": "agentMessage", "id": "empty-model-answer", "text": "hello"},
      });
      await Future<void>.delayed(Duration.zero);
      final assistant = events
          .whereType<BridgeSseMessageUpdated>()
          .map((event) => event.info)
          .singleWhere((info) => info["role"] == "assistant");
      expect(assistant["modelID"], "gpt-default");
      expect(assistant["providerID"], "openai");
      await subscription.cancel();
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
        const _Response(result: {"turnId": "u-2"}),
      ]);

      // createSession with no parts marks t-dropped as loaded.
      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
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
        const _Response(result: {"turnId": "u-active"}),
        const _Response(result: null),
      ]);

      await plugin.sendPrompt(
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

    test("notification stream is mapped into bridge events", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);

      // Subscribe BEFORE the connection so buffered events flow.
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      // Trigger _ensureConnected.
      await plugin.healthCheck();

      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-1"},
      });
      fake.pushNotification("item/agentMessage/delta", {
        "threadId": "t-1",
        "turnId": "u-1",
        "itemId": "i-1",
        "delta": "Hi",
      });
      fake.pushNotification("turn/completed", {"threadId": "t-1"});

      // Drain microtasks so all notification handlers run.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        events.map((e) => e.runtimeType.toString()).toList(),
        containsAllInOrder([
          "BridgeSseSessionStatus",
          "BridgeSseMessagePartDelta",
          "BridgeSseSessionIdle",
        ]),
      );

      // Active session status is tracked from the notifications.
      final statuses = await plugin.getSessionStatuses();
      expect(statuses["t-1"], isA<PluginSessionStatusIdle>());
    });

    test("keepalive sends periodic model/list RPCs while connected, stops on dispose", () async {
      final kaFake = _FakeAppServer();
      final kaPlugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => kaFake.channel,
        ),
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample",
        keepaliveInterval: const Duration(milliseconds: 20),
      );
      // Only `initialize` is canned; keepalive model/list calls get an error
      // response, which the plugin swallows — exactly the production behaviour.
      kaFake.respondInOrder([const _Response(result: _initOk)]);

      await kaPlugin.healthCheck(); // connect → starts keepalive
      await Future<void>.delayed(const Duration(milliseconds: 90));

      final firedWhileConnected = kaFake.sentMethods.where((m) => m == "model/list").length;
      expect(firedWhileConnected, greaterThanOrEqualTo(2));

      await kaPlugin.dispose();
      final afterDispose = kaFake.sentMethods.where((m) => m == "model/list").length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // No further keepalives once disposed.
      expect(
        kaFake.sentMethods.where((m) => m == "model/list").length,
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
      final rolloutReader = SessionRolloutReader(
        environment: {"CODEX_HOME": codexHome.path},
      );
      final configReader = CodexConfigReader(
        environment: {"CODEX_HOME": codexHome.path},
      );
      final scopedPlugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => scopedFake.channel,
        ),
        rolloutReader: rolloutReader,
        configReader: configReader,
        metadataRepository: CodexMetadataRepository(
          skillReader: CodexSkillReader(
            environment: {"CODEX_HOME": codexHome.path},
          ),
          rolloutReader: rolloutReader,
          configReader: configReader,
          launchDirectory: "/work/sample",
        ),
        projectCwd: "/work/sample",
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

    test("sendPrompt forwards the selected variant as the turn/start effort", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-effort"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-effort",
        parts: const [PluginPromptPart.text(text: "think hard")],
        variant: const PluginSessionVariant(id: "high"),
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start")["effort"], equals("high"));
    });

    test("sendPrompt without a variant sends no effort (codex uses its default)", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-default"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-default",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start").containsKey("effort"), isFalse);
    });

    test("createSession applies the variant on the first turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-new"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "start low")],
        variant: const PluginSessionVariant(id: "low"),
        agent: null,
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentParamsFor("turn/start")["effort"], equals("low"));
    });
  });
}

const Map<String, dynamic> _initOk = {
  "userAgent": "codex-cli/0.121.0",
  "codexHome": "/Users/test/.codex",
  "platformOs": "macos",
  "platformFamily": "unix",
};

class _Response {
  // ignore: unused_element_parameter
  const _Response({this.result, this.error});
  final Object? result;
  final Map<String, dynamic>? error;
}

/// Fake app-server that records every method/params it received and
/// replies in the order [respondInOrder] queued. Lets us push
/// server-originated notifications via [pushNotification].
class _FakeAppServer {
  _FakeAppServer() {
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

  /// Invoked with each request method BEFORE the canned response is sent —
  /// lets a test emit server notifications mid-request (e.g. codex pushing
  /// `thread/name/updated` while `turn/start` is still in flight).
  FutureOr<void> Function(String method)? onRequest;

  List<String> get sentMethods => _sent.map((f) => f.method).toList(growable: false);

  Map<String, dynamic> sentParamsFor(String method) {
    final frame = _sent.firstWhere((f) => f.method == method);
    return frame.params ?? const {};
  }

  List<Map<String, dynamic>> sentParamsForAll(String method) => _sent
      .where((frame) => frame.method == method)
      .map((frame) => frame.params ?? const <String, dynamic>{})
      .toList(growable: false);

  void respondInOrder(List<_Response> responses) {
    _pending
      ..clear()
      ..addAll(responses);
  }

  void pushNotification(String method, Map<String, dynamic> params) {
    _serverToClient.add(
      jsonEncode({"jsonrpc": "2.0", "method": method, "params": params}),
    );
  }

  Future<void> _onClientFrame(Object? frame) async {
    final raw = frame as String;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _sent.add(
      _SentFrame(
        method: decoded["method"] as String,
        params: (decoded["params"] as Map?)?.cast<String, dynamic>(),
      ),
    );
    await onRequest?.call(decoded["method"] as String);
    final id = decoded["id"];
    if (id == null) return; // notification from client (none today)
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
    final envelope = <String, dynamic>{"jsonrpc": "2.0", "id": id};
    if (response.error != null) {
      envelope["error"] = response.error;
    } else {
      envelope["result"] = response.result;
    }
    _serverToClient.add(jsonEncode(envelope));
  }
}

class _SentFrame {
  _SentFrame({required this.method, required this.params});
  final String method;
  final Map<String, dynamic>? params;
}

class _StubChannel implements WebSocketChannel {
  _StubChannel({required this.stream, required this.sink});

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink;

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

class _SinkAdapter implements WebSocketSink {
  _SinkAdapter(this._controller);
  final StreamController<Object?> _controller;

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
