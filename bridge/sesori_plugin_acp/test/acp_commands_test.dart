import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// `getCommands` serves the commands the agent advertised via the
/// `available_commands_update` notification (ACP has no request endpoint for
/// them). Before any update arrives, the list is empty.
void main() {
  group("AcpCommandTracker", () {
    AcpNotificationRecord update(Map<String, dynamic> body) => mapAcpNotificationForTest(
      AcpNotification(
        method: "session/update",
        params: {"sessionId": "s1", "update": body},
      ),
    );

    test("parses advertised commands fail-soft; last update wins", () {
      final tracker = AcpCommandTracker()
        ..consume(
          update({
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {
                "name": "create_plan",
                "description": "Plan before coding",
                "input": {"hint": "what to plan"},
              },
              {"name": "compress", "description": "Compact the thread"},
              {"description": "malformed: no name"},
              "not-a-map",
            ],
          }),
        );

      final commands = tracker.commands;
      expect(commands, hasLength(2));
      expect(commands[0].name, "create_plan");
      expect(commands[0].description, "Plan before coding");
      expect(commands[0].hints, ["what to plan"]);
      expect(commands[0].source, PluginCommandSource.command);
      expect(commands[1].name, "compress");
      expect(commands[1].hints, isEmpty);

      tracker.consume(
        update({
          "sessionUpdate": "available_commands_update",
          "availableCommands": const <Object?>[],
        }),
      );
      expect(tracker.commands, isEmpty);
    });

    test("ignores unrelated notifications", () {
      final tracker = AcpCommandTracker()
        ..consume(
          mapAcpNotificationForTest(
            const AcpNotification(method: "cursor/update_todos", params: {}),
          ),
        )
        ..consume(update({"sessionUpdate": "plan", "entries": <Object?>[]}));
      expect(tracker.commands, isEmpty);
    });
  });

  group("AcpPlugin.getCommands", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      plugin = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp", pluginId: "acp"),
        processFactory: (_) async => fake,
      );
      plugin.events.listen((_) {});
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 80; i++) {
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    test("serves the agent's advertised slash commands", () async {
      final connecting = plugin.ensureConnected();
      final init = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": init["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);

      expect(await plugin.getCommands(projectId: cwd), isEmpty);

      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {
                "name": "create_plan",
                "description": "Plan before coding",
                "input": {"hint": "what to plan"},
              },
            ],
          },
        },
      });
      await pump();

      final commands = await plugin.getCommands(projectId: cwd);
      expect(commands, hasLength(1));
      expect(commands.single.name, "create_plan");
      expect(commands.single.description, "Plan before coding");
      expect(commands.single.hints, ["what to plan"]);
    });

    test("attaches notification and approval listeners before initialize completes", () async {
      final connecting = plugin.ensureConnected();
      final init = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "early_command"},
            ],
          },
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": 91,
        "method": "session/request_permission",
        "params": {
          "sessionId": "s1",
          "toolCall": {"kind": "execute"},
          "options": [
            {"optionId": "allow", "kind": "allow_once"},
          ],
        },
      });
      await pump();
      await pump();

      expect(await plugin.getCommands(projectId: cwd), hasLength(1));
      expect(await plugin.getPendingPermissions(sessionId: "s1"), hasLength(1));

      fake.emit({
        "jsonrpc": "2.0",
        "id": init["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);
    });

    test("clears commands when the ACP process connection resets", () async {
      final connecting = plugin.ensureConnected();
      final init = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": init["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);

      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "old_process_command"},
            ],
          },
        },
      });
      await pump();
      expect(await plugin.getCommands(projectId: cwd), hasLength(1));

      await plugin.resetConnectionAfterExit();

      expect(await plugin.getCommands(projectId: cwd), isEmpty);
    });
  });

  test("history replay advertises commands and emits a session refresh", () async {
    final live = FakeAcpProcess();
    final replay = FakeAcpProcess();
    final processes = [live, replay];
    final emitted = <BridgeSseEvent>[];
    final plugin = AcpPlugin(
      id: "acp",
      agentDisplayName: "ACP",
      launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
      launchDirectory: "/repo",
      eventMapper: AcpEventMapper(launchDirectory: "/repo", agentId: "acp", pluginId: "acp"),
      processFactory: (_) async => processes.removeAt(0),
    );
    plugin.events.listen(emitted.add);

    Future<Map<String, dynamic>> waitForFrame(FakeAcpProcess process, String method) async {
      for (var i = 0; i < 100; i++) {
        final matches = process.written.where((frame) => frame["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await Future<void>.delayed(Duration.zero);
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    try {
      final connecting = plugin.ensureConnected();
      final liveInit = await waitForFrame(live, "initialize");
      live.emit({
        "jsonrpc": "2.0",
        "id": liveInit["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {"loadSession": true},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo/worktree",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      final sessionNew = await waitForFrame(live, "session/new");
      live.emit({
        "jsonrpc": "2.0",
        "id": sessionNew["id"],
        "result": {"sessionId": "s1"},
      });
      await creating;

      final messages = plugin.getSessionMessages(
        "s1",
        acceptedCommands: const [],
      );
      final replayInit = await waitForFrame(replay, "initialize");
      replay.emit({
        "jsonrpc": "2.0",
        "id": replayInit["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {"loadSession": true},
          "authMethods": <Object?>[],
        },
      });
      final load = await waitForFrame(replay, "session/load");
      replay.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "stale_replay_command"},
            ],
          },
        },
      });
      replay.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "s1",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "from_replay"},
            ],
          },
        },
      });
      replay.emit({"jsonrpc": "2.0", "id": load["id"], "result": const <String, dynamic>{}});
      await messages;

      expect((await plugin.getCommands(projectId: "/repo")).single.name, "from_replay");
      expect(
        emitted.whereType<BridgeSseSessionsUpdated>().single.sessionID,
        "s1",
      );
    } finally {
      await plugin.dispose();
      await live.close();
      await replay.close();
    }
  });

  test("accepted command echo folds assistant result and preserves invocation", () {
    const userId = "s1-h0-user";
    const resultId = "s1-h1-assistant";
    final mapped = const AcpMessageRepository().mapHistory(
      sessionId: "s1",
      agentId: "ACP",
      modelId: null,
      providerId: null,
      records: const [
        AcpReplayMessage(
          id: userId,
          role: AcpReplayRole.user,
          text: "/create_plan auth",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: resultId,
          role: AcpReplayRole.assistant,
          text: "the plan",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
      ],
      acceptedCommands: const [
        PluginCommandInvocationContext(
          invocationId: "opaque-acp-invocation",
          name: "create_plan",
          arguments: "auth",
          acceptedAt: 100,
          backendMessageId: null,
        ),
      ],
      knownCommandNames: const {"create_plan"},
    );

    expect(mapped, hasLength(1));
    expect(
      mapped.single.info,
      isA<PluginMessageCommand>()
          .having(
            (message) => message.id,
            "id",
            "s1-command-opaque-acp-invocation",
          )
          .having((message) => message.invocationId, "invocationId", "opaque-acp-invocation")
          .having((message) => message.origin, "origin", PluginCommandOrigin.manual),
    );
    expect(mapped.single.parts.single.id, "s1-command-opaque-acp-invocation-result");
    expect(mapped.single.parts.single.messageID, "s1-command-opaque-acp-invocation");
    expect(mapped.single.parts.single.text, "the plan");
  });

  test("duplicate command history pairs newest accepted contexts to newest echoes", () {
    final mapped = const AcpMessageRepository().mapHistory(
      sessionId: "s1",
      agentId: "ACP",
      modelId: null,
      providerId: null,
      records: const [
        AcpReplayMessage(
          id: "user-1",
          role: AcpReplayRole.user,
          text: "/review same",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "assistant-1",
          role: AcpReplayRole.assistant,
          text: "first result",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "user-2",
          role: AcpReplayRole.user,
          text: "/review same",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "assistant-2",
          role: AcpReplayRole.assistant,
          text: "second result",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "user-3",
          role: AcpReplayRole.user,
          text: "/review same",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "assistant-3",
          role: AcpReplayRole.assistant,
          text: "third result",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
      ],
      acceptedCommands: const [
        PluginCommandInvocationContext(
          invocationId: "newest-invocation",
          name: "review",
          arguments: "same",
          acceptedAt: 200,
          backendMessageId: null,
        ),
        PluginCommandInvocationContext(
          invocationId: "older-invocation",
          name: "review",
          arguments: "same",
          acceptedAt: 100,
          backendMessageId: null,
        ),
      ],
      knownCommandNames: const {"review"},
    );

    expect(mapped, hasLength(3));
    expect(
      mapped.map((message) => (message.info as PluginMessageCommand).invocationId),
      [null, "older-invocation", "newest-invocation"],
    );
    expect(
      mapped.map((message) => message.parts.single.text),
      ["first result", "second result", "third result"],
    );
  });

  test("recognized external slash history has manual origin", () {
    final mapped = const AcpMessageRepository().mapHistory(
      sessionId: "s1",
      agentId: "ACP",
      modelId: null,
      providerId: null,
      records: const [
        AcpReplayMessage(
          id: "external-command",
          role: AcpReplayRole.user,
          text: "/create_plan auth",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
      ],
      acceptedCommands: const [],
      knownCommandNames: const {"/create_plan"},
    );

    expect(
      mapped.single.info,
      isA<PluginMessageCommand>()
          .having((message) => message.origin, "origin", PluginCommandOrigin.manual)
          .having((message) => message.invocationId, "invocationId", isNull),
    );
  });

  test("accepted live command and history replay have equivalent shape", () async {
    final commandTurnTracker = AcpCommandTurnTracker();
    final mapper = AcpEventMapper(
      launchDirectory: "/repo",
      agentId: "ACP",
      pluginId: "acp",
    );
    final dispatcher = AcpTurnEventDispatcher(
      eventMapper: mapper,
      commandTracker: AcpCommandTracker(),
      commandTurnTracker: commandTurnTracker,
      residencyTracker: AcpSessionResidencyTracker(),
    );
    final liveEvents = <BridgeSseEvent>[];
    final subscription = dispatcher.events.listen(liveEvents.add);
    final registration = commandTurnTracker.register(
      sessionId: "s1",
      invocationId: "equivalent-invocation",
      name: "review",
      arguments: "args",
    );
    dispatcher.beginTurn(sessionId: "s1");
    dispatcher.stageCommandEnvelope(turnId: registration.turnId);
    dispatcher.flushCommand(registration.turnId);

    AcpNotificationRecord notification(Map<String, dynamic> update) => mapAcpNotificationForTest(
      AcpNotification(
        method: AcpMethods.sessionUpdate,
        params: {"sessionId": "s1", "update": update},
      ),
    );

    final updates = [
      {
        "sessionUpdate": "agent_thought_chunk",
        "messageId": "m1",
        "content": {"type": "text", "text": "thinking"},
      },
      {
        "sessionUpdate": "agent_message_chunk",
        "messageId": "m1",
        "content": {"type": "text", "text": "first"},
      },
      {
        "sessionUpdate": "tool_call",
        "toolCallId": "tool-1",
        "kind": "read",
        "status": "completed",
        "rawOutput": {"stdout": "done"},
      },
      {
        "sessionUpdate": "agent_message_chunk",
        "messageId": "m2",
        "content": {"type": "text", "text": " second"},
      },
    ];
    for (final update in updates) {
      dispatcher.consume(notification(update));
    }
    await Future<void>.delayed(Duration.zero);
    commandTurnTracker.complete(registration.turnId);
    await subscription.cancel();
    await dispatcher.dispose();

    Map<String, dynamic>? liveInfo;
    final liveParts = <String, PluginMessagePart>{};
    for (final event in liveEvents) {
      switch (event) {
        case BridgeSseMessageUpdated(:final info):
          liveInfo = info;
        case BridgeSseMessagePartUpdated(:final part):
          liveParts[part.id] = part;
        case BridgeSseMessagePartDelta(:final partID, :final delta):
          final part = liveParts[partID]!;
          liveParts[partID] = part.copyWith(text: "${part.text ?? ""}$delta");
        case BridgeSseMessagePartRemoved(:final partID):
          liveParts.remove(partID);
        default:
          break;
      }
    }

    final history = const AcpMessageRepository().mapHistory(
      sessionId: "s1",
      agentId: "ACP",
      modelId: null,
      providerId: null,
      records: const [
        AcpReplayMessage(
          id: "s1-muser-user",
          role: AcpReplayRole.user,
          text: "/review args",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "s1-mm1-assistant",
          role: AcpReplayRole.assistant,
          text: "first",
          reasoning: "thinking",
          tools: [
            AcpReplayTool(
              id: "tool-1",
              name: "read",
              title: null,
              status: PluginToolStatus.completed,
              output: "done",
            ),
          ],
          errorName: null,
          errorMessage: null,
        ),
        AcpReplayMessage(
          id: "s1-mm2-assistant",
          role: AcpReplayRole.assistant,
          text: " second",
          reasoning: "",
          tools: [],
          errorName: null,
          errorMessage: null,
        ),
      ],
      acceptedCommands: const [
        PluginCommandInvocationContext(
          invocationId: "equivalent-invocation",
          name: "review",
          arguments: "args",
          acceptedAt: 1,
          backendMessageId: null,
        ),
      ],
      knownCommandNames: const {"review"},
    );

    expect(
      {
        "info": liveInfo,
        "parts": liveParts.values.map((part) => part.toJson()).toList(),
      },
      history.single.toJson(),
    );
  });
}
