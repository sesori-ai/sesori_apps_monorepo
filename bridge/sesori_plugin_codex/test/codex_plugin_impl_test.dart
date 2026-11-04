// Tests for the codex plugin. Each helper that fires-and-forgets a
// response to the client's first request is intentionally not awaited — the
// pattern of "subscribe to the next outgoing frame, then push a reply" is
// what gives the test its determinism, and awaiting it would deadlock.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "support/codex_plugin_test_factory.dart";
import "support/stub_web_socket_channel.dart";

void main() {
  group("CodexPlugin", () {
    test("id returns codex", () {
      expect(CodexPlugin.pluginId, equals("codex"));
    });

    test("is bridge-derived: launchDirectory is the launch CWD and sessions enumerate from disk", () async {
      // codex is a BridgeDerivedProjectsPluginApi, so the bridge derives the
      // project list from listAllSessions/launchDirectory — the plugin has no
      // project members at all. Pin CODEX_HOME away from the user's real
      // history so the test is hermetic.
      final tempHome = Directory.systemTemp.createTempSync("codex-home-stub-");
      try {
        const serverUrl = "ws://127.0.0.1:0";
        final plugin = createInjectedCodexPlugin(
          serverUrl: serverUrl,
          environment: {"CODEX_HOME": tempHome.path},
          projectCwd: "/repo/example",
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl, channelFactory: null, onDisconnected: null),
          keepaliveInterval: const Duration(seconds: 30),
          toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
          runtimeExit: runningCodexRuntime,
        );
        expect(plugin.launchDirectory, equals("/repo/example"));
        expect(await plugin.listAllSessions(knownDirectories: const {}), isEmpty);
        await plugin.dispose();
      } finally {
        try {
          tempHome.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test("read methods return empty when no codex history exists", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-stub-");
      try {
        // Hermetic readers so the user's real ~/.codex/ doesn't leak into
        // this test.
        const serverUrl = "ws://127.0.0.1:0";
        final plugin = createInjectedCodexPlugin(
          serverUrl: serverUrl,
          environment: {"CODEX_HOME": tempHome.path},
          projectCwd: "/repo/example",
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl, channelFactory: null, onDisconnected: null),
          keepaliveInterval: const Duration(seconds: 30),
          toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
          runtimeExit: runningCodexRuntime,
        );
        expect(await plugin.getSessions(projectId: "/repo/example"), isEmpty);
        expect(await plugin.getSessionMessages("s-1"), isEmpty);
        expect(await plugin.getSessionStatuses(), isEmpty);
        expect(plugin.getActiveSessionsSummary(), isEmpty);
        // With no config, rollout history, or live connection, Codex exposes
        // only Default because Plan requires a resolved model.
        final agents = await plugin.getAgents(projectId: "/repo/example");
        expect(agents.map((agent) => agent.name), equals(["Agent"]));
        expect(agents.every((agent) => agent.model == null), isTrue);
        expect(
          (await plugin.getProviders(projectId: "/repo/example")).providers,
          isEmpty,
        );
        await plugin.dispose();
      } finally {
        try {
          tempHome.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test("getAgents/getProviders synthesise from config + the project's own latest rollout", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-syn-");
      try {
        File(p.join(tempHome.path, "config.toml")).writeAsStringSync('model = "gpt-5.5"\nmodel_provider = "openai"\n');
        // A rollout whose turn_context model differs from the global config
        // default — the per-session model must win.
        final rollout = File(
          p.join(
            tempHome.path,
            "sessions/2026/05/27/rollout-2026-05-27T10-00-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
          ),
        )..createSync(recursive: true);
        rollout.writeAsStringSync(
          "${jsonEncode({
            "type": "session_meta",
            "payload": {
              "id": "019a0000-1111-2222-3333-bbbbbbbbbbbb",
              "timestamp": "2026-05-27T10:00:00Z",
              "cwd": "/repo/example",
              "model_provider": "openai",
            },
          })}\n"
          "${jsonEncode({
            "type": "turn_context",
            "payload": {"model": "gpt-5.4-codex"},
          })}\n",
        );
        // A NEWER rollout in a different derived project — it must not leak
        // into /repo/example's defaults.
        final otherRollout = File(
          p.join(
            tempHome.path,
            "sessions/2026/05/28/rollout-2026-05-28T10-00-00-019a0000-1111-2222-3333-cccccccccccc.jsonl",
          ),
        )..createSync(recursive: true);
        otherRollout.writeAsStringSync(
          "${jsonEncode({
            "type": "session_meta",
            "payload": {
              "id": "019a0000-1111-2222-3333-cccccccccccc",
              "timestamp": "2026-05-28T10:00:00Z",
              "cwd": "/repo/other",
              "model_provider": "anthropic",
            },
          })}\n"
          "${jsonEncode({
            "type": "turn_context",
            "payload": {"model": "claude-x"},
          })}\n",
        );

        const serverUrl = "ws://127.0.0.1:0";
        final plugin = createInjectedCodexPlugin(
          serverUrl: serverUrl,
          environment: {"CODEX_HOME": tempHome.path},
          projectCwd: "/repo/example",
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl, channelFactory: null, onDisconnected: null),
          keepaliveInterval: const Duration(seconds: 30),
          toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
          runtimeExit: runningCodexRuntime,
        );

        final agents = await plugin.getAgents(projectId: "/repo/example");
        expect(agents.map((agent) => agent.name), equals(["Agent"]));
        final agent = agents.first;
        expect(agent.name, equals("Agent"));
        expect(agent.model?.modelID, equals("gpt-5.4-codex"));
        expect(agent.model?.providerID, equals("openai"));
        expect(agents.last.model, equals(agent.model));

        final providers = (await plugin.getProviders(projectId: "/repo/example")).providers;
        expect(providers.single.id, equals("openai"));
        expect(providers.single.defaultModelID, equals("gpt-5.4-codex"));

        // The other derived project resolves its own rollout's defaults.
        final otherAgent = (await plugin.getAgents(projectId: "/repo/other")).first;
        expect(otherAgent.model?.modelID, equals("claude-x"));
        expect(otherAgent.model?.providerID, equals("anthropic"));

        // A project with no sessions falls back to the global config.toml.
        final freshAgent = (await plugin.getAgents(projectId: "/repo/fresh")).first;
        expect(freshAgent.model?.modelID, equals("gpt-5.5"));
        expect(freshAgent.model?.providerID, equals("openai"));
        await plugin.dispose();
      } finally {
        try {
          tempHome.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test("initialize completes after a successful handshake", () async {
      final fake = _FakeWebSocket();
      final tempHome = Directory.systemTemp.createTempSync("codex-home-health-");
      addTearDown(() => tempHome.deleteSync(recursive: true));
      const serverUrl = "ws://127.0.0.1:0";
      final plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": tempHome.path},
        projectCwd: "/repo/example",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => fake.channel,
          onDisconnected: null,
        ),
        keepaliveInterval: const Duration(seconds: 30),
        toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
        runtimeExit: runningCodexRuntime,
      );

      // Auto-respond to the first request with a valid initialize response.
      fake.outgoing.first.then((Object? frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        expect(decoded["method"], equals("initialize"));
        final params = decoded["params"] as Map<String, dynamic>;
        final capabilities = params["capabilities"] as Map<String, dynamic>;
        expect(
          capabilities["experimentalApi"],
          isTrue,
        );
        fake.serverSink.add(
          jsonEncode({
            "jsonrpc": "2.0",
            "id": decoded["id"],
            "result": _initOk,
          }),
        );
      });

      await plugin.initialize();
      await plugin.dispose();
    });

    test("initialize throws when the handshake errors", () async {
      final fake = _FakeWebSocket();
      final tempHome = Directory.systemTemp.createTempSync("codex-home-health-");
      addTearDown(() => tempHome.deleteSync(recursive: true));
      const serverUrl = "ws://127.0.0.1:0";
      final plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": tempHome.path},
        projectCwd: "/repo/example",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => fake.channel,
          onDisconnected: null,
        ),
        keepaliveInterval: const Duration(seconds: 30),
        toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
        runtimeExit: runningCodexRuntime,
      );

      fake.outgoing.first.then((Object? frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        fake.serverSink.add(
          jsonEncode({
            "jsonrpc": "2.0",
            "id": decoded["id"],
            "error": {"code": -32000, "message": "handshake refused"},
          }),
        );
      });

      await expectLater(plugin.initialize(), throwsStateError);
      await plugin.dispose();
    });

    test("an unexpected transport drop clears live session activity", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final socketReady = Completer<WebSocket>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socketReady.complete(socket);
        socket.listen((frame) {
          final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
          if (decoded["method"] != "initialize") return;
          socket.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": decoded["id"],
              "result": _initOk,
            }),
          );
        });
      });
      final plugin = createInjectedCodexPlugin(
        serverUrl: "ws://127.0.0.1:${server.port}",
        environment: const {},
        projectCwd: "/repo/example",
        clientFactory: null,
        keepaliveInterval: const Duration(seconds: 30),
        toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
        // An exited process leaves the drop idle instead of reconnecting.
        runtimeExit: exitedCodexRuntime,
      );
      addTearDown(plugin.dispose);
      final firstSummary = Completer<void>();
      final approvalSummary = Completer<void>();
      var invalidations = 0;
      final subscription = plugin.events.listen((event) {
        if (event is! BridgeSseProjectUpdated) return;
        invalidations++;
        if (invalidations == 1) firstSummary.complete();
        if (invalidations == 2) approvalSummary.complete();
      });
      addTearDown(subscription.cancel);

      await plugin.initialize();
      final socket = await socketReady.future;
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "thread/started",
          "params": {
            "thread": {
              "id": "t-running",
              "cwd": "/repo/example",
              "createdAt": 1700000000,
              "updatedAt": 1700000000,
            },
          },
        }),
      );
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "turn/started",
          "params": {
            "threadId": "t-running",
            "turn": {"id": "turn-1", "startedAt": 1700000001},
          },
        }),
      );
      await firstSummary.future.timeout(const Duration(seconds: 2));
      expect(plugin.getActiveSessionsSummary(), isNotEmpty);
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "id": 99,
          "method": "item/commandExecution/requestApproval",
          "params": {
            "threadId": "t-running",
            "turnId": "turn-1",
            "itemId": "item-1",
            "command": "ls",
          },
        }),
      );
      await approvalSummary.future.timeout(const Duration(seconds: 2));
      final pending = await plugin.getPendingPermissions(sessionId: "t-running");
      expect(pending, hasLength(1));

      final completed = plugin.events
          .where((event) => event is BridgeSseSessionIdle)
          .cast<BridgeSseSessionIdle>()
          .first;
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "turn/completed",
          "params": {
            "threadId": "t-running",
            "turn": {"id": "turn-1", "status": "completed"},
          },
        }),
      );
      expect((await completed.timeout(const Duration(seconds: 2))).sessionID, "t-running");
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      await plugin.replyToPermission(
        requestId: pending.single.id,
        sessionId: "t-running",
        reply: PluginPermissionReply.once,
      );
      await idle.timeout(const Duration(seconds: 2));
      expect(plugin.currentWorkState, PluginWorkState.idle);

      final busyAgain = plugin.workState.firstWhere((state) => state == PluginWorkState.busy);
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "turn/started",
          "params": {
            "threadId": "t-running",
            "turn": {"id": "turn-2", "startedAt": 1700000002},
          },
        }),
      );
      await busyAgain.timeout(const Duration(seconds: 2));

      // Leave a prompt outstanding so teardown emits its clearing event, whose
      // work-state sync must not overwrite the disconnect's `unknown`.
      final secondAsk = plugin.events.where((event) => event is BridgeSsePermissionAsked).first;
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "id": 100,
          "method": "item/commandExecution/requestApproval",
          "params": {
            "threadId": "t-running",
            "turnId": "turn-2",
            "itemId": "item-2",
            "command": "ls -la",
          },
        }),
      );
      await secondAsk.timeout(const Duration(seconds: 2));

      final asyncAsk = plugin.events.where((event) => event is BridgeSseQuestionAsked).first;
      socket.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "item/completed",
          "params": {
            "threadId": "t-running",
            "item": {
              "type": "agentMessage",
              "id": "async-question",
              "text": "Which interface?",
              "delivery": "async",
              "questions": [
                {
                  "title": "Which interface?",
                  "options": ["CLI", "Desktop"],
                },
              ],
            },
          },
        }),
      );
      await asyncAsk.timeout(const Duration(seconds: 2));
      expect(await plugin.getPendingQuestions(sessionId: "t-running"), hasLength(1));

      final disconnectWorkStates = <PluginWorkState>[];
      final workStateSubscription = plugin.workState.listen(disconnectWorkStates.add);
      addTearDown(workStateSubscription.cancel);
      await pumpEventQueue();
      disconnectWorkStates.clear();

      final disconnected = plugin.events
          .where((event) => event is BridgeSseSessionIdle)
          .cast<BridgeSseSessionIdle>()
          .first;
      await socket.close(WebSocketStatus.goingAway);

      expect(
        (await disconnected.timeout(const Duration(seconds: 2))).sessionID,
        "t-running",
      );
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(await plugin.getPendingQuestions(sessionId: "t-running"), isEmpty);
      expect(
        await plugin.getPendingPermissions(sessionId: "t-running"),
        isEmpty,
      );
      await pumpEventQueue();
      expect(plugin.currentWorkState, PluginWorkState.unknown);
      expect(disconnectWorkStates, isNot(contains(PluginWorkState.idle)));
    });

    test("a socket drop mid-turn reconnects at once and restores busy while the turn runs", () async {
      final codexHome = Directory.systemTemp.createTempSync("codex-home-reconnect-");
      addTearDown(() => codexHome.delete(recursive: true));
      final (:plugin, :connectionCount) = await _dropMidTurn(
        threadIds: const ["t-running"],
        codexHome: codexHome.path,
        reply: ({required connection, required method, required threadId, required socket}) {
          // The first reconnect drops again before answering its resume.
          if (connection == 2 && method == "thread/resume") {
            unawaited(socket.close(WebSocketStatus.goingAway));
            return null;
          }
          return _resumeReply(method: method, threadId: threadId, turnStatus: "inProgress");
        },
      );
      final workStates = <PluginWorkState>[];
      final workStateSubscription = plugin.workState.listen(workStates.add);
      addTearDown(workStateSubscription.cancel);

      // No further call: the drops themselves reconnect, and the session that
      // missed its resume is resumed on the next connection.
      final restored = await plugin.events
          .where((event) => event is BridgeSseSessionStatus)
          .cast<BridgeSseSessionStatus>()
          .first
          .timeout(const Duration(seconds: 2));
      expect(connectionCount(), 3);
      expect(restored.sessionID, "t-running");
      expect(restored.status, isA<PluginSessionStatusBusy>());
      expect((await plugin.getSessionStatuses())["t-running"], isA<PluginSessionStatusBusy>());
      expect(plugin.currentWorkState, PluginWorkState.busy);
      // The cut-off resume never reports a running turn as idle work.
      expect(workStates, isNot(contains(PluginWorkState.idle)));
    });

    test("a drop during the reconnect's handshake leaves the session for the next request", () async {
      final codexHome = Directory.systemTemp.createTempSync("codex-home-reconnect-");
      addTearDown(() => codexHome.delete(recursive: true));
      final (:plugin, :connectionCount) = await _dropMidTurn(
        threadIds: const ["t-running"],
        codexHome: codexHome.path,
        reply: ({required connection, required method, required threadId, required socket}) {
          if (connection == 2) {
            unawaited(socket.close(WebSocketStatus.goingAway));
            return null;
          }
          return _resumeReply(method: method, threadId: threadId, turnStatus: "inProgress");
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(connectionCount(), 2);
      expect(plugin.currentWorkState, PluginWorkState.unknown);
    });

    test("a resume that fails on a live connection releases the work state", () async {
      final codexHome = Directory.systemTemp.createTempSync("codex-home-reconnect-");
      addTearDown(() => codexHome.delete(recursive: true));
      final (:plugin, connectionCount: _) = await _dropMidTurn(
        threadIds: const ["t-running"],
        codexHome: codexHome.path,
        reply: ({required connection, required method, required threadId, required socket}) =>
            connection == 2 && method == "thread/resume"
            ? const {
                "error": {"code": -32600, "message": "thread not found"},
              }
            : _resumeReply(method: method, threadId: threadId, turnStatus: "inProgress"),
      );

      await plugin.workState.firstWhere((state) => state == PluginWorkState.idle).timeout(const Duration(seconds: 2));
      expect((await plugin.getSessionStatuses())["t-running"], isNot(isA<PluginSessionStatusBusy>()));
    });

    test("a session resumed idle keeps the work state unknown while another resume is pending", () async {
      final codexHome = Directory.systemTemp.createTempSync("codex-home-reconnect-");
      addTearDown(() => codexHome.delete(recursive: true));
      final runningResume = Completer<void>();
      final (:plugin, connectionCount: _) = await _dropMidTurn(
        threadIds: const ["t-done", "t-running"],
        codexHome: codexHome.path,
        reply: ({required connection, required method, required threadId, required socket}) async {
          // The running session's resume answers only once released.
          if (connection == 2 && threadId == "t-running") await runningResume.future;
          final turnStatus = threadId == "t-done" ? "completed" : "inProgress";
          return _resumeReply(method: method, threadId: threadId, turnStatus: turnStatus);
        },
      );
      final workStates = <PluginWorkState>[];
      final workStateSubscription = plugin.workState.listen(workStates.add);
      addTearDown(workStateSubscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect((await plugin.getSessionStatuses())["t-done"], isA<PluginSessionStatusIdle>());
      expect(plugin.currentWorkState, PluginWorkState.unknown);
      final restored = plugin.events.where((event) => event is BridgeSseSessionStatus).first;
      runningResume.complete();
      await restored.timeout(const Duration(seconds: 2));
      expect(plugin.currentWorkState, PluginWorkState.busy);
      expect(workStates, isNot(contains(PluginWorkState.idle)));
    });

    test("a turn that ends during a socket drop sends its final reply after the reconnect", () async {
      const threadId = "019a0000-1111-2222-3333-dddddddddddd";
      final codexHome = Directory.systemTemp.createTempSync("codex-home-reconnect-");
      addTearDown(() => codexHome.delete(recursive: true));
      String record({required String role, required String text}) => jsonEncode({
        "type": "response_item",
        "payload": {
          "type": "message",
          "role": role,
          "content": [
            {"type": role == "user" ? "input_text" : "output_text", "text": text},
          ],
        },
      });
      Directory(p.join(codexHome.path, "sessions")).createSync();
      File(p.join(codexHome.path, "sessions", "rollout-2026-11-03T10-00-00-$threadId.jsonl")).writeAsStringSync(
        [
          jsonEncode({
            "type": "session_meta",
            "payload": {"id": threadId, "cwd": "/repo/example"},
          }),
          record(role: "user", text: "Fix it."),
          record(role: "assistant", text: "Fixed while you were away."),
        ].join("\n"),
      );
      final (:plugin, connectionCount: _) = await _dropMidTurn(
        threadIds: const [threadId],
        codexHome: codexHome.path,
        reply: ({required connection, required method, required threadId, required socket}) =>
            _resumeReply(method: method, threadId: threadId, turnStatus: "completed"),
      );

      final replyPart = await plugin.events
          .where((event) => event is BridgeSseMessagePartUpdated)
          .cast<BridgeSseMessagePartUpdated>()
          .first
          .timeout(const Duration(seconds: 2));
      expect(
        replyPart.part,
        isA<PluginMessagePartText>().having((text) => text.text, "text", "Fixed while you were away."),
      );
      expect((await plugin.getSessionStatuses())[threadId], isA<PluginSessionStatusIdle>());
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("disconnect idles a provisional resumed child and its hydrated root", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-disconnect-");
      addTearDown(() => tempHome.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final socketReady = Completer<WebSocket>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socketReady.complete(socket);
        socket.listen((frame) {
          final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
          final result = switch (decoded["method"]) {
            "initialize" => _initOk,
            "thread/resume" => const {
              "model": "gpt-5.4-mini",
              "modelProvider": "openai",
              "thread": {
                "id": "child-1",
                "parentThreadId": "root-1",
                "threadSource": "subAgent",
              },
            },
            "turn/start" => const {
              "turn": {"id": "child-turn"},
            },
            _ => null,
          };
          if (result == null) return;
          socket.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": decoded["id"],
              "result": result,
            }),
          );
        });
      });
      final plugin = createInjectedCodexPlugin(
        serverUrl: "ws://127.0.0.1:${server.port}",
        environment: {"CODEX_HOME": tempHome.path},
        projectCwd: "/repo/example",
        clientFactory: null,
        keepaliveInterval: const Duration(seconds: 30),
        toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
        runtimeExit: exitedCodexRuntime,
      );
      addTearDown(plugin.dispose);
      final idleSessionIds = <String>{};
      final bothIdle = Completer<void>();
      final subscription = plugin.events.listen((event) {
        if (event case BridgeSseSessionIdle(:final sessionID)) {
          idleSessionIds.add(sessionID);
          if (idleSessionIds.containsAll(const {"child-1", "root-1"}) && !bothIdle.isCompleted) {
            bothIdle.complete();
          }
        }
      });
      addTearDown(subscription.cancel);

      await plugin.initialize();
      final socket = await socketReady.future;
      await plugin.sendPrompt(
        fastMode: false,
        sessionId: "child-1",
        promptId: "prompt-1",
        parts: const [PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );
      final statuses = await plugin.getSessionStatuses();
      expect(statuses["child-1"], isA<PluginSessionStatusBusy>());
      expect(statuses["root-1"], isA<PluginSessionStatusBusy>());

      await socket.close(WebSocketStatus.goingAway);
      await bothIdle.future.timeout(const Duration(seconds: 2));

      expect(idleSessionIds, {"child-1", "root-1"});
      expect(await plugin.getSessionStatuses(), isEmpty);
      expect(plugin.currentWorkState, PluginWorkState.unknown);
    });

    test("dispose closes event buffer without error", () async {
      final plugin = createInjectedCodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        environment: const {},
        projectCwd: Directory.current.path,
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: null,
          onDisconnected: null,
        ),
        keepaliveInterval: const Duration(seconds: 30),
        toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
        runtimeExit: runningCodexRuntime,
      );
      await expectLater(plugin.dispose(), completes);
    });
  });

  group("CodexAppServerClient", () {
    test("request demultiplexes responses by id", () async {
      final fake = _FakeWebSocket();
      final client = CodexAppServerClient(
        serverUrl: "ws://127.0.0.1:0",
        channelFactory: (_) => fake.channel,
        onDisconnected: null,
      );

      // Echo every request back with a result derived from method name. The
      // initialize handshake is just the first request to come through.
      var handshakeDone = false;
      fake.outgoing.listen((Object? frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        if (!handshakeDone) {
          handshakeDone = true;
          fake.serverSink.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": decoded["id"],
              "result": _initOk,
            }),
          );
          return;
        }
        fake.serverSink.add(
          jsonEncode({
            "jsonrpc": "2.0",
            "id": decoded["id"],
            "result": {"echo": decoded["method"]},
          }),
        );
      });
      await client.connect();

      final results = await Future.wait([
        client.request(method: "thread/list", params: null, timeout: codexRequestTimeout),
        client.request(method: "skills/list", params: null, timeout: codexRequestTimeout),
      ]);
      expect(results[0], equals({"echo": "thread/list"}));
      expect(results[1], equals({"echo": "skills/list"}));
      await client.dispose();
    });

    test("notifications stream emits server-pushed events", () async {
      final fake = _FakeWebSocket();
      final client = CodexAppServerClient(
        serverUrl: "ws://127.0.0.1:0",
        channelFactory: (_) => fake.channel,
        onDisconnected: null,
      );

      fake.outgoing.first.then((Object? frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        fake.serverSink.add(
          jsonEncode({
            "jsonrpc": "2.0",
            "id": decoded["id"],
            "result": _initOk,
          }),
        );
      });
      await client.connect();

      final notif = client.notifications.first;
      fake.serverSink.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "method": "thread/started",
          "params": {"threadId": "t-1"},
        }),
      );
      final received = await notif;
      expect(received.method, equals("thread/started"));
      expect(received.params["threadId"], equals("t-1"));
      await client.dispose();
    });
  });
}

