import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Exercises [AcpPlugin.getActiveSessionsSummary] — the activity feed the
/// mobile app renders as the per-project "running"/"needs you" badge. The
/// stub used to return `const []`, so Cursor sessions never appeared.
void main() {
  group("AcpPlugin.getActiveSessionsSummary", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    late List<BridgeSseEvent> emitted;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      emitted = [];
      plugin = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp", pluginId: "acp"),
        commandTracker: AcpCommandTracker(),
        processFactory: (_) async => fake,
      );
      plugin.events.listen(emitted.add);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    // Polls written frames until one with [method] appears (the handshake is
    // several awaits deep, so a single pump can race the first frame).
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where((f) => f["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      final frame = await waitForFrame(method);
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await pump();
    }

    Future<String> connectAndCreateSession() async {
      final connecting = plugin.ensureConnected();
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: cwd,
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", {"sessionId": "s1"});
      final session = await creating;
      return session.id;
    }

    test("idle session is not surfaced; a running turn is, then clears", () async {
      final sessionId = await connectAndCreateSession();
      expect(sessionId, "s1");

      // Created but idle -> no activity row.
      expect(plugin.getActiveSessionsSummary(), isEmpty);

      // Dispatch a prompt and withhold the session/prompt response so the turn
      // stays in flight (ACP has no turn-complete event: busy == future pending).
      await plugin.sendPrompt(
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );
      await waitForFrame("session/prompt");

      final running = plugin.getActiveSessionsSummary();
      expect(running, hasLength(1));
      expect(running.single.id, cwd, reason: "the single synthesized project");
      final active = running.single.activeSessions.single;
      expect(active.id, sessionId);
      expect(active.mainAgentRunning, isTrue);
      expect(active.awaitingInput, isFalse);
      expect(active.isRetrying, isFalse);
      expect(active.childSessionIds, isEmpty, reason: "ACP sessions are flat");
      expect(emitted.whereType<BridgeSseProjectUpdated>(), hasLength(1));

      // Resolve the turn -> session goes idle -> summary clears.
      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(emitted.whereType<BridgeSseProjectUpdated>(), hasLength(2));
    });

    test("a session awaiting a permission is surfaced with awaitingInput", () async {
      final sessionId = await connectAndCreateSession();
      expect(plugin.getActiveSessionsSummary(), isEmpty);

      // A permission ask arrives for the session (the agent is blocked on the
      // user). The base registry tracks it as pending input.
      fake.emit({
        "jsonrpc": "2.0",
        "id": 99,
        "method": "session/request_permission",
        "params": {
          "sessionId": sessionId,
          "toolCall": {"toolCallId": "tc-1", "title": "Run", "kind": "execute"},
          "options": [
            {"optionId": "opt-allow-once", "name": "Allow", "kind": "allow_once"},
          ],
        },
      });
      await pump();

      final summary = plugin.getActiveSessionsSummary();
      expect(summary, hasLength(1));
      final active = summary.single.activeSessions.single;
      expect(active.id, sessionId);
      expect(active.awaitingInput, isTrue);
      expect(active.mainAgentRunning, isFalse, reason: "no prompt turn in flight");
      expect(emitted.whereType<BridgeSseProjectUpdated>(), hasLength(1));

      final requestId = emitted.whereType<BridgeSsePermissionAsked>().single.requestID;
      await plugin.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: PluginPermissionReply.once,
      );
      await pump();
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(emitted.whereType<BridgeSseProjectUpdated>(), hasLength(2));
    });
  });
}
