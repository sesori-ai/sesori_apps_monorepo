import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

/// A running sub-agent keeps its root busy after the root's own turn settles:
/// the idle reaper and safe stops must never kill it, the completion push
/// fires once, and the activity summary carries the child.
void main() {
  group("AcpPlugin child sessions keep the root busy", () {
    late FakeAcpProcess fake;
    late TestAcpPlugin plugin;
    late List<BridgeSseEvent> emitted;
    const cwd = "/repo";

    setUp(() {
      fake = FakeAcpProcess();
      emitted = [];
      plugin = composeTestAcpPlugin(processFactory: (_) async => fake, launchDirectory: cwd);
      plugin.events.listen(emitted.add);
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    Future<Map<String, dynamic>> waitForFrameCount(String method, int count) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where((frame) => frame["method"] == method).toList();
        if (matches.length >= count) return matches.last;
        await pump();
      }
      throw StateError("agent never wrote $count '$method' frames");
    }

    Future<Map<String, dynamic>> waitForFrame(String method) => waitForFrameCount(method, 1);

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
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", {"sessionId": "s1"});
      return (await creating).id;
    }

    Future<void> startTurn(String sessionId) async {
      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "spawn")],
        variant: null,
        agent: null,
        model: null,
      );
      await waitForFrame("session/prompt");
    }

    /// The harness mapper's push: a child spawned under [root] mid-turn.
    void spawnChild({required String root, required String childId}) {
      final result = plugin.childSessionTracker.spawn(
        sessionId: root,
        spawn: AcpChildSpawn(
          childSessionId: childId,
          description: "child",
          agent: "general-purpose",
          prompt: "p",
          isBackground: true,
        ),
        directory: cwd,
      );
      result.events.forEach(plugin.emitEvent);
    }

    /// The harness mapper's push: a child finished. Tracker-driven events reach
    /// the plugin stream asynchronously, so settle before asserting.
    Future<void> finishChild(String childId, {required PluginToolStatus status}) async {
      plugin.childSessionTracker
          .finish(childSessionId: childId, status: status, output: null, error: null)
          .forEach(plugin.emitEvent);
      await pump();
    }

    Future<void> finishChildAndHoldRoot(String childId, {required String holdId}) async {
      plugin.childSessionTracker
          .finishAndHoldRoot(
            childSessionId: childId,
            holdId: holdId,
            status: PluginToolStatus.completed,
            output: null,
            error: null,
          )
          .forEach(plugin.emitEvent);
      await pump();
    }

    Iterable<BridgeSseSessionIdle> rootIdles(String sessionId) =>
        emitted.whereType<BridgeSseSessionIdle>().where((event) => event.sessionID == sessionId);

    test("the root idle is deferred while a child runs and released by the last finish", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      spawnChild(root: sessionId, childId: "c2");

      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(rootIdles(sessionId), isEmpty, reason: "children still run");
      expect(await plugin.getSessionStatuses(), {
        sessionId: const PluginSessionStatus.busy(),
        "c1": const PluginSessionStatus.busy(),
        "c2": const PluginSessionStatus.busy(),
      });
      expect(plugin.currentWorkState, PluginWorkState.busy);
      final active = plugin.getActiveSessionsSummary().single.activeSessions.single;
      expect(active.id, sessionId);
      expect(active.mainAgentRunning, isFalse, reason: "the root's own turn settled");
      expect(active.childSessionIds, ["c1", "c2"]);

      final invalidationsBeforeFirstFinish = emitted.whereType<BridgeSseProjectUpdated>().length;
      await finishChild("c1", status: PluginToolStatus.completed);
      expect(rootIdles(sessionId), isEmpty, reason: "one child still runs");
      expect(emitted.whereType<BridgeSseProjectUpdated>().length, greaterThan(invalidationsBeforeFirstFinish));
      expect(plugin.getActiveSessionsSummary().single.activeSessions.single.childSessionIds, ["c2"]);
      expect(plugin.currentWorkState, PluginWorkState.busy);

      await finishChild("c2", status: PluginToolStatus.cancelled);
      expect(rootIdles(sessionId), hasLength(1), reason: "released exactly once");
      final childIdleIndex = emitted.lastIndexWhere(
        (event) =>
            event is BridgeSseSessionStatus &&
            event.sessionID == "c2" &&
            shared.SessionStatus.fromJson(event.status) == const shared.SessionStatus.idle(),
      );
      final rootIdleIndex = emitted.lastIndexWhere(
        (event) => event is BridgeSseSessionIdle && event.sessionID == sessionId,
      );
      expect(childIdleIndex, lessThan(rootIdleIndex), reason: "the real child terminal state must win first");
      expect(await plugin.getSessionStatuses(), {
        sessionId: const PluginSessionStatus.idle(),
        "c1": const PluginSessionStatus.idle(),
        "c2": const PluginSessionStatus.idle(),
      });
      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("a child finishing before the root's turn settles leaves the normal idle path intact", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await finishChild("c1", status: PluginToolStatus.completed);
      expect(rootIdles(sessionId), isEmpty, reason: "the root's own turn is still in flight");

      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(rootIdles(sessionId), hasLength(1));
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("a running child alone keeps the work state busy after an idle root", () async {
      final sessionId = await connectAndCreateSession();
      expect(plugin.currentWorkState, PluginWorkState.idle);
      spawnChild(root: sessionId, childId: "c1");
      await pump();
      expect(plugin.currentWorkState, PluginWorkState.busy);
      final active = plugin.getActiveSessionsSummary().single.activeSessions.single;
      expect(active.mainAgentRunning, isFalse);
      expect(active.childSessionIds, ["c1"]);
    });

    test("a new root turn during a deferred idle takes over the idle accounting", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(rootIdles(sessionId), isEmpty);

      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "again")],
        variant: null,
        agent: null,
        model: null,
      );
      await pump();
      await finishChild("c1", status: PluginToolStatus.completed);
      expect(rootIdles(sessionId), isEmpty, reason: "the second turn is still in flight");
      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(rootIdles(sessionId), hasLength(1));
    });

    test("an autonomous root hold bridges the child finish to its uncounted settlement turn", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await respond("session/prompt", {"stopReason": "end_turn"});

      await finishChildAndHoldRoot("c1", holdId: "wake-c1");
      expect(rootIdles(sessionId), isEmpty);
      expect(plugin.currentWorkState, PluginWorkState.busy);
      final active = plugin.getActiveSessionsSummary().single.activeSessions.single;
      expect(active.mainAgentRunning, isTrue, reason: "the autonomous root turn is active work");
      expect(active.childSessionIds, isEmpty, reason: "the child itself is already terminal");

      expect(
        plugin.childSessionTracker.releaseRootHold(rootSessionId: sessionId, holdId: "wake-c1"),
        isTrue,
      );
      await pump();
      expect(rootIdles(sessionId), hasLength(1));
      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("a prompt cancels and waits behind an autonomous root hold", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await respond("session/prompt", {"stopReason": "end_turn"});
      await finishChildAndHoldRoot("c1", holdId: "wake-c1");

      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );

      await waitForFrame("session/cancel");
      expect(
        fake.written.where((frame) => frame["method"] == "session/prompt"),
        hasLength(1),
        reason: "the autonomous root turn still owns the session lane",
      );

      plugin.childSessionTracker.releaseRootHold(rootSessionId: sessionId, holdId: "wake-c1");
      final secondPrompt = await waitForFrameCount("session/prompt", 2);
      fake.emit({
        "jsonrpc": "2.0",
        "id": secondPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await pump();

      expect(rootIdles(sessionId), hasLength(1));
    });

    test("global interruption clears a held root even without a session-status entry", () async {
      await connectAndCreateSession();
      plugin.childSessionTracker.spawn(
        sessionId: "unlisted-root",
        spawn: const AcpChildSpawn(
          childSessionId: "c1",
          description: "Thing",
          agent: "worker",
          prompt: "Do it",
          isBackground: false,
        ),
        directory: "/repo",
      );
      await finishChildAndHoldRoot("c1", holdId: "wake-c1");
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final interrupted = await plugin.interruptActiveWork(budget: const Duration(seconds: 1));

      expect(interrupted, {"unlisted-root"});
      expect(plugin.childSessionTracker.hasActiveWork, isFalse);
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("global interruption cancels tracker-only children before waiting for idle", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final interrupted = await plugin.interruptActiveWork(budget: const Duration(seconds: 1));

      expect(interrupted, {sessionId, "c1"});
      expect(plugin.currentWorkState, PluginWorkState.idle);
      expect(rootIdles(sessionId), hasLength(1));
      final tile = emitted
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartSubtask>()
          .last;
      expect(tile.taskState?.status, PluginToolStatus.cancelled);
    });

    test("process exit cancels running children, idles them, and releases the root", () async {
      final sessionId = await connectAndCreateSession();
      await startTurn(sessionId);
      spawnChild(root: sessionId, childId: "c1");
      await respond("session/prompt", {"stopReason": "end_turn"});
      expect(rootIdles(sessionId), isEmpty);

      fake.exit(1);
      await plugin.resetConnectionAfterExit();

      final tile = emitted
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartSubtask>()
          .last;
      expect(tile.childSessionID, "c1");
      expect(tile.taskState?.status, PluginToolStatus.cancelled);
      final childStatus = emitted.whereType<BridgeSseSessionStatus>().where((event) => event.sessionID == "c1").last;
      expect(shared.SessionStatus.fromJson(childStatus.status), const shared.SessionStatus.idle());
      expect(rootIdles(sessionId), hasLength(1));
      expect(await plugin.getSessionStatuses(), {sessionId: const PluginSessionStatus.idle()});
      expect(plugin.childSessionTracker.childStatuses, isEmpty);
    });

    test("deleting the root drops its children from the statuses", () async {
      final sessionId = await connectAndCreateSession();
      spawnChild(root: sessionId, childId: "c1");
      expect((await plugin.getSessionStatuses()).keys, containsAll([sessionId, "c1"]));

      await plugin.deleteSession(sessionId);
      await pump();
      expect(await plugin.getSessionStatuses(), isEmpty);
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });
  });
}
