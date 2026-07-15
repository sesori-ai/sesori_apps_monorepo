import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// `getSessionMessages` replays a stored thread via a short-lived `session/load`
/// client. cursor-agent rejects that load for some stored sessions with
/// method-not-found / invalid-params (a session created by a prior agent
/// process, or whose worktree was moved/removed). That is not a transport
/// failure, so the read path must degrade to a usable (possibly empty) thread —
/// mirroring the resume path — instead of 502ing the whole session-detail view.
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

    test("session/load rejected with -32602 degrades to a usable thread, not a 502", () async {
      final loading = plugin.getSessionMessages(sessionId);
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      expect((loadFrame["params"] as Map)["sessionId"], sessionId);
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32602, "message": "Invalid params"},
      });

      // The session stays openable: an empty (but usable) thread, not a throw.
      expect(await loading, isEmpty);
    });

    test("session/load rejected with -32601 also degrades to a usable thread", () async {
      final loading = plugin.getSessionMessages(sessionId);
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32601, "message": "Method not found"},
      });

      expect(await loading, isEmpty);
    });

    test("partial history replayed before a -32602 rejection is preserved", () async {
      final loading = plugin.getSessionMessages(sessionId);
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

      final messages = await loading;
      expect(messages, isNotEmpty, reason: "history collected before the rejection must survive");
      final text = messages
          .expand((m) => m.parts)
          .where((p) => p.type == PluginMessagePartType.text)
          .map((p) => p.text)
          .join();
      expect(text, contains("partial reply"));
    });

    test("a genuine RPC error (not -32601/-32602) still surfaces as a typed failure", () async {
      final loading = plugin.getSessionMessages(sessionId);
      await completeReplayHandshake();

      final loadFrame = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "error": {"code": -32000, "message": "Server error"},
      });

      await expectLater(loading, throwsA(isA<PluginOperationException>()));
    });
  });
}
