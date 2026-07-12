import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// A turn on a session not created this run must first re-load it (ACP agents
/// hold sessions per-process, so a prior-run session is otherwise rejected with
/// "session not found"). The resume `session/load` precedes the `session/prompt`
/// and its history replay is suppressed from the live stream.
void main() {
  group("AcpPlugin resume-on-demand", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    final emitted = <BridgeSseEvent>[];
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
      emitted.clear();
      plugin.events.listen(emitted.add);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    // Polls with a small real delay: a serialized turn's dispatch can sit
    // behind the resume-load replay drain (~250ms of wall-clock quiet time),
    // which zero-duration pumps never outlast.
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 400; i++) {
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    test("a prior-run session is loaded before the prompt, replay suppressed", () async {
      final connecting = plugin.ensureConnected();
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": true},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      // Prompt a session this process never created.
      final sending = plugin.sendPrompt(
        sessionId: "old-session",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );

      // The resume-load goes out first; while it is in flight, simulate the
      // agent replaying old history — it must NOT reach the live stream.
      final loadFrame = await waitForFrame("session/load");
      expect((loadFrame["params"] as Map)["sessionId"], "old-session");
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "old-session",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "OLD HISTORY"},
          },
        },
      });
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "old-session",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": const <Object?>[],
          },
        },
      });
      await pump();
      fake.emit({"jsonrpc": "2.0", "id": loadFrame["id"], "result": const <String, dynamic>{}});

      // sendPrompt resolves once the turn is accepted (queued); the dispatch
      // itself runs on the session's serialization chain, so wait for the
      // prompt frame before asserting on the frame order.
      await sending;
      await waitForFrame("session/prompt");

      // session/load was sent before session/prompt.
      final methods = fake.written.map((f) => f["method"]).toList();
      expect(
        methods.indexOf("session/load") < methods.indexOf("session/prompt"),
        isTrue,
        reason: "resume-load must precede the prompt",
      );

      // The suppressed replay produced no message events on the live stream.
      expect(emitted.whereType<BridgeSseMessagePartDelta>(), isEmpty);
      // Command metadata is current even during a history replay, so the
      // client receives the stale-session signal and re-fetches it.
      expect(emitted.whereType<BridgeSseSessionsUpdated>(), hasLength(1));

      // Complete the first turn so the follow-up prompt dispatches (turns on
      // one session are serialized).
      await respond("session/prompt", {"stopReason": "end_turn"});

      // A second prompt on the now-resident session does NOT re-load.
      final loadsBefore = fake.written.where((f) => f["method"] == "session/load").length;
      final again = plugin.sendPrompt(
        sessionId: "old-session",
        parts: const [PluginPromptPart.text(text: "again")],
        variant: null,
        agent: null,
        model: null,
      );
      await again;
      final loadsAfter = fake.written.where((f) => f["method"] == "session/load").length;
      expect(loadsAfter, loadsBefore, reason: "resident session is not re-loaded");
    });
  });
}
