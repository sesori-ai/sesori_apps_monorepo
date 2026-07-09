import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Turn-lifecycle robustness:
///
///  - prompts on one session are serialized (agents reject or drop overlapping
///    `session/prompt` requests), and the session stays busy until its LAST
///    queued turn settles;
///  - an abort drops queued-but-undispatched turns;
///  - a transiently failed resume `session/load` is retried on the next turn,
///    while a permanently unsupported one is memoized (no load loop);
///  - concurrent prompts coalesce onto a single resume-load whose replay
///    suppression covers the whole load;
///  - sessionId-less server requests attribute precisely when exactly one
///    turn is in flight.
void main() {
  group("AcpPlugin turn serialization", () {
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

    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 80; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await pump();
      }
      throw StateError("agent never wrote $count '$method' frame(s)");
    }

    Future<Map<String, dynamic>> waitForFrame(String method) =>
        waitForFrameCount(method, 1);

    void respondTo(Map<String, dynamic> frame, Map<String, dynamic> result) {
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<void> connect({bool loadSession = false}) async {
      final connecting = plugin.ensureConnected();
      final frame = await waitForFrame("initialize");
      respondTo(frame, {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": loadSession},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
    }

    Future<String> createSession(String directory, String sessionId) async {
      final creating = plugin.createSession(
        directory: directory,
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      final newFrames = frames("session/new").length;
      final frame = await waitForFrameCount("session/new", newFrames + 1);
      respondTo(frame, {"sessionId": sessionId});
      final session = await creating;
      return session.id;
    }

    Future<void> sendPrompt(String sessionId, String text) => plugin.sendPrompt(
      sessionId: sessionId,
      parts: [PluginPromptPart.text(text: text)],
      variant: null,
      agent: null,
      model: null,
    );

    int busyCount() => emitted.whereType<BridgeSseSessionStatus>().length;
    int idleCount() => emitted.whereType<BridgeSseSessionIdle>().length;

    test("a second prompt on one session dispatches only after the first turn completes", () async {
      await connect();
      final sessionId = await createSession(cwd, "s1");

      await sendPrompt(sessionId, "first");
      final firstPrompt = await waitForFrame("session/prompt");
      expect(busyCount(), 1);

      await sendPrompt(sessionId, "second");
      for (var i = 0; i < 10; i++) {
        await pump();
      }
      expect(
        frames("session/prompt"),
        hasLength(1),
        reason: "the second prompt must wait for the first turn to complete",
      );
      expect(busyCount(), 1, reason: "queued turn keeps the one busy signal");
      expect(idleCount(), 0);

      respondTo(firstPrompt, {"stopReason": "end_turn"});
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      expect((secondPrompt["params"] as Map)["sessionId"], sessionId);
      await pump();
      expect(
        idleCount(),
        0,
        reason: "the session is still busy while the queued turn runs",
      );
      expect(
        plugin.getActiveSessionsSummary().single.activeSessions.single.mainAgentRunning,
        isTrue,
      );

      respondTo(secondPrompt, {"stopReason": "end_turn"});
      await pump();
      await pump();
      expect(idleCount(), 1, reason: "idle only after the last queued turn settles");
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("abort drops queued-but-undispatched turns", () async {
      await connect();
      final sessionId = await createSession(cwd, "s1");

      await sendPrompt(sessionId, "first");
      final firstPrompt = await waitForFrame("session/prompt");
      await sendPrompt(sessionId, "queued");

      await plugin.abortSession(sessionId: sessionId);
      expect(frames("session/cancel"), hasLength(1));

      // The agent honours the cancel by ending the in-flight turn.
      respondTo(firstPrompt, {"stopReason": "cancelled"});
      for (var i = 0; i < 10; i++) {
        await pump();
      }

      expect(
        frames("session/prompt"),
        hasLength(1),
        reason: "the queued turn must not dispatch after an abort",
      );
      expect(idleCount(), 1, reason: "queue accounting settles to idle");
      expect(emitted.whereType<BridgeSseSessionError>(), isEmpty);
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("a transiently failed resume-load is retried on the next turn", () async {
      await connect(loadSession: true);

      final sendingFirst = sendPrompt("old-1", "hi");
      final firstLoad = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstLoad["id"],
        "error": {"code": -32000, "message": "transient agent hiccup"},
      });
      await sendingFirst;
      // The turn still proceeds and surfaces its own outcome.
      final firstPrompt = await waitForFrame("session/prompt");
      respondTo(firstPrompt, {"stopReason": "end_turn"});
      await pump();

      final sendingSecond = sendPrompt("old-1", "again");
      final secondLoad = await waitForFrameCount("session/load", 2);
      respondTo(secondLoad, const {});
      await sendingSecond;
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      respondTo(secondPrompt, {"stopReason": "end_turn"});

      expect(
        frames("session/load"),
        hasLength(2),
        reason: "a transient load failure must not cache the session as resident",
      );
    });

    test("an unsupported resume-load is memoized and not re-attempted", () async {
      await connect(loadSession: true);

      final sendingFirst = sendPrompt("old-1", "hi");
      final firstLoad = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstLoad["id"],
        "error": {"code": -32601, "message": "method not found"},
      });
      await sendingFirst;
      final firstPrompt = await waitForFrame("session/prompt");
      respondTo(firstPrompt, {"stopReason": "end_turn"});
      await pump();

      final sendingSecond = sendPrompt("old-1", "again");
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      respondTo(secondPrompt, {"stopReason": "end_turn"});
      await sendingSecond;

      expect(
        frames("session/load"),
        hasLength(1),
        reason: "an unsupported load is memoized so turns don't loop on it",
      );
    });

    test("concurrent prompts coalesce onto one resume-load with one suppression window", () async {
      await connect(loadSession: true);

      final sendingA = sendPrompt("old-1", "a");
      final sendingB = sendPrompt("old-1", "b");

      final loadFrame = await waitForFrame("session/load");
      // Replay streamed by the in-flight load must never reach the live stream,
      // even while a second caller shares the load.
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
          "sessionId": "old-1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "OLD HISTORY"},
          },
        },
      });
      await pump();
      respondTo(loadFrame, const {});
      await Future.wait([sendingA, sendingB]);

      expect(
        frames("session/load"),
        hasLength(1),
        reason: "concurrent callers must share a single resume-load",
      );
      expect(emitted.whereType<BridgeSseMessagePartDelta>(), isEmpty);

      // Both prompts dispatch, serialized.
      final firstPrompt = await waitForFrame("session/prompt");
      expect(frames("session/prompt"), hasLength(1));
      respondTo(firstPrompt, {"stopReason": "end_turn"});
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      respondTo(secondPrompt, {"stopReason": "end_turn"});
    });

    test("sessionId-less server requests attribute to the unambiguous in-flight turn", () async {
      await connect();
      final s1 = await createSession(cwd, "s1");
      final s2 = await createSession("/other", "s2");

      Future<Map<String, dynamic>> promptFrameFor(String sessionId) async {
        for (var i = 0; i < 80; i++) {
          final match = frames("session/prompt")
              .where((f) => (f["params"] as Map)["sessionId"] == sessionId);
          if (match.isNotEmpty) return match.last;
          await pump();
        }
        throw StateError("no session/prompt frame for $sessionId");
      }

      void emitBarePermission(int id) {
        fake.emit({
          "jsonrpc": "2.0",
          "id": id,
          "method": "session/request_permission",
          "params": {
            "toolCall": {"toolCallId": "tc-$id", "title": "Run", "kind": "execute"},
            "options": [
              {"optionId": "allow", "name": "Allow", "kind": "allow_once"},
            ],
          },
        });
      }

      // Turns in flight on two sessions: attribution falls back to the most
      // recent dispatch (ACP carries no request→turn correlation).
      await sendPrompt(s1, "one");
      final s1Prompt = await promptFrameFor(s1);
      await sendPrompt(s2, "two");
      final s2Prompt = await promptFrameFor(s2);

      emitBarePermission(501);
      await pump();
      expect(await plugin.getPendingPermissions(sessionId: s2), hasLength(1));
      expect(await plugin.getPendingPermissions(sessionId: s1), isEmpty);

      // With only one turn left in flight, attribution is precise — even
      // though the other session dispatched more recently.
      respondTo(s2Prompt, {"stopReason": "end_turn"});
      await pump();
      await pump();
      emitBarePermission(502);
      await pump();
      expect(await plugin.getPendingPermissions(sessionId: s1), hasLength(1));

      // With no turn in flight, the last dispatched turn's session absorbs a
      // boundary request (the pre-existing behaviour).
      respondTo(s1Prompt, {"stopReason": "end_turn"});
      await pump();
      await pump();
      emitBarePermission(503);
      await pump();
      expect(await plugin.getPendingPermissions(sessionId: s2), hasLength(2));
    });
  });
}
