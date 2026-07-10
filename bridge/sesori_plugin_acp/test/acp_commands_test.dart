import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

/// `getCommands` serves the commands the agent advertised via the
/// `available_commands_update` notification (ACP has no request endpoint for
/// them). Before any update arrives, the list is empty.
void main() {
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
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp"),
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
  });
}