const Map<String, dynamic> _initOk = {
  "userAgent": "codex-cli/0.121.0",
  "codexHome": "/Users/test/.codex",
  "platformOs": "macos",
  "platformFamily": "unix",
};

/// Runs a turn on each of [threadIds] against a loopback app-server, then
/// drops that first connection mid-turn and returns once the drop idled them.
/// [reply] answers each request on the numbered connection, given the thread
/// it names, with a JSON-RPC result or error body, or null to stay silent; it
/// may close the socket.
Future<({CodexPlugin plugin, int Function() connectionCount})> _dropMidTurn({
  required List<String> threadIds,
  required String codexHome,
  required FutureOr<Map<String, Object?>?> Function({
    required int connection,
    required String method,
    required String? threadId,
    required WebSocket socket,
  })
  reply,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  final firstSocket = Completer<WebSocket>();
  var connectionCount = 0;
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final connection = ++connectionCount;
    if (connection == 1) firstSocket.complete(socket);
    socket.listen((frame) async {
      final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
      final body = await reply(
        connection: connection,
        method: decoded["method"] as String,
        threadId: (decoded["params"] as Map<String, dynamic>?)?["threadId"] as String?,
        socket: socket,
      );
      if (body != null) socket.add(jsonEncode({"jsonrpc": "2.0", "id": decoded["id"], ...body}));
    });
  });
  final plugin = createInjectedCodexPlugin(
    serverUrl: "ws://127.0.0.1:${server.port}",
    environment: {"CODEX_HOME": codexHome},
    projectCwd: "/repo/example",
    clientFactory: null,
    keepaliveInterval: const Duration(seconds: 30),
    toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
    runtimeExit: runningCodexRuntime,
  );
  addTearDown(plugin.dispose);

  await plugin.initialize();
  final socket = await firstSocket.future;
  final busy = plugin.events.where((event) => event is BridgeSseSessionStatus).take(threadIds.length).drain<void>();
  for (final threadId in threadIds) {
    socket.add(
      jsonEncode({
        "jsonrpc": "2.0",
        "method": "turn/started",
        "params": {
          "threadId": threadId,
          "turn": {"id": "turn-1"},
        },
      }),
    );
  }
  await busy.timeout(const Duration(seconds: 2));
  final idled = plugin.events.where((event) => event is BridgeSseSessionIdle).take(threadIds.length).drain<void>();
  await socket.close(WebSocketStatus.goingAway);
  await idled.timeout(const Duration(seconds: 2));
  return (plugin: plugin, connectionCount: () => connectionCount);
}

