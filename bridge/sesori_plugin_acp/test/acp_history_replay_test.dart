import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// `getSessionMessages` replays a stored thread via a short-lived `session/load`
/// client. Only a conclusive lack of method/capability is an empty history;
/// invalid parameters and other operation failures remain observable.
void main() {
  group("AcpPlugin history replay", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    const cwd = "/repo";
    const sessionId = "prior-run-session";

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
      // Prime the session's directory so the replay skips the live warm-up
      // enumeration and the only client it spins up is the replay client.
      plugin.primeSessionDirectory(sessionId: sessionId, directory: cwd);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 400; i++) {
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> completeReplayHandshake() async {
      final initFrame = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initFrame["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {"loadSession": true},
          "authMethods": <Object?>[],
        },
      });
      await pump();
    }

    test("session/load rejected with -32602 surfaces as an operation failure", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      expect((loadFrame["params"] as Map)["sessionId"], sessionId);
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32602, "message": "Invalid params"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });

    test("session/load rejected with -32601 also degrades to a usable thread", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32601, "message": "Method not found"},
      });

      expect(await loading, isEmpty);
    });

    test("partial replay before a -32602 rejection does not hide the failure", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      // Some history streamed in before the agent rejected the load.
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "partial reply"},
          },
        },
      });
      await pump();
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32602, "message": "Invalid params"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });

    test("a command snapshot replayed before a -32602 rejection still triggers a refresh", () async {
      final emitted = <BridgeSseEvent>[];
      plugin.events.listen(emitted.add);
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      // The agent replayed a command snapshot before rejecting the load. The
      // process-global command tracker consumed it, so consumers must still be
      // nudged to re-fetch commands on the degraded path.
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "from_replay"},
            ],
          },
        },
      });
      await pump();
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32602, "message": "Invalid params"},
      });
      await expectLater(loading, throwsA(isA<PluginOperationException>()));
      await pump();

      expect(emitted.whereType<BridgeSseSessionsUpdated>(), isNotEmpty);
    });

    test("a genuine RPC error (not -32601/-32602) still surfaces as a typed failure", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32000, "message": "Server error"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });

    // The degrade is scoped to the `session/load` request alone: a rejected
    // handshake means the replay client is broken (not "this stored session is
    // unloadable"), and the getSessionMessages contract requires auth/transport
    // failures to surface typed, never as an empty thread.

    test("a -32602 rejection of `initialize` surfaces as a typed failure, not an empty thread", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );

      final initFrame = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initFrame["id"],
        "error": {"code": -32602, "message": "Invalid params"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });

    test("a -32601 rejection of `authenticate` surfaces as a typed failure, not an empty thread", () async {
      final loading = plugin.getSessionMessages(
        sessionId,
        acceptedCommands: const [],
      );

      final initFrame = await waitForFrame("initialize");
      // The agent advertises an auth method, so the replay client must
      // authenticate before loading — reject that instead of the load.
      fake.emit({
        "jsonrpc": "2.0",
        "id": initFrame["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {"loadSession": true},
          "authMethods": [
            {"id": "agent_login", "name": "Agent login"},
          ],
        },
      });
      final authFrame = await waitForFrame("authenticate");
      fake.emit({
        "jsonrpc": "2.0",
        "id": authFrame["id"],
        "error": {"code": -32601, "message": "Method not found"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });
  });
}
