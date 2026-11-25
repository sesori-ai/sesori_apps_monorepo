import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// `compactSession` sends the harness's native compaction command only to a
/// quiet session whose live command list advertises it, and never cancels a
/// running turn the way `sendCommand` does.
void main() {
  group("AcpPlugin.compactSession", () {
    late FakeAcpProcess fake;
    late AcpPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      plugin = composeTestAcpPlugin(processFactory: (_) async => fake, launchDirectory: cwd);
      plugin.events.listen((_) {});
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    List<Map<String, dynamic>> frames(String method) =>
        fake.written.where((f) => f["method"] == method).toList(growable: false);

    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 400; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote $count '$method' frame(s)");
    }

    void respondTo(Map<String, dynamic> frame, Map<String, dynamic> result) {
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<String> connectWithSession({required List<String> commands}) async {
      final connecting = plugin.ensureConnected();
      respondTo(await waitForFrameCount("initialize", 1), {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": false},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
      final creating = plugin.createSession(
        origin: PluginPromptOrigin.user,
        fastMode: false,
        directory: cwd,
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      respondTo(await waitForFrameCount("session/new", 1), {"sessionId": "s1"});
      final session = await creating;
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": session.id,
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              for (final name in commands) {"name": name},
            ],
          },
        },
      });
      await Future<void>.delayed(Duration.zero);
      return session.id;
    }

    Future<PluginCompactionResult> compact(String sessionId) =>
        plugin.compactSession(sessionId: sessionId, promptId: "compact-1");

    test("an idle session that advertises compact gets the command", () async {
      final sessionId = await connectWithSession(commands: ["review", "compact"]);

      expect(await compact(sessionId), PluginCompactionResult.accepted);

      final prompt = await waitForFrameCount("session/prompt", 1);
      expect(prompt.toString(), contains("/compact"));
      expect(frames("session/cancel"), isEmpty);
      respondTo(prompt, {"stopReason": "end_turn"});
    });

    test("a live command list without compact is unsupported and sends nothing", () async {
      final sessionId = await connectWithSession(commands: ["review"]);

      expect(await compact(sessionId), PluginCompactionResult.unsupported);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(frames("session/prompt"), isEmpty);
    });

    test("after a restart it loads the session to learn the commands before deciding", () async {
      final connecting = plugin.ensureConnected();
      respondTo(await waitForFrameCount("initialize", 1), {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": true},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
      plugin.primeSessionDirectory(sessionId: "prior", directory: cwd);

      final compacting = compact("prior");
      final load = await waitForFrameCount("session/load", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "prior",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "compact"},
            ],
          },
        },
      });
      respondTo(load, <String, dynamic>{});

      expect(await compacting, PluginCompactionResult.accepted);
      final prompt = await waitForFrameCount("session/prompt", 1);
      expect(prompt.toString(), contains("/compact"));
      expect(frames("session/load"), hasLength(1));
      respondTo(prompt, {"stopReason": "end_turn"});
    });

    test("a running turn is busy: nothing is queued and the turn is not cancelled", () async {
      final sessionId = await connectWithSession(commands: ["compact"]);
      await plugin.sendPrompt(
        origin: PluginPromptOrigin.user,
        fastMode: false,
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "work")],
        variant: null,
        agent: null,
        model: null,
      );
      final running = await waitForFrameCount("session/prompt", 1);

      expect(await compact(sessionId), PluginCompactionResult.sessionBusy);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(frames("session/cancel"), isEmpty);
      expect(await plugin.getQueuedPrompts(sessionId: sessionId), isEmpty);
      respondTo(running, {"stopReason": "end_turn"});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(frames("session/prompt"), hasLength(1));
    });
  });
}
