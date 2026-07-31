import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// `getCommands` serves the commands the agent advertised via the
/// `available_commands_update` notification (ACP has no request endpoint for
/// them). Before any update arrives, the list is empty.
void main() {
  group("AcpCommandTracker", () {
    AcpNotification update(Map<String, dynamic> body) => AcpNotification(
      method: "session/update",
      params: {"sessionId": "s1", "update": body},
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
      expect(tracker.hasSnapshot, isTrue);
    });

    test("ignores malformed command snapshots without replacing the last good value", () {
      final emptyTracker = AcpCommandTracker()
        ..consume(
          update({
            "sessionUpdate": "available_commands_update",
            "availableCommands": {"name": "not-a-list"},
          }),
        );
      expect(emptyTracker.commands, isEmpty);
      expect(emptyTracker.hasSnapshot, isFalse);

      final populatedTracker = AcpCommandTracker()
        ..consume(
          update({
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "review"},
            ],
          }),
        )
        ..consume(update({"sessionUpdate": "available_commands_update"}));
      expect(populatedTracker.commands.single.name, "review");
      expect(populatedTracker.hasSnapshot, isTrue);
    });

    test("ignores unrelated notifications", () {
      final tracker = AcpCommandTracker()
        ..consume(const AcpNotification(method: "cursor/update_todos", params: {}))
        ..consume(update({"sessionUpdate": "plan", "entries": <Object?>[]}));
      expect(tracker.commands, isEmpty);
    });
  });

  group("AcpPlugin.getCommands", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    late List<BridgeSseEvent> emitted;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      emitted = <BridgeSseEvent>[];
      final configurationTracker = AcpSessionConfigurationTracker();
      final commandTracker = AcpCommandTracker();
      plugin = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        contentMapper: const AcpContentMapper(),
        eventMapper: AcpEventMapper(
          launchDirectory: cwd,
          agentId: "acp",
          pluginId: "acp",
          configurationTracker: configurationTracker,
          contentMapper: const AcpContentMapper(),
        ),
        commandTracker: commandTracker,
        sessionOptionsService: AcpSessionOptionsService(
          configurationTracker: configurationTracker,
          commandTracker: commandTracker,
          pluginId: "acp",
          agentDisplayName: "ACP",
        ),
        processFactory: (_) async => fake,
      );
      plugin.events.listen(emitted.add);
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
      final discovery = await plugin.getSessionOptions(
        projectId: cwd,
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      final options = (discovery as PluginSessionOptionsDiscoveryObserved).options;
      expect(options.completeness, PluginSessionOptionsCompleteness.complete);
      expect(options.commands.single.name, "create_plan");
      expect(
        emitted.whereType<BridgeSseSessionOptionsChanged>().single.sessionID,
        "s1",
      );
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
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final plugin = AcpPlugin(
      id: "acp",
      agentDisplayName: "ACP",
      launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
      launchDirectory: "/repo",
      contentMapper: const AcpContentMapper(),
      eventMapper: AcpEventMapper(
        launchDirectory: "/repo",
        agentId: "acp",
        pluginId: "acp",
        configurationTracker: configurationTracker,
        contentMapper: const AcpContentMapper(),
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: "acp",
        agentDisplayName: "ACP",
      ),
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
        userVisibleText: null,
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

      final messages = plugin.getSessionMessages("s1");
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
      expect(
        emitted.whereType<BridgeSseSessionOptionsChanged>().single.sessionID,
        "s1",
      );
    } finally {
      await plugin.dispose();
      await live.close();
      await replay.close();
    }
  });
}