/// Answers `initialize`, and `thread/resume` of [threadId] with one turn in
/// [turnStatus].
Map<String, Object?>? _resumeReply({required String method, required String? threadId, required String turnStatus}) =>
    switch (method) {
      "initialize" => const {"result": _initOk},
      "thread/resume" => {
        "result": {
          "thread": {
            "id": threadId,
            "cwd": "/repo/example",
            "turns": [
              {"id": "turn-1", "status": turnStatus},
            ],
          },
        },
      },
      _ => null,
    };

/// Minimal bidirectional channel for in-memory WebSocket testing.
///
/// Mirrors the surface used by [CodexAppServerClient]:
///   - `channel.stream`   → frames sent from server to client.
///   - `channel.sink.add` → frames sent from client to server.
///
/// Tests can subscribe to [outgoing] to see what the client sent and respond
/// on [serverSink].
class _FakeWebSocket() {
  this {
    _clientToServer = StreamController<Object?>.broadcast();
    _serverToClient = StreamController<Object?>.broadcast();
    channel = StubWebSocketChannel(
      stream: _serverToClient.stream,
      sink: ControllerWebSocketSink(controller: _clientToServer),
    );
  }

  late final StreamController<Object?> _clientToServer;
  late final StreamController<Object?> _serverToClient;
  late final WebSocketChannel channel;

  Stream<Object?> get outgoing => _clientToServer.stream;
  Sink<Object?> get serverSink => ControllerWebSocketSink(controller: _serverToClient);
}
