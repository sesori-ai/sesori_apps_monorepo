import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// An agent that advertises `sessionCapabilities.resume` but NOT `loadSession`
/// must have prior-run sessions re-activated via `session/resume` before a
/// turn — otherwise the fresh agent process rejects the `session/prompt` as an
/// unknown session. `session/resume` replays no history, so no replay
/// suppression applies.
void main() {
  group("AcpPlugin resume-only sessions", () {
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
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp"),
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

    List<Map<String, dynamic>> frames(String method) =>
        fake.written.where((f) => f["method"] == method).toList(growable: false);

    // Polls with a small real delay so a dispatch queued behind another
    // serialized-turn step is not out-raced by zero-duration pumps.
    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 400; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote $count '$method' frame(s)");
    }

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      final frame = await waitForFrameCount("initialize", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {
            "loadSession": false,
            "sessionCapabilities": {"resume": <String, dynamic>{}},
          },
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);
    }

    Future<void> sendPrompt(String text) => plugin.sendPrompt(
      sessionId: "old-1",
      parts: [PluginPromptPart.text(text: text)],
      variant: null,
      agent: null,
      model: null,
    );

    test("a prior-run session is resumed (not loaded) before the prompt, unsuppressed", () async {
      await connect();

      final sending = sendPrompt("hi");
      final resumeFrame = await waitForFrameCount("session/resume", 1);
      final params = (resumeFrame["params"] as Map).cast<String, dynamic>();
      expect(params["sessionId"], "old-1");
      expect(params["cwd"], cwd);

      // A live update arriving during the resume is NOT replay — session/resume
      // returns no history — so it must reach the live stream.
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "old-1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "live"},
          },
        },
      });
      await pump();
      fake.emit({"jsonrpc": "2.0", "id": resumeFrame["id"], "result": const <String, dynamic>{}});
      await sending;

      expect(frames("session/load"), isEmpty, reason: "loadSession is not advertised");
      expect(
        emitted.whereType<BridgeSseMessagePartDelta>(),
        isNotEmpty,
        reason: "resume replays nothing, so mid-resume updates are live",
      );

      final promptFrame = await waitForFrameCount("session/prompt", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": promptFrame["id"],
        "result": {"stopReason": "end_turn"},
      });
      await pump();

      // The now-resident session is not re-resumed on the next turn.
      final again = sendPrompt("again");
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      fake.emit({
        "jsonrpc": "2.0",
        "id": secondPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await again;
      expect(frames("session/resume"), hasLength(1));
    });

    test("a transiently failed resume is retried on the next turn", () async {
      await connect();

      final sending = sendPrompt("hi");
      final firstResume = await waitForFrameCount("session/resume", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstResume["id"],
        "error": {"code": -32000, "message": "transient"},
      });
      await sending;
      final firstPrompt = await waitForFrameCount("session/prompt", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await pump();

      final again = sendPrompt("again");
      final secondResume = await waitForFrameCount("session/resume", 2);
      fake.emit({"jsonrpc": "2.0", "id": secondResume["id"], "result": const <String, dynamic>{}});
      await again;
      expect(frames("session/resume"), hasLength(2));
    });

    test("an unsupported resume (-32601) is memoized", () async {
      await connect();

      final sending = sendPrompt("hi");
      final firstResume = await waitForFrameCount("session/resume", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstResume["id"],
        "error": {"code": -32601, "message": "method not found"},
      });
      await sending;
      final firstPrompt = await waitForFrameCount("session/prompt", 1);
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await pump();

      final again = sendPrompt("again");
      await waitForFrameCount("session/prompt", 2);
      await again;
      expect(frames("session/resume"), hasLength(1));
    });
  });
}
