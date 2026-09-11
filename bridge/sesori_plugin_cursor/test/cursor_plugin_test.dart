import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorPlugin", () {
    late FakeAcpProcess fake;
    late CursorPlugin plugin;
    late _FakeCursorSessionCleanupService sessionCleanupService;
    late Set<Object?> handledFrameIds;

    Map<String, dynamic> catalogResult() => {
      "sessionId": "s1",
      "configOptions": [
        {
          "id": "mode",
          "category": "mode",
          "currentValue": "agent",
          "options": [
            {
              "value": "agent",
              "name": "Agent",
              "description": "Works autonomously",
            },
            {
              "value": "plan",
              "name": "Plan",
              "description": "Plans before editing",
            },
            {
              "value": "ask",
              "name": "Ask",
              "description": "Answers without editing",
            },
          ],
        },
        {
          "id": "model",
          "category": "model",
          "currentValue": "gpt-5.4",
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        {
          "id": "effort",
          "category": "thought_level",
          "currentValue": "medium",
          "options": [
            {"value": "low", "name": "Low"},
            {"value": "medium", "name": "Medium"},
            {"value": "high", "name": "High"},
          ],
        },
      ],
    };

    Map<String, dynamic> effortModelSelectionResult({required String modelId}) => {
      "configOptions": [
        {
          "id": "model",
          "category": "model",
          "currentValue": modelId,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        {
          "id": "effort",
          "category": "thought_level",
          "currentValue": "medium",
          "options": [
            {"value": "low", "name": "Low"},
            {"value": "medium", "name": "Medium"},
            {"value": "high", "name": "High"},
          ],
        },
      ],
    };

    void capture(
      Map<String, dynamic> result, {
      String? sessionId,
      bool fromNewSession = false,
    }) {
      plugin.captureSessionConfig(
        AcpNewSessionResult.fromJson(result),
        sessionId: sessionId,
        fromNewSession: fromNewSession,
      );
    }

    setUp(() {
      fake = FakeAcpProcess();
      sessionCleanupService = _FakeCursorSessionCleanupService();
      handledFrameIds = {};
      plugin = CursorPlugin(
        launchDirectory: "/repo",
        processFactory: (_) async => fake,
        sessionCleanupService: sessionCleanupService,
      );
    });

    tearDown(() async {
      await plugin.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);
    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = fake.written.where(
          (frame) => frame["method"] == method && !handledFrameIds.contains(frame["id"]),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrameIds.add(frame["id"]);
          return frame;
        }
        await pump();
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    void respondFrame(Map<String, dynamic> frame, Map<String, dynamic> result) {
      fake.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<void> respond(String method, Map<String, dynamic> result) async {
      respondFrame(await waitForFrame(method), result);
      await pump();
    }

    Future<PluginAbortResult> abort({required String sessionId, required PluginAbortSubAgentPolicy policy}) =>
        plugin.abortSession(
          sessionId: sessionId,
          subAgents: policy,
          useAtomicStop: true,
          knownSubAgentSessionIds: const {"must-not-fan-out"},
        );

    Future<Map<String, dynamic>> startTaskPrompt({
      required String sessionId,
      required String toolCallId,
      required bool connect,
    }) async {
      if (connect) {
        final connecting = plugin.ensureConnected();
        await respond("initialize", const {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        });
        expect(await connecting, isTrue);
      }
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", {"sessionId": sessionId});
      final session = await creating;
      await plugin.sendPrompt(
        sessionId: session.id,
        promptId: "prompt-$sessionId",
        parts: const [PluginPromptPart.text(text: "delegate")],
        variant: null,
        agent: null,
        model: null,
      );
      final prompt = await waitForFrame("session/prompt");
      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": session.id,
          "update": {
            "sessionUpdate": "tool_call",
            "toolCallId": toolCallId,
            "title": "Task: inspect",
            "status": "pending",
            "rawInput": {"_toolName": "task"},
          },
        },
      });
      await pump();
      return prompt;
    }

    test("delegates persisted session cleanup", () async {
      expect(plugin, isA<PersistedSessionCleanupApi>());

      await plugin.deletePersistedSession(
        backendSessionId: "session-1",
      );

      expect(sessionCleanupService.deletedSessionIds, ["session-1"]);
    });

    // getProviders now warms the catalog before returning (so a fresh session's
    // effort pill is populated up front). That needs the ACP handshake. For a
    // test that only reads back a directly-captured catalog, service a
    // no-capability agent (no session list) so the warm-up probe is an instant
    // no-op, then return the providers. Use only for the FIRST fetch on a
    // plugin; afterward that scope's exhausted outcome skips another probe.
    Future<PluginProvidersResult> providersAfterWarmup() async {
      final future = plugin.getProviders(projectId: "/repo");
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      await respond("cursor/list_available_models", const {"models": <Object?>[]});
      return await future;
    }

    test("id is cursor", () {
      expect(plugin.id, "cursor");
    });

    test("the default binary is the stable Cursor CLI executable", () {
      expect(CursorBinary.defaultBinary, "cursor-agent");
      final spec = CursorBinary.launchSpec(cwd: "/repo");
      expect(spec.command, "cursor-agent");
      expect(spec.args, ["acp"]);
    });

    test("compact stays user-visible while summarize is dispatched", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final connecting = plugin.ensureConnected();
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", const {"sessionId": "s-command"});
      final session = await creating;

      await plugin.sendCommand(
        promptId: "prompt-1",
        sessionId: session.id,
        command: "compact",
        arguments: "focus on the current task",
        userVisibleArguments: "focus on the current task",
        variant: null,
        agent: null,
        model: null,
      );
      await pump();

      expect(
        (events.whereType<BridgeSseMessagePartUpdated>().single.part as PluginMessagePartText).text,
        "/compact focus on the current task",
      );
      final promptFrame = await waitForFrame("session/prompt");
      final params = (promptFrame["params"] as Map).cast<String, dynamic>();
      final prompt = params["prompt"] as List;
      expect(
        (prompt.single as Map)["text"],
        "/summarize focus on the current task",
      );
      fake.emit({
        "jsonrpc": "2.0",
        "id": promptFrame["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("a busy follow-up cancels the active turn before replacement dispatch", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final connecting = plugin.ensureConnected();
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await respond("session/new", const {"sessionId": "s-follow-up"});
      final session = await creating;

      await plugin.sendPrompt(
        promptId: "prompt-1",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final firstPrompt = await waitForFrame("session/prompt");

      await plugin.sendPrompt(
        promptId: "prompt-2",
        sessionId: session.id,
        parts: const [PluginPromptPart.text(text: "replace it")],
        variant: null,
        agent: null,
        model: null,
      );
      final cancel = await waitForFrame("session/cancel");
      expect(cancel["params"], {"sessionId": session.id});
      expect(fake.written.where((frame) => frame["method"] == "session/prompt"), hasLength(1));
      expect((await plugin.getQueuedPrompts(sessionId: session.id)).single.id, "prompt-2");

      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "result": {"stopReason": "cancelled"},
      });
      final replacement = await waitForFrame("session/prompt");
      final replacementParams = (replacement["params"] as Map).cast<String, dynamic>();
      expect(replacementParams["sessionId"], session.id);
      expect(((replacementParams["prompt"] as List).single as Map)["text"], "replace it");
      expect(await plugin.getQueuedPrompts(sessionId: session.id), isEmpty);
      expect(events.whereType<BridgeSseSessionIdle>(), isEmpty);

      fake.emit({
        "jsonrpc": "2.0",
        "id": replacement["id"],
        "result": {"stopReason": "end_turn"},
      });
      for (var i = 0; i < 10 && events.whereType<BridgeSseSessionIdle>().isEmpty; i++) {
        await pump();
      }
      expect(events.whereType<BridgeSseSessionIdle>(), hasLength(1));
      expect(events.whereType<BridgeSseSessionError>(), isEmpty);
    });

    test("prompt cancellation settles active Task before the root turns idle", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final prompt = await startTaskPrompt(
        sessionId: "s-task-cancel",
        toolCallId: "task-cancel-1",
        connect: true,
      );

      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "cancelled"},
      });
      for (var i = 0; i < 10 && events.whereType<BridgeSseSessionIdle>().isEmpty; i++) {
        await pump();
      }

      final cancelledIndex = events.indexWhere(
        (event) =>
            event is BridgeSseMessagePartUpdated &&
            event.part is PluginMessagePartTool &&
            (event.part as PluginMessagePartTool).state.status == PluginToolStatus.cancelled,
      );
      final idleIndex = events.indexWhere((event) => event is BridgeSseSessionIdle);
      expect(cancelledIndex, greaterThanOrEqualTo(0));
      expect(idleIndex, greaterThan(cancelledIndex));
    });

    test("prompt failure errors active Task after prompt error and before root settlement", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final prompt = await startTaskPrompt(
        sessionId: "s-task-failure",
        toolCallId: "task-failure-1",
        connect: true,
      );

      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "error": {"code": -32000, "message": "Agent connection failed"},
      });
      for (var i = 0; i < 10 && events.whereType<BridgeSseSessionIdle>().isEmpty; i++) {
        await pump();
      }

      final promptErrorIndex = events.indexWhere(
        (event) => event is BridgeSseMessageUpdated && event.info is PluginMessageError,
      );
      final taskErrorIndex = events.indexWhere(
        (event) =>
            event is BridgeSseMessagePartUpdated &&
            event.part is PluginMessagePartTool &&
            (event.part as PluginMessagePartTool).state.status == PluginToolStatus.error,
      );
      final sessionErrorIndex = events.indexWhere((event) => event is BridgeSseSessionError);
      final idleIndex = events.indexWhere((event) => event is BridgeSseSessionIdle);
      expect(promptErrorIndex, greaterThanOrEqualTo(0));
      expect(taskErrorIndex, greaterThan(promptErrorIndex));
      expect(
        ((events[taskErrorIndex] as BridgeSseMessagePartUpdated).part as PluginMessagePartTool).state.error,
        "Agent connection failed",
      );
      expect(idleIndex, greaterThan(taskErrorIndex));
      expect(sessionErrorIndex, greaterThan(idleIndex));
    });

    test("process exit errors active Task before root settlement resets correlation", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);
      final wrapper = AcpBridgePlugin(plugin: plugin, clock: const ServerClock());
      addTearDown(() => wrapper.shutdown(budget: null));

      final connecting = wrapper.connect(
        budget: const Duration(seconds: 1),
        startAborted: StartAbortSignal.never,
      );
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      await connecting;
      await startTaskPrompt(
        sessionId: "s-task-exit",
        toolCallId: "task-exit-1",
        connect: false,
      );

      fake.exit(17);
      for (var i = 0; i < 10 && (events.whereType<BridgeSseSessionIdle>().isEmpty || plugin.client != null); i++) {
        await pump();
      }

      final taskErrorIndex = events.indexWhere(
        (event) =>
            event is BridgeSseMessagePartUpdated &&
            event.part is PluginMessagePartTool &&
            (event.part as PluginMessagePartTool).state.status == PluginToolStatus.error,
      );
      final sessionErrorIndex = events.indexWhere((event) => event is BridgeSseSessionError);
      final idleIndex = events.indexWhere((event) => event is BridgeSseSessionIdle);
      expect(taskErrorIndex, greaterThanOrEqualTo(0));
      expect(
        ((events[taskErrorIndex] as BridgeSseMessagePartUpdated).part as PluginMessagePartTool).state.error,
        "agent process exited with code 17",
      );
      expect(idleIndex, greaterThan(taskErrorIndex));
      expect(sessionErrorIndex, greaterThan(idleIndex));
      expect(plugin.client, isNull);
    });

    test("prompt-write Task completion stays ordered before its acknowledged cursor/task request", () async {
      const sessionId = "s-task-prompt-write";
      const toolCallId = "task-prompt-write-1";
      final promptWriteFake = _PromptWriteCursorProcess(
        sessionId: sessionId,
        toolCallId: toolCallId,
      );
      final promptWritePlugin = CursorPlugin(
        launchDirectory: "/repo",
        processFactory: (_) async => promptWriteFake,
        sessionCleanupService: _FakeCursorSessionCleanupService(),
      );
      final events = <BridgeSseEvent>[];
      final subscription = promptWritePlugin.events.listen(events.add);
      addTearDown(() async {
        await subscription.cancel();
        await promptWritePlugin.dispose();
        await promptWriteFake.close();
      });

      Future<Map<String, dynamic>> waitForPromptWriteFrame(String method) async {
        for (var i = 0; i < 50; i++) {
          final matches = promptWriteFake.written.where((frame) => frame["method"] == method);
          if (matches.isNotEmpty) return matches.first;
          await pump();
        }
        throw StateError("agent never wrote a '$method' frame");
      }

      final connecting = promptWritePlugin.ensureConnected();
      final initialize = await waitForPromptWriteFrame("initialize");
      promptWriteFake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
          "authMethods": <Object?>[],
        },
      });
      expect(await connecting, isTrue);

      final creating = promptWritePlugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final sessionNew = await waitForPromptWriteFrame("session/new");
      promptWriteFake.emit({
        "jsonrpc": "2.0",
        "id": sessionNew["id"],
        "result": {"sessionId": sessionId},
      });
      final session = await creating;

      await promptWritePlugin.sendPrompt(
        sessionId: session.id,
        promptId: "prompt-task-write",
        parts: const [PluginPromptPart.text(text: "delegate")],
        variant: null,
        agent: null,
        model: null,
      );
      final prompt = await waitForPromptWriteFrame("session/prompt");
      for (
        var i = 0;
        i < 50 &&
            (events
                    .whereType<BridgeSseMessagePartUpdated>()
                    .where((event) => event.part is PluginMessagePartSubtask)
                    .isEmpty ||
                promptWriteFake.written.every((frame) => frame["id"] != _PromptWriteCursorProcess.taskRequestId));
        i++
      ) {
        await pump();
      }

      final userIndex = events.indexWhere(
        (event) =>
            event is BridgeSseMessageUpdated &&
            event.info is PluginMessageUser &&
            (event.info as PluginMessageUser).promptId == "prompt-task-write",
      );
      final genericIndex = events.indexWhere(
        (event) =>
            event is BridgeSseMessagePartUpdated &&
            event.part is PluginMessagePartTool &&
            event.part.id.contains(toolCallId) &&
            (event.part as PluginMessagePartTool).state.status == PluginToolStatus.completed,
      );
      final tiles = events
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartSubtask>()
          .where((part) => part.id.contains(toolCallId))
          .toList(growable: false);
      final tileIndex = events.indexWhere(
        (event) => event is BridgeSseMessagePartUpdated && event.part is PluginMessagePartSubtask,
      );
      expect(userIndex, greaterThanOrEqualTo(0));
      expect(genericIndex, greaterThan(userIndex), reason: "accepted user content precedes buffered Task output");
      expect(tileIndex, greaterThan(genericIndex), reason: "terminal Task maps before cursor/task reinjection");
      expect(tiles, hasLength(1));
      expect(tiles.single.taskState?.status, PluginToolStatus.completed);
      expect(
        promptWriteFake.written.singleWhere(
          (frame) => frame["id"] == _PromptWriteCursorProcess.taskRequestId,
        )["result"],
        isA<Map<Object?, Object?>>(),
        reason: "cursor/task is acknowledged through production Cursor composition",
      );

      promptWriteFake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("tool-correlated extensions keep the earlier session with two turns in flight", () async {
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);
      addTearDown(subscription.cancel);

      final connecting = plugin.ensureConnected();
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);

      Future<String> createSession({required String sessionId}) async {
        final creating = plugin.createSession(
          directory: "/repo",
          parentSessionId: null,
          parts: const [],
          userVisibleText: null,
          variant: null,
          agent: null,
          model: null,
        );
        await respond("session/new", {"sessionId": sessionId});
        return (await creating).id;
      }

      final firstSessionId = await createSession(sessionId: "s-first");
      final secondSessionId = await createSession(sessionId: "s-second");
      await plugin.sendPrompt(
        promptId: "prompt-first",
        sessionId: firstSessionId,
        parts: const [PluginPromptPart.text(text: "first")],
        variant: null,
        agent: null,
        model: null,
      );
      final firstPrompt = await waitForFrame("session/prompt");
      await plugin.sendPrompt(
        promptId: "prompt-second",
        sessionId: secondSessionId,
        parts: const [PluginPromptPart.text(text: "second")],
        variant: null,
        agent: null,
        model: null,
      );
      final secondPrompt = await waitForFrame("session/prompt");

      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": firstSessionId,
          "update": {
            "sessionUpdate": "tool_call",
            "toolCallId": "todo-tool",
            "kind": "other",
            "status": "pending",
          },
        },
      });
      await pump();
      fake.emit({
        "jsonrpc": "2.0",
        "id": 90,
        "method": "cursor/update_todos",
        "params": {"toolCallId": "todo-tool", "todos": <Object?>[]},
      });
      await pump();

      expect(events.whereType<BridgeSseTodoUpdated>().single.sessionID, firstSessionId);
      expect(
        fake.written.singleWhere((frame) => frame["id"] == 90)["result"],
        isA<Map<Object?, Object?>>(),
      );

      fake.emit({
        "jsonrpc": "2.0",
        "id": firstPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": secondPrompt["id"],
        "result": {"stopReason": "end_turn"},
      });
    });

    test("active Task rejects confirm and keep, while stop cancels only root and waits", () async {
      const sessionId = "s-task-stop";
      final prompt = await startTaskPrompt(sessionId: sessionId, toolCallId: "task-stop-1", connect: true);
      final writesBeforePolicy = fake.written.length;
      for (final policy in [PluginAbortSubAgentPolicy.confirm, PluginAbortSubAgentPolicy.keep]) {
        expect(
          await abort(sessionId: sessionId, policy: policy),
          isA<PluginAbortRejectedSubAgentsRunning>().having((result) => result.runningSubAgentCount, "count", 1),
        );
      }
      expect(fake.written, hasLength(writesBeforePolicy));

      final stopping = abort(sessionId: sessionId, policy: PluginAbortSubAgentPolicy.stop);
      await pump();
      expect(fake.written.where((frame) => frame["method"] == AcpMethods.sessionCancel), hasLength(1));
      respondFrame(prompt, {"stopReason": "cancelled"});
      expect(await stopping, const PluginAbortAccepted(workKept: false, subAgentsHandled: false));
    });

    test("background transition makes stop partial, then every policy refuses without effects", () async {
      final workStates = <PluginWorkState>[];
      final workSubscription = plugin.workState.listen(workStates.add);
      addTearDown(workSubscription.cancel);
      const sessionId = "s-background-stop";
      final prompt = await startTaskPrompt(
        sessionId: sessionId,
        toolCallId: "task-background-stop",
        connect: true,
      );
      final stopping = abort(sessionId: sessionId, policy: PluginAbortSubAgentPolicy.stop);
      await pump();
      fake.emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": "tool_call_update",
            "toolCallId": "task-background-stop",
            "status": "completed",
            "rawOutput": {"durationMs": 5, "isBackground": true},
          },
        },
      });
      respondFrame(prompt, {"stopReason": "cancelled"});
      await expectLater(
        stopping,
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "status", 502)),
      );
      await pump();
      expect(await plugin.getSessionStatuses(), {sessionId: const PluginSessionStatus.idle()});
      expect(workStates.last, PluginWorkState.busy);

      await plugin.sendPrompt(
        sessionId: sessionId,
        promptId: "prompt-after-background",
        parts: const [PluginPromptPart.text(text: "must survive refusal")],
        variant: null,
        agent: null,
        model: null,
      );
      final survivingPrompt = await waitForFrame("session/prompt");
      final writesBeforeRefusals = fake.written.length;
      for (final policy in PluginAbortSubAgentPolicy.values) {
        expect(
          await abort(sessionId: sessionId, policy: policy),
          const PluginAbortNotPerformed(reason: PluginAbortRefusalReason.residentWorkCompletionUnknown),
        );
      }
      expect(fake.written, hasLength(writesBeforeRefusals));
      expect(plugin.getActiveSessionsSummary().single.activeSessions.single.mainAgentRunning, isTrue);
      respondFrame(survivingPrompt, {"stopReason": "end_turn"});
      await pump();

      await plugin.resetConnectionAfterExit();
      expect(workStates.last, PluginWorkState.idle);
    });

    test("captureSessionConfig populates providers, effort variants, and mode agents", () async {
      capture(catalogResult(), fromNewSession: true);

      final providers = await providersAfterWarmup();
      expect(providers.providers, hasLength(1));
      final provider = providers.providers.single;
      expect(provider.id, "cursor");
      expect(provider.models, hasLength(2));
      expect(provider.defaultModelID, "gpt-5.4");
      // Effort levels are per-model variants, default effort first. Sibling
      // models get a provisional copy so the first providers response is complete.
      expect(provider.models.first.variants, ["high", "medium", "low"]);
      expect(provider.models.last.variants, ["high", "medium", "low"]);

      final agents = await plugin.getAgents(projectId: "/repo");
      expect(agents.map((a) => a.name), ["Agent", "Plan", "Ask"]);
      expect(
        agents.map((a) => a.description),
        ["Works autonomously", "Plans before editing", "Answers without editing"],
      );
      expect(agents.every((a) => a.model == null), isTrue);
    });

    test("getSessionOptions delegates one plugin-scoped tracker snapshot", () async {
      capture(catalogResult(), fromNewSession: true);

      final optionsFuture = plugin.getSessionOptions(
        projectId: "/another-project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      // Service the catalog warm-up probe so it completes instantly instead of
      // waiting out the 12s total probe timeout with no agent on hand.
      await respond("initialize", const {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      await respond("cursor/list_available_models", const {"models": <Object?>[]});

      final result = await optionsFuture;

      final options = (result as PluginSessionOptionsDiscoveryObserved).options;
      expect(options.completeness, PluginSessionOptionsCompleteness.partial);
      expect(options.agents.map((agent) => agent.name), ["Agent", "Plan", "Ask"]);
      expect(options.providers.providers.single.defaultModelID, "gpt-5.4");
      expect(options.commands.single.name, "compact");
    });

    Map<String, dynamic> modelCatalog(String currentValue, {bool includeMode = true}) => {
      "sessionId": "s",
      "configOptions": [
        if (includeMode)
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
              {"value": "plan", "name": "Plan"},
              {"value": "ask", "name": "Ask"},
            ],
          },
        {
          "id": "model",
          "category": "model",
          "currentValue": currentValue,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
      ],
    };

    test("a session/new capture seeds the new-session default model", () async {
      capture(modelCatalog("sonnet-4.6"), sessionId: "new-1", fromNewSession: true);
      expect(
        (await providersAfterWarmup()).providers.single.defaultModelID,
        "sonnet-4.6",
        reason: "session/new's currentValue is the new-session default, even when it isn't the first model",
      );
    });

    test("a session/load (or probe) does not overwrite the new-session default", () async {
      capture(modelCatalog("gpt-5.4"), sessionId: "new-1", fromNewSession: true);
      // First fetch records an exhausted outcome for this scope.
      expect((await providersAfterWarmup()).providers.single.defaultModelID, "gpt-5.4");

      capture(modelCatalog("sonnet-4.6"), sessionId: "old");
      capture(modelCatalog("sonnet-4.6"));

      // Latched: this fetch reads back without re-warming.
      expect(
        (await plugin.getProviders(projectId: "/repo")).providers.single.defaultModelID,
        "gpt-5.4",
        reason: "neither a load nor a probe may change the new-session default",
      );
    });

    test("applyTurnSelection drives model + mode + effort from agent and variant", () async {
      capture(catalogResult(), fromNewSession: true);

      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "plan",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // mode=plan
      await respond("session/set_config_option", const {}); // effort=high
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets, hasLength(3));
      expect(sets[0]["configId"], "model");
      expect(sets[0]["value"], "sonnet-4.6");
      expect(sets[1]["configId"], "mode");
      expect(sets[1]["value"], "plan");
      expect(sets[2]["configId"], "effort");
      expect(sets[2]["value"], "high");

      final again = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "plan",
      );
      await again;
      final setsAfter = fake.written.where((f) => f["method"] == "session/set_config_option");
      expect(setsAfter, hasLength(3), reason: "unchanged model+mode+effort are not re-applied");

      await client.dispose();
    });

    test("applyTurnSelection resolves mode from display name agent", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: "Ask",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode=ask
      await respond("session/set_config_option", const {}); // effort=medium
      await applying;

      final modeSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "mode")
          .map((p) => p["value"])
          .toList();
      expect(modeSets, ["ask"]);

      await client.dispose();
    });

    test("applyTurnSelection re-applies the same effort after a model switch", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final first = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort high
      await first;

      final second = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model sonnet
      await respond("session/set_config_option", const {}); // effort high again
      await second;

      final effortSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort")
          .map((p) => p["value"])
          .toList();
      expect(effortSets, ["high", "high"], reason: "the same effort string must be re-pushed after a model change");

      await client.dispose();
    });

    test("applyTurnSelection uses per-model thought_level config ids", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final first = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "reasoning",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      }); // model -> stamps reasoning for gpt
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort/reasoning high
      await first;

      final second = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "agent",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "sonnet-4.6",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      }); // model -> stamps effort for sonnet
      await respond("session/set_config_option", const {}); // high on effort
      await second;

      final thoughtSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort" || p["configId"] == "reasoning")
          .map((p) => "${p["configId"]}=${p["value"]}")
          .toList();
      expect(thoughtSets, ["reasoning=high", "effort=high"]);

      await client.dispose();
    });

    test("applyTurnSelection does not reuse another model's thought config id", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
      );
      await respond(
        "session/set_config_option",
        modelCatalog("sonnet-4.6"),
      ); // model response has no thought_level option
      await respond("session/set_config_option", const {}); // mode=plan
      await applying;

      final configIds = fake.written
          .where((frame) => frame["method"] == "session/set_config_option")
          .map((frame) => frame["params"] as Map)
          .map((params) => params["configId"])
          .toList();
      expect(configIds, ["model", "mode"]);

      await client.dispose();
    });

    test("applyTurnSelection restores the selected model's default effort", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final selectingHigh = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
      );
      await respond("session/set_config_option", {
        "configOptions": [
          {
            "id": "model",
            "category": "model",
            "currentValue": "sonnet-4.6",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "low",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "high", "name": "High"},
            ],
          },
        ],
      });
      await respond("session/set_config_option", const {}); // mode=plan
      await respond("session/set_config_option", const {}); // effort=high
      await selectingHigh;

      final restoringDefault = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: "Plan",
      );
      await respond("session/set_config_option", const {}); // effort=low
      await restoringDefault;

      final effortSets = fake.written
          .where((frame) => frame["method"] == "session/set_config_option")
          .map((frame) => (frame["params"] as Map).cast<String, dynamic>())
          .where((params) => params["configId"] == "effort")
          .map((params) => params["value"])
          .toList();
      expect(effortSets, ["high", "low"]);

      await client.dispose();
    });

    test("applyTurnSelection never pushes an unknown model", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "not-a-real-model"),
        variant: null,
        agent: null,
      );
      await respond("session/set_config_option", const {}); // mode=agent
      await respond("session/set_config_option", const {}); // effort=medium
      await applying;

      final sets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .toList();
      expect(sets.where((s) => s["configId"] == "model"), isEmpty, reason: "unknown model is never pushed");
      expect(sets.where((s) => s["configId"] == "mode" && s["value"] == "agent"), hasLength(1));
      expect(sets.where((s) => s["configId"] == "effort" && s["value"] == "medium"), hasLength(1));

      await client.dispose();
    });

    test("a default turn preserves an unknown model reported by Cursor", () async {
      capture(
        {
          "sessionId": "s1",
          "configOptions": [
            {
              "id": "model",
              "category": "model",
              "currentValue": "cursor-internal-model",
              "options": [
                {"value": "gpt-5.4", "name": "GPT-5.4"},
              ],
            },
          ],
        },
        sessionId: "s1",
        fromNewSession: true,
      );
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );

      await plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: null,
        variant: null,
        agent: null,
      );

      expect(plugin.eventMapper.modelForSession(sessionId: "s1"), "cursor-internal-model");
      expect(fake.written.where((frame) => frame["method"] == "session/set_config_option"), isEmpty);
      await client.dispose();
    });

    test("applyTurnSelection does not push unknown effort", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: const PluginSessionVariant(id: "not-a-real-effort"),
        agent: "agent",
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await applying;

      final effortSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "effort");
      expect(effortSets, isEmpty, reason: "unknown effort is fail-closed");

      await client.dispose();
    });

    test("a default (null) model is re-applied when another model is active", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final selecting = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort
      await selecting;

      final defaulting = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sB",
        model: null,
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model=gpt-5.4
      await respond("session/set_config_option", const {}); // effort re-applied after model change
      await defaulting;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4"]);

      await client.dispose();
    });

    test("a session's null-model turn re-applies its own model, not the global default", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final a = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      );
      await respond("session/set_config_option", const {});
      await respond("session/set_config_option", const {});
      await a;

      final b = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sB",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "gpt-5.4"),
      ); // model
      await respond("session/set_config_option", const {}); // effort re-applied
      await b;

      final aAgain = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sA",
        model: null,
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      ); // model
      await respond("session/set_config_option", const {}); // effort re-applied
      await aAgain;

      final modelSets = fake.written
          .where((f) => f["method"] == "session/set_config_option")
          .map((f) => (f["params"] as Map).cast<String, dynamic>())
          .where((p) => p["configId"] == "model")
          .map((p) => p["value"])
          .toList();
      expect(modelSets, ["sonnet-4.6", "gpt-5.4", "sonnet-4.6"]);

      await client.dispose();
    });

    test("a rejected model switch stamps the model actually in effect", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final applying = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "s1",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      final modelFrame = await waitForFrame("session/set_config_option");
      fake.emit({
        "jsonrpc": "2.0",
        "id": modelFrame["id"],
        "error": {"code": -32000, "message": "rejected"},
      });
      await pump();
      await respond("session/set_config_option", const {}); // mode
      await respond("session/set_config_option", const {}); // effort
      await applying;

      expect(plugin.eventMapper.modelForSession(sessionId: "s1"), "gpt-5.4");

      await client.dispose();
    });

    test("a rejected switch does not inherit another session's model", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      final a = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sA",
        model: (providerID: "cursor", modelID: "sonnet-4.6"),
        variant: null,
        agent: null,
      );
      await respond(
        "session/set_config_option",
        effortModelSelectionResult(modelId: "sonnet-4.6"),
      );
      await respond("session/set_config_option", const {});
      await respond("session/set_config_option", const {});
      await a;

      final b = plugin.applyTurnSelection(
        configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
        sessionId: "sB",
        model: (providerID: "cursor", modelID: "gpt-5.4"),
        variant: null,
        agent: null,
      );
      final modelFrame = await waitForFrame("session/set_config_option");
      fake.emit({
        "jsonrpc": "2.0",
        "id": modelFrame["id"],
        "error": {"code": -32000, "message": "rejected"},
      });
      await pump();
      await b;

      expect(plugin.eventMapper.modelForSession(sessionId: "sB"), "gpt-5.4");

      await client.dispose();
    });

    test("onConnectionReset re-applies model+mode+effort after an agent respawn", () async {
      capture(catalogResult(), fromNewSession: true);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();

      Future<void> applyOnce() async {
        final applying = plugin.applyTurnSelection(
          configRepository: AcpSessionConfigRepository(api: AcpAgentApi(client: client)),
          sessionId: "s1",
          model: (providerID: "cursor", modelID: "sonnet-4.6"),
          variant: const PluginSessionVariant(id: "high"),
          agent: "plan",
        );
        await respond(
          "session/set_config_option",
          effortModelSelectionResult(modelId: "sonnet-4.6"),
        );
        await respond("session/set_config_option", const {});
        await respond("session/set_config_option", const {});
        await applying;
      }

      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(3),
      );

      plugin.onConnectionReset();

      await applyOnce();
      expect(
        fake.written.where((f) => f["method"] == "session/set_config_option"),
        hasLength(6),
        reason: "the applied-cache is cleared on reset, so the selection is re-pushed",
      );

      await client.dispose();
    });

    test("getProviders tolerates a malformed model option and derives a safe default", () async {
      capture({
        "sessionId": "s1",
        "configOptions": [
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
            ],
          },
          {
            "id": "model",
            "category": "model",
            "options": [
              {"value": 123, "name": "Bad"},
              {"value": "gpt-5.4", "name": "GPT-5.4"},
            ],
          },
        ],
      });
      final providers = await providersAfterWarmup();
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), ["gpt-5.4"]);
      expect(provider.defaultModelID, "gpt-5.4");
    });

    test("getProviders is empty before any session/catalog", () async {
      final providers = plugin.getProviders(projectId: "/repo");
      await respond("initialize", {
        "protocolVersion": 1,
        "agentCapabilities": <String, dynamic>{},
        "authMethods": <Object?>[],
      });
      await respond("cursor/list_available_models", const {"models": <Object?>[]});
      expect((await providers).providers, isEmpty);
    });

    test("a models-only capture surfaces effort variants once thought_level is captured", () async {
      capture(modelCatalog("gpt-5.4", includeMode: false), fromNewSession: true);
      capture(catalogResult(), fromNewSession: false);
      final full = await providersAfterWarmup();
      expect(full.providers.single.models.first.variants, ["high", "medium", "low"]);
    });

    test("a grouped model catalog surfaces every nested model", () async {
      capture({
        "sessionId": "s1",
        "configOptions": [
          {
            "id": "mode",
            "category": "mode",
            "currentValue": "agent",
            "options": [
              {"value": "agent", "name": "Agent"},
            ],
          },
          {
            "id": "model",
            "category": "model",
            "currentValue": "gpt-5.4",
            "options": [
              {
                "group": "openai",
                "name": "OpenAI",
                "options": [
                  {"value": "gpt-5.4", "name": "GPT-5.4"},
                ],
              },
              {
                "group": "anthropic",
                "name": "Anthropic",
                "options": [
                  {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
                ],
              },
            ],
          },
        ],
      }, fromNewSession: true);

      final providers = await providersAfterWarmup();
      final provider = providers.providers.single;
      expect(provider.models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(provider.defaultModelID, "gpt-5.4");
    });
  });

  // The catalog warm-up walk seeds a provisional effort scale before the first
  // turn so the composer's effort pill shows for a fresh session. Cursor only
  // reveals a model's effort for a model active in a session, so the bridge
  // `session/load`s recent sessions until a reasoning one is found. These drive
  // the real getProviders -> catalog service path end to end, so the isolated
  // catalog client spawns its own process — a fresh fake per spawn.
  group("CursorPlugin catalog warm-up", () {
    final fakes = <FakeAcpProcess>[];
    late CursorPlugin plugin;
    const cwd = "/repo";

    setUp(() {
      fakes.clear();
      plugin = CursorPlugin(
        launchDirectory: cwd,
        sessionCleanupService: _FakeCursorSessionCleanupService(),
        processFactory: (_) async {
          final fake = FakeAcpProcess();
          fakes.add(fake);
          return fake;
        },
      );
    });

    tearDown(() async {
      await plugin.dispose();
      for (final fake in fakes) {
        await fake.close();
      }
    });

    List<Map<String, dynamic>> allWritten() => [for (final fake in fakes) ...fake.written];

    Map<String, dynamic> listSession(String id, {required int updatedAt}) => {
      "sessionId": id,
      "cwd": cwd,
      "title": id,
      "updatedAt": updatedAt,
    };

    // A `session/load` result carrying Cursor's model + mode config, and — only
    // for a reasoning model — a multi-level effort `thought_level`.
    Map<String, dynamic> loadResult({
      required String currentModel,
      required bool reasoning,
    }) => {
      "sessionId": "ignored",
      "configOptions": [
        {
          "id": "mode",
          "category": "mode",
          "currentValue": "agent",
          "options": [
            {"value": "agent", "name": "Agent"},
            {"value": "plan", "name": "Plan"},
          ],
        },
        {
          "id": "model",
          "category": "model",
          "currentValue": currentModel,
          "options": [
            {"value": "gpt-5.4", "name": "GPT-5.4"},
            {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
          ],
        },
        if (reasoning)
          {
            "id": "effort",
            "category": "thought_level",
            "currentValue": "medium",
            "options": [
              {"value": "low", "name": "Low"},
              {"value": "medium", "name": "Medium"},
              {"value": "high", "name": "High"},
            ],
          },
      ],
    };

    /// Background agent answering initialize / session/list / session/load
    /// across every spawned fake until stopped.
    void Function() autoAnswer({
      required List<Map<String, dynamic>> listSessions,
      required Map<String, Map<String, dynamic>> loadResults,
      List<Map<String, dynamic>>? availableModels,
      Map<String?, List<Map<String, dynamic>>>? listSessionsByScope,
      bool rejectUnfiltered = false,
      List<String>? loadOrder,
      List<Map<String, dynamic>>? availableCommands,
    }) {
      final answered = <(FakeAcpProcess, Object?)>{};
      var running = true;
      unawaited(() async {
        while (running) {
          for (final fake in fakes.toList()) {
            for (final frame in fake.written.toList()) {
              final id = frame["id"];
              if (id == null || !answered.add((fake, id))) continue;
              final Map<String, dynamic> result;
              switch (frame["method"]) {
                case "initialize":
                  result = {
                    "protocolVersion": 1,
                    "agentCapabilities": {
                      "loadSession": true,
                      "sessionCapabilities": {"list": <String, dynamic>{}},
                    },
                    "authMethods": <Object?>[],
                  };
                case "cursor/list_available_models":
                  if (availableModels == null) {
                    fake.emit({
                      "jsonrpc": "2.0",
                      "id": id,
                      "error": {"code": -32601, "message": "method not found"},
                    });
                    continue;
                  }
                  result = {"models": availableModels};
                case "session/list":
                  final params = (frame["params"] as Map?)?.cast<String, dynamic>();
                  final listScope = params?["cwd"] as String?;
                  if (rejectUnfiltered && listScope == null) {
                    fake.emit({
                      "jsonrpc": "2.0",
                      "id": id,
                      "error": {"code": -32602, "message": "cwd is required"},
                    });
                    continue;
                  }
                  result = {
                    "sessions": listSessionsByScope?[listScope] ?? listSessions,
                  };
                case "session/load":
                  final sid = (frame["params"] as Map).cast<String, dynamic>()["sessionId"] as String;
                  loadOrder?.add(sid);
                  if (availableCommands != null) {
                    fake.emit({
                      "jsonrpc": "2.0",
                      "method": "session/update",
                      "params": {
                        "sessionId": sid,
                        "update": {
                          "sessionUpdate": "available_commands_update",
                          "availableCommands": availableCommands,
                        },
                      },
                    });
                    await Future<void>.delayed(Duration.zero);
                  }
                  result = loadResults[sid] ?? const {};
                default:
                  answered.remove((fake, id));
                  continue;
              }
              fake.emit({"jsonrpc": "2.0", "id": id, "result": result});
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());
      return () => running = false;
    }

    test("discovers commands while catalog sessions are loaded", () async {
      final stop = autoAnswer(
        listSessions: [listSession("session", updatedAt: 1000)],
        loadResults: {
          "session": loadResult(currentModel: "gpt-5.4", reasoning: true),
        },
        availableCommands: const [
          {"name": "review", "description": "Review changes"},
        ],
      );

      final commands = await plugin.getCommands(projectId: cwd);
      stop();

      expect(commands.map((command) => command.name), ["review", "compact"]);
    });

    test("discovers agents and models before the first Cursor session", () async {
      final stop = autoAnswer(
        listSessions: const [],
        loadResults: const {},
        availableModels: [
          {"value": "default", "name": "Auto"},
          {
            "value": "gpt-5.6-sol",
            "name": "GPT-5.6 Sol",
            "configOptions": [
              {
                "id": "reasoning",
                "name": "Reasoning",
                "category": "thought_level",
                "currentValue": "medium",
                "options": [
                  {"value": "none", "name": "None"},
                  {"value": "low", "name": "Low"},
                  {"value": "medium", "name": "Medium"},
                  {"value": "high", "name": "High"},
                ],
              },
            ],
          },
        ],
      );

      final providers = await plugin.getProviders(projectId: cwd);
      final agents = await plugin.getAgents(projectId: cwd);
      stop();

      expect(providers.providers.single.models.map((model) => model.id), ["gpt-5.6-sol", "default"]);
      expect(providers.providers.single.defaultModelID, "default");
      expect(
        providers.providers.single.models.last.defaultVariant,
        "medium",
      );
      expect(
        providers.providers.single.models.last.variants,
        ["high", "medium", "low", "none"],
      );
      expect(agents.map((agent) => agent.name), ["Agent", "Plan", "Ask"]);
      expect(
        allWritten().where((frame) => frame["method"] == "session/list"),
        isEmpty,
        reason: "account discovery does not require a historical session",
      );
      expect(
        allWritten().where((frame) => frame["method"] == "session/new"),
        isEmpty,
        reason: "catalog discovery must not create a throwaway session",
      );
    });

    test("seeds provisional effort when the newest session is non-reasoning but an older one is reasoning", () async {
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          listSession("s-new", updatedAt: 3000),
          listSession("s-old", updatedAt: 1000),
        ],
        loadResults: {
          // Newest session's model has no effort scale.
          "s-new": loadResult(currentModel: "gpt-5.4", reasoning: false),
          // Older session's model does.
          "s-old": loadResult(currentModel: "sonnet-4.6", reasoning: true),
        },
        loadOrder: loadOrder,
      );

      final providers = await plugin.getProviders(projectId: cwd);
      stop();

      expect(loadOrder, ["s-new", "s-old"], reason: "walked newest-first until the reasoning session seeded effort");
      final models = providers.providers.single.models;
      expect(models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(
        models.every((m) => m.variants.isNotEmpty),
        isTrue,
        reason: "every model shows the provisional effort scale so the pill renders",
      );
      // Default effort first, then the rest — the provisional scale from s-old.
      expect(models.first.variants, ["high", "medium", "low"]);
    });

    test("returns empty variants (no hang, no throwaway session) when no session is reasoning", () async {
      final loadOrder = <String>[];
      final stop = autoAnswer(
        listSessions: [
          listSession("s-new", updatedAt: 3000),
          listSession("s-old", updatedAt: 1000),
        ],
        loadResults: {
          "s-new": loadResult(currentModel: "gpt-5.4", reasoning: false),
          "s-old": loadResult(currentModel: "gpt-5.4", reasoning: false),
        },
        loadOrder: loadOrder,
      );

      final providers = await plugin.getProviders(projectId: cwd);

      final models = providers.providers.single.models;
      expect(models.map((m) => m.id), ["gpt-5.4", "sonnet-4.6"]);
      expect(
        models.every((m) => m.variants.isEmpty),
        isTrue,
        reason: "no reasoning session anywhere -> no effort scale to show",
      );
      expect(
        allWritten().where((f) => f["method"] == "session/new"),
        isEmpty,
        reason: "warm-up must never create a throwaway session",
      );
      expect(loadOrder, ["s-new", "s-old"], reason: "both sessions walked (under the bound), neither reasoning");

      // A second fetch must not re-walk: the scope's exhausted outcome prevents
      // another probe process from being spawned.
      final fakesAfterFirst = fakes.length;
      final again = await plugin.getProviders(projectId: cwd);
      stop();
      expect(again.providers.single.models.every((m) => m.variants.isEmpty), isTrue);
      expect(
        fakes.length,
        fakesAfterFirst,
        reason: "the exhausted outcome stops a re-walk and another process spawn",
      );
    });

    test("launch-scope exhaustion cannot suppress another project scope", () async {
      const projectScope = "/other-project";
      final stop = autoAnswer(
        listSessions: const [],
        listSessionsByScope: {
          cwd: const [],
          projectScope: [
            {
              "sessionId": "project-session",
              "cwd": projectScope,
              "title": "Project session",
              "updatedAt": 1000,
            },
          ],
        },
        rejectUnfiltered: true,
        loadResults: {
          "project-session": loadResult(
            currentModel: "sonnet-4.6",
            reasoning: true,
          ),
        },
      );

      await plugin.warmCatalog();
      final providers = await plugin.getProviders(projectId: projectScope);
      stop();

      expect(providers.providers.single.models, isNotEmpty);
      expect(
        allWritten()
            .where((frame) => frame["method"] == "session/list")
            .map((frame) => (frame["params"] as Map)["cwd"]),
        contains(projectScope),
      );
    });
  });
}

final class _PromptWriteCursorProcess({required final String sessionId, required final String toolCallId})
    implements AcpProcessHandle {
  static const taskRequestId = 700;

  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exit = Completer<int>();
  late final _PromptWriteCursorInput _stdin = _PromptWriteCursorInput(
    onFrame: (frame) {
      if (_emittedTaskFrames || frame["method"] != AcpMethods.sessionPrompt) return;
      _emittedTaskFrames = true;
      emit({
        "jsonrpc": "2.0",
        "method": AcpMethods.sessionUpdate,
        "params": {
          "sessionId": sessionId,
          "update": {
            "sessionUpdate": "tool_call",
            "toolCallId": toolCallId,
            "title": "Task: inspect",
            "status": "completed",
            "rawInput": {"_toolName": "task"},
            "rawOutput": {"isBackground": false},
          },
        },
      });
      emit({
        "jsonrpc": "2.0",
        "id": taskRequestId,
        "method": "cursor/task",
        "params": {
          "toolCallId": toolCallId,
          "description": "Inspect",
          "prompt": "Inspect code",
          "subagentType": {"custom": "unspecified"},
        },
      });
    },
  );
  var _emittedTaskFrames = false;
  var _stdoutTapped = false;
  var _stderrTapped = false;

  List<Map<String, dynamic>> get written => _stdin.frames;

  @override
  Stream<List<int>> get stdout {
    _stdoutTapped = true;
    return _stdout.stream;
  }

  @override
  Stream<List<int>> get stderr {
    _stderrTapped = true;
    return _stderr.stream;
  }

  @override
  IOSink get stdin => _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }

  void emit(Map<String, dynamic> message) {
    _stdout.add(utf8.encode("${jsonEncode(message)}\n"));
  }

  Future<void> close() async {
    if (!_stdoutTapped) _stdout.stream.listen(null);
    if (!_stderrTapped) _stderr.stream.listen(null);
    await _stdout.close();
    await _stderr.close();
  }
}

final class _PromptWriteCursorInput({required final void Function(Map<String, dynamic>) onFrame})
    extends CapturingIOSink {
  @override
  void add(List<int> data) {
    final priorLength = frames.length;
    super.add(data);
    frames.skip(priorLength).forEach(onFrame);
  }
}

class _FakeCursorSessionCleanupService() implements CursorSessionCleanupService {
  final List<String> deletedSessionIds = [];

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) async {
    deletedSessionIds.add(backendSessionId);
  }
}
