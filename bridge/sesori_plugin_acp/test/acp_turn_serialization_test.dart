import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// An [AcpPlugin] whose [applyTurnSelection] blocks on a test-controlled gate,
/// so a test can land an abort while a turn is mid-selection.
class _GatedSelectionPlugin extends AcpPlugin {
  _GatedSelectionPlugin({
    required super.id,
    required super.agentDisplayName,
    required super.launchSpec,
    required super.launchDirectory,
    required super.eventMapper,
    required AcpProcessFactory super.processFactory,
  });

  Completer<void>? selectionGate;

  @override
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    final gate = selectionGate;
    if (gate != null) await gate.future;
  }
}

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

    // Polls with a small real delay: a serialized turn's dispatch can sit
    // behind the resume-load replay drain (~250ms of wall-clock quiet time),
    // which zero-duration pumps never outlast.
    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 400; i++) {
        final matches = frames(method);
        if (matches.length >= count) return matches[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
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

    test("an accepted prompt is emitted immediately as a user message", () async {
      await connect();
      final sessionId = await createSession(cwd, "s1");
      emitted.clear();

      await sendPrompt(sessionId, "visible immediately");
      await pump();

      final message = emitted.whereType<BridgeSseMessageUpdated>().single;
      expect(message.info["role"], "user");
      expect(
        emitted.whereType<BridgeSseMessagePartUpdated>().single.part.text,
        "visible immediately",
      );

      final prompt = await waitForFrame("session/prompt");
      respondTo(prompt, {"stopReason": "end_turn"});
    });

    test("an initial create prompt is left to history replay", () async {
      await connect();
      emitted.clear();

      final creating = plugin.createSession(
        directory: cwd,
        parentSessionId: null,
        parts: [
          const PluginPromptPart.text(text: "[SYSTEM CONTEXT — IMPORTANT] internal"),
          const PluginPromptPart.text(text: "visible prompt"),
        ],
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrame("session/new");
      respondTo(frame, {"sessionId": "s1"});
      await creating;
      await pump();

      expect(emitted.whereType<BridgeSseMessageUpdated>(), isEmpty);

      final prompt = await waitForFrame("session/prompt");
      respondTo(prompt, {"stopReason": "end_turn"});
    });

    test("command arguments are not emitted as a user message", () async {
      await connect();
      final sessionId = await createSession(cwd, "s1");
      emitted.clear();

      await plugin.sendCommand(
        sessionId: sessionId,
        command: "review",
        arguments: "[SYSTEM CONTEXT — IMPORTANT] internal\n\nuser arguments",
        variant: null,
        agent: null,
        model: null,
      );
      await pump();

      expect(emitted.whereType<BridgeSseMessageUpdated>(), isEmpty);

      final prompt = await waitForFrame("session/prompt");
      respondTo(prompt, {"stopReason": "end_turn"});
    });

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

    test("an abort landing during turn selection still drops the turn", () async {
      final gated = _GatedSelectionPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp"),
        processFactory: (_) async => fake,
      );
      addTearDown(gated.dispose);
      final gatedEvents = <BridgeSseEvent>[];
      gated.events.listen(gatedEvents.add);

      final connecting = gated.ensureConnected();
      final init = await waitForFrame("initialize");
      respondTo(init, {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      final creating = gated.createSession(
        directory: cwd,
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      respondTo(await waitForFrame("session/new"), {"sessionId": "s1"});
      await creating;

      // Hold the turn in selection, abort, then release the gate: the prompt
      // must never dispatch (an abort right before dispatch must not start a
      // fresh agent run).
      final gate = Completer<void>();
      gated.selectionGate = gate;
      await gated.sendPrompt(
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );
      for (var i = 0; i < 5; i++) {
        await pump();
      }
      await gated.abortSession(sessionId: "s1");
      gate.complete();
      for (var i = 0; i < 10; i++) {
        await pump();
      }

      expect(frames("session/prompt"), isEmpty);
      expect(gatedEvents.whereType<BridgeSseSessionIdle>(), hasLength(1));
      expect(gated.getActiveSessionsSummary(), isEmpty);
    });

    test("deleting a session mid-turn does not resurrect it as idle", () async {
      await connect();
      final sessionId = await createSession(cwd, "s1");

      await sendPrompt(sessionId, "hi");
      final promptFrame = await waitForFrame("session/prompt");

      await plugin.deleteSession(sessionId);
      expect(frames("session/cancel"), hasLength(1));

      // The cancelled prompt settles after the delete: its accounting must not
      // re-create the deleted session's status entry or emit idle for it.
      respondTo(promptFrame, {"stopReason": "cancelled"});
      for (var i = 0; i < 10; i++) {
        await pump();
      }
      expect(await plugin.getSessionStatuses(), isEmpty);
      expect(emitted.whereType<BridgeSseSessionIdle>(), isEmpty);
    });

    test("a queued turn retries a transiently failed resume-load at dispatch", () async {
      await connect(loadSession: true);

      // Two prompts queued up front. The first turn's load fails transiently
      // and its prompt errors; the SECOND queued turn must retry the load at
      // its own dispatch — not inherit the failure.
      final sendingA = sendPrompt("old-1", "a");
      final sendingB = sendPrompt("old-1", "b");
      await Future.wait([sendingA, sendingB]);

      final firstLoad = await waitForFrame("session/load");
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstLoad["id"],
        "error": {"code": -32000, "message": "transient"},
      });
      final firstPrompt = await waitForFrame("session/prompt");
      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "error": {"code": -32000, "message": "session not found"},
      });

      final secondLoad = await waitForFrameCount("session/load", 2);
      respondTo(secondLoad, const {});
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      respondTo(secondPrompt, {"stopReason": "end_turn"});
      await pump();
      expect(frames("session/load"), hasLength(2));
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

    test("a queued turn survives an agent respawn by resolving the live client", () async {
      // Two processes: the first dies mid-turn, the queued turn must dispatch
      // on the respawned replacement instead of failing against the captured
      // dead client.
      final fakes = [FakeAcpProcess(), FakeAcpProcess()];
      final spawned = <FakeAcpProcess>[];
      final respawning = AcpPlugin(
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        launchDirectory: cwd,
        eventMapper: AcpEventMapper(launchDirectory: cwd, agentId: "acp"),
        processFactory: (_) async {
          final next = fakes.removeAt(0);
          spawned.add(next);
          return next;
        },
      );
      addTearDown(() async {
        await respawning.dispose();
        for (final f in spawned) {
          await f.close();
        }
        for (final f in fakes) {
          await f.close();
        }
      });
      final events = <BridgeSseEvent>[];
      respawning.events.listen(events.add);

      List<Map<String, dynamic>> framesOn(FakeAcpProcess fake, String method) =>
          fake.written.where((f) => f["method"] == method).toList(growable: false);
      Future<Map<String, dynamic>> waitOn(FakeAcpProcess fake, String method, int count) async {
        for (var i = 0; i < 400; i++) {
          final matches = framesOn(fake, method);
          if (matches.length >= count) return matches[count - 1];
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        throw StateError("expected $count '$method' frame(s)");
      }

      final connecting = respawning.ensureConnected();
      final first = spawned.isEmpty ? fakes.first : spawned.first;
      final init1 = await waitOn(first, "initialize", 1);
      first.emit({
        "jsonrpc": "2.0",
        "id": init1["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);

      final creating = respawning.createSession(
        directory: cwd,
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      final newFrame = await waitOn(first, "session/new", 1);
      first.emit({
        "jsonrpc": "2.0",
        "id": newFrame["id"],
        "result": {"sessionId": "s1"},
      });
      await creating;

      Future<void> send(String text) => respawning.sendPrompt(
        sessionId: "s1",
        parts: [PluginPromptPart.text(text: text)],
        variant: null,
        agent: null,
        model: null,
      );

      await send("first");
      await waitOn(first, "session/prompt", 1);
      await send("queued");

      // The agent dies mid-turn; the lifecycle wrapper resets the connection.
      first.exit(1);
      await respawning.resetConnectionAfterExit();

      // The queued turn re-resolves the client, spawning the replacement and
      // completing its handshake before dispatching.
      final second = await () async {
        for (var i = 0; i < 400; i++) {
          if (spawned.length > 1) return spawned[1];
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        throw StateError("the queued turn never respawned the agent");
      }();
      final init2 = await waitOn(second, "initialize", 1);
      second.emit({
        "jsonrpc": "2.0",
        "id": init2["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });

      final queuedPrompt = await waitOn(second, "session/prompt", 1);
      expect((queuedPrompt["params"] as Map)["sessionId"], "s1");
      second.emit({
        "jsonrpc": "2.0",
        "id": queuedPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      for (var i = 0; i < 10; i++) {
        await pump();
      }

      // The interrupted first turn surfaced as an error; the queued turn
      // completed and the session settled idle.
      expect(events.whereType<BridgeSseSessionError>(), hasLength(1));
      expect(events.whereType<BridgeSseSessionIdle>(), hasLength(1));
      expect(respawning.getActiveSessionsSummary(), isEmpty);
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
