// Phase 4 write-path integration tests: createSession, sendPrompt,
// abortSession round-trip against an in-memory fake WS, plus the
// notification → BridgeSseEvent pipeline.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable, prefer_foreach, avoid_dynamic_calls

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  group("CodexPlugin write path", () {
    late Directory codexHome;
    late _FakeAppServer fake;
    late CodexPlugin plugin;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-write-");
      fake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      plugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => fake.channel,
        ),
        keepaliveInterval: const Duration(seconds: 30),
      );
    });

    tearDown(() async {
      await plugin.dispose();
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
    });

    test("createSession round-trips thread/start and turn/start", () async {
      // Respond to: initialize, thread/start, turn/start.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-new",
              "cwd": "/work/sample",
              "createdAt": 1700000000,
              "updatedAt": 1700000005,
              "name": null,
            },
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      final session = await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "hello codex")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(session.id, equals("t-new"));
      expect(session.directory, equals("/work/sample"));
      expect(session.projectID, equals("/work/sample"));

      // Inspect sent frames.
      final methods = fake.sentMethods;
      expect(methods, equals(["initialize", "thread/start", "turn/start"]));
      final turnStartParams = fake.sentParamsFor("turn/start");
      expect(turnStartParams["threadId"], equals("t-new"));
      expect((turnStartParams["input"] as List).first["text"], equals("hello codex"));
    });

    test("lists skills, invokes them with dollar syntax, and compacts natively", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "cwd": "/work/sample",
                "skills": [
                  {
                    "name": "review",
                    "description": "Review changes",
                    "shortDescription": null,
                    "interface": null,
                    "enabled": true,
                  },
                ],
              },
            ],
          },
        ),
        const _Response(
          result: {
            "thread": {"id": "t-existing", "cwd": "/work/sample"},
            "model": "gpt-5.4",
          },
        ),
        const _Response(result: {"turnId": "u-skill"}),
        const _Response(result: {}),
      ]);

      final commands = await plugin.getCommands(projectId: "/work/sample");
      await plugin.sendCommand(
        sessionId: "t-existing",
        command: "review",
        arguments: "staged changes",
        userVisibleArguments: "staged changes",
        variant: null,
        agent: "Plan",
        model: null,
      );
      await plugin.sendCommand(
        sessionId: "t-existing",
        command: "compact",
        arguments: "",
        userVisibleArguments: null,
        variant: null,
        agent: null,
        model: null,
      );

      expect(commands.map((command) => command.name), ["review", "compact"]);
      expect(fake.sentMethods, [
        "initialize",
        "skills/list",
        "thread/resume",
        "turn/start",
        "thread/compact/start",
      ]);
      expect(fake.sentParamsFor("skills/list"), {
        "cwds": ["/work/sample"],
      });
      final input = fake.sentParamsFor("turn/start")["input"] as List;
      expect(input.single["text"], r"$review staged changes");
      expect(fake.sentParamsFor("turn/start")["collaborationMode"], {
        "mode": "plan",
        "settings": {
          "model": "gpt-5.4",
          "reasoning_effort": "medium",
          "developer_instructions": null,
        },
      });
    });

    test("a live event emitted during the first turn is scoped to the new session's directory", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-live",
              "cwd": "/other/proj",
              "createdAt": 1700000000,
              "updatedAt": 1700000000,
              "name": null,
            },
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);
      // codex can emit a cwd-less notification while turn/start is still in
      // flight and before any rollout exists on disk — the thread directory
      // must already be recorded so the event maps to the session's real
      // project instead of the launch cwd.
      fake.onRequest = (method) {
        if (method == "turn/start") {
          fake.pushNotification("thread/name/updated", {
            "threadId": "t-live",
            "threadName": "First title",
          });
        }
      };
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.createSession(
        directory: "/other/proj",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "go")],
        variant: null,
        agent: null,
        model: null,
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      final updated = events.whereType<BridgeSseSessionUpdated>().single;
      expect(updated.info["projectID"], equals("/other/proj"));
    });

    test("renameSession keeps a fresh non-launch session on its own project before the rollout is flushed", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {
              "id": "t-sub",
              "cwd": "/work/sample/packages/core",
              "createdAt": 1700000000,
              "updatedAt": 1700000000,
              "name": null,
            },
          },
        ),
        const _Response(result: {}),
      ]);

      final created = await plugin.createSession(
        directory: "/work/sample/packages/core",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      expect(created.projectID, equals("/work/sample/packages/core"));

      // codexHome is empty — no rollout has been flushed — yet the rename
      // response must still attribute the session to its real project rather
      // than the launch cwd, proving the in-memory thread→directory map is
      // consulted before the disk rollout.
      final renamed = await plugin.renameSession(sessionId: "t-sub", title: "Renamed");
      expect(renamed.projectID, equals("/work/sample/packages/core"));
      expect(renamed.directory, equals("/work/sample/packages/core"));
    });

    test("renameSession retries beyond the initial rollout flush window", () async {
      const emptyRolloutResponse = _Response(
        error: {
          "code": -32603,
          "message":
              "failed to set thread name: Fatal error: failed to update thread metadata "
              "t-empty-rollout: thread-store internal error: failed to read session metadata "
              "/tmp/rollout-t-empty-rollout.jsonl: rollout at "
              "/tmp/rollout-t-empty-rollout.jsonl is empty",
        },
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-empty-rollout"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        emptyRolloutResponse,
        const _Response(result: {}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "start")],
        variant: null,
        agent: null,
        model: null,
      );
      final renamed = await plugin.renameSession(
        sessionId: "t-empty-rollout",
        title: "Renamed",
      );

      expect(renamed.title, equals("Renamed"));
      expect(fake.sentMethods.where((method) => method == "thread/name/set"), hasLength(7));
    });

    test("renameSession does not retry unrelated RPC failures", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          error: {
            "code": -32603,
            "message": "failed to set thread name: state database is unavailable",
          },
        ),
        const _Response(result: {}),
      ]);

      await expectLater(
        plugin.renameSession(sessionId: "t-failed", title: "Renamed"),
        throwsA(
          isA<CodexRpcException>().having(
            (error) => error.message,
            "message",
            contains("state database is unavailable"),
          ),
        ),
      );

      expect(fake.sentMethods.where((method) => method == "thread/name/set"), hasLength(1));
    });

    test("renameSession bounds a stalled retry by the rollout deadline", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          error: {
            "code": -32603,
            "message":
                "failed to read session metadata /tmp/rollout.jsonl: "
                "rollout at /tmp/rollout.jsonl is empty",
          },
        ),
        const _Response(respond: false),
      ]);
      final stopwatch = Stopwatch()..start();

      await expectLater(
        plugin.renameSession(sessionId: "t-stalled", title: "Renamed").timeout(const Duration(seconds: 4)),
        throwsA(isA<TimeoutException>()),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test("sendPrompt resumes a thread from a prior run before the turn", () async {
      // `t-existing` was never started in this plugin instance, so the
      // app-server has not loaded it — the plugin must resume it on demand
      // before turn/start, or codex would answer "thread not found".
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-existing"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-existing",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );

      final methods = fake.sentMethods;
      expect(methods, equals(["initialize", "thread/resume", "turn/start"]));
      expect(fake.sentParamsFor("thread/resume")["threadId"], equals("t-existing"));
      expect(fake.sentParamsFor("turn/start")["threadId"], equals("t-existing"));
    });

    test("sendPrompt sends Default mode explicitly so it replaces Plan mode", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.4-mini",
            "modelProvider": "openai",
            "thread": {"id": "t-default-mode"},
          },
        ),
        const _Response(result: {"turnId": "u-default"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-default-mode",
        parts: const [PluginPromptPart.text(text: "implement it")],
        variant: null,
        agent: "Default",
        model: null,
      );

      final params = fake.sentParamsFor("turn/start");
      expect(params.containsKey("model"), isFalse);
      expect(params.containsKey("effort"), isFalse);
      expect(params["collaborationMode"], {
        "mode": "default",
        "settings": {
          "model": "gpt-5.4-mini",
          "reasoning_effort": null,
          "developer_instructions": null,
        },
      });
    });

    test("sendPrompt does not re-resume a thread created in this run", () async {
      // createSession (no parts) loads the thread; a follow-up turn must reuse
      // it without a redundant resume round-trip.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-fresh"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        sessionId: "t-fresh",
        parts: const [PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentMethods, isNot(contains("thread/resume")));
    });

    test("turn/start 'thread not found' triggers a resume and one retry", () async {
      // A thread the plugin believes is loaded but the app-server has dropped:
      // the first turn/start fails, then resume + retry must recover it.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-dropped"},
          },
        ),
        const _Response(error: {"code": -32600, "message": "thread not found"}),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-dropped"},
          },
        ),
        const _Response(result: {"turnId": "u-2"}),
      ]);

      // createSession with no parts marks t-dropped as loaded.
      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
      );
      await plugin.sendPrompt(
        sessionId: "t-dropped",
        parts: const [PluginPromptPart.text(text: "are you there")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(
        fake.sentMethods,
        equals(["initialize", "thread/start", "turn/start", "thread/resume", "turn/start"]),
      );
    });

    test("abortSession calls turn/interrupt on the active turn", () async {
      // First the connection + a sendPrompt that triggers turn/started
      // notification, so the plugin knows the turn id to abort. `t-1` is
      // unknown to this run, so the prompt resumes it before the turn.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-1"},
          },
        ),
        const _Response(result: {"turnId": "u-active"}),
        const _Response(result: null),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-1",
        parts: const [PluginPromptPart.text(text: "long task")],
        variant: null,
        agent: null,
        model: null,
      );

      // Simulate codex emitting turn/started so the plugin captures the turn id.
      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-active"},
      });
      // Give the event subscription a microtask to process.
      await Future<void>.delayed(Duration.zero);

      await plugin.abortSession(sessionId: "t-1");

      expect(fake.sentMethods, contains("turn/interrupt"));
      final params = fake.sentParamsFor("turn/interrupt");
      expect(params["threadId"], equals("t-1"));
      expect(params["turnId"], equals("u-active"));
    });

    test("notification stream is mapped into bridge events", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);

      // Subscribe BEFORE the connection so buffered events flow.
      final events = <BridgeSseEvent>[];
      final terminalActivityUpdate = Completer<void>();
      var projectUpdates = 0;
      final subscription = plugin.events.listen((event) {
        events.add(event);
        if (event is BridgeSseProjectUpdated) {
          projectUpdates++;
          if (projectUpdates == 2) terminalActivityUpdate.complete();
        }
      });

      // Trigger _ensureConnected.
      await plugin.healthCheck();

      fake.pushNotification("thread/started", {
        "thread": {
          "id": "t-1",
          "cwd": "/work/sample",
          "createdAt": 1700000000,
          "updatedAt": 1700000000,
        },
      });
      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-1", "startedAt": 1700000005},
      });
      await Future<void>.delayed(Duration.zero);

      final running = plugin.getActiveSessionsSummary();
      expect(running, hasLength(1));
      expect(running.single.id, "/work/sample");
      expect(running.single.activeSessions.single.id, "t-1");
      expect(running.single.activeSessions.single.mainAgentRunning, isTrue);

      fake.pushNotification("item/agentMessage/delta", {
        "threadId": "t-1",
        "turnId": "u-1",
        "itemId": "i-1",
        "delta": "Hi",
      });
      fake.pushNotification("turn/completed", {
        "threadId": "t-1",
        "turn": {"id": "u-1", "completedAt": 1700000010},
      });

      // A terminal notification may briefly wait for Codex to create/finish
      // its rollout file. Await the activity invalidation emitted after idle
      // instead of assuming the ordered async event pipeline is synchronous.
      await terminalActivityUpdate.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(
        events.map((e) => e.runtimeType.toString()).toList(),
        containsAllInOrder([
          "BridgeSseSessionUpdated",
          "BridgeSseSessionStatus",
          "BridgeSseProjectUpdated",
          "BridgeSseMessagePartDelta",
          "BridgeSseSessionUpdated",
          "BridgeSseSessionIdle",
          "BridgeSseProjectUpdated",
        ]),
      );

      // Active session status is tracked from the notifications.
      final statuses = await plugin.getSessionStatuses();
      expect(statuses["t-1"], isA<PluginSessionStatusIdle>());
      expect(plugin.getActiveSessionsSummary(), isEmpty);
    });

    test("live rollout tools converge exactly with reloaded history", () async {
      const sessionId = "019a0000-1111-2222-3333-aaaaaaaaaaaa";
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/07/23/"
          "rollout-2026-07-23T08-00-00-$sessionId.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "timestamp": "2026-07-23T08:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": sessionId,
            "timestamp": "2026-07-23T08:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
            "cli_version": "0.144.1",
          },
        })}\n",
      );
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": sessionId},
          },
        ),
        const _Response(result: {"turnId": "u-live"}),
      ]);
      final events = <BridgeSseEvent>[];
      final subscription = plugin.events.listen(events.add);

      await plugin.sendPrompt(
        sessionId: sessionId,
        parts: const [PluginPromptPart.text(text: "run the live event fixture")],
        variant: null,
        agent: null,
        model: null,
      );

      final records = <Map<String, Object?>>[
        _toolCall(
          id: "fc-immediate",
          callId: "call-immediate",
          name: "exec_command",
          arguments: '{"cmd":"printf \'LIVE-EVENT-TEST immediate-complete\\\\n\'"}',
        ),
        _toolOutput(
          callId: "call-immediate",
          output: _processOutput(
            chunkId: "immediate",
            exitCode: 0,
            output: "LIVE-EVENT-TEST immediate-complete\n",
          ),
        ),
        _customToolCall(
          id: "ct-exec-1",
          callId: "call-exec-1",
          input:
              'const r = await tools.exec_command({cmd:"sleep 5"}); '
              "text(r.output);",
        ),
        _customToolOutput(
          callId: "call-exec-1",
          output:
              "Script running with cell ID 1\n"
              "Wall time: 0.01 seconds\n"
              "Output:\n",
        ),
        _toolCall(
          id: "fc-wait-1",
          callId: "call-wait-1",
          name: "wait",
          arguments: '{"cell_id":"1","yield_time_ms":10000,"max_tokens":20000}',
        ),
        _toolOutput(
          callId: "call-wait-1",
          output:
              "Script completed with exit code 0\n"
              "Final output:\n",
        ),
        _customToolCall(
          id: "ct-exec-2",
          callId: "call-exec-2",
          input:
              'const r = await tools.exec_command({cmd:"sleep 2"}); '
              "text(r.output);",
        ),
        _customToolOutput(
          callId: "call-exec-2",
          output:
              "Script running with cell ID 2\n"
              "Wall time: 0.01 seconds\n"
              "Output:\n",
        ),
        _toolCall(
          id: "fc-wait-2",
          callId: "call-wait-2",
          name: "wait",
          arguments: '{"cell_id":"2","yield_time_ms":10000,"max_tokens":20000}',
        ),
        _toolOutput(
          callId: "call-wait-2",
          output:
              "Script completed with exit code 0\n"
              "Final output:\n",
        ),
        _toolCall(
          id: "fc-failed",
          callId: "call-failed",
          name: "exec_command",
          arguments: '{"cmd":"/usr/bin/false"}',
        ),
        _toolOutput(
          callId: "call-failed",
          output: _processOutput(
            chunkId: "failed",
            exitCode: 1,
            output: "",
          ),
        ),
        _toolCall(
          id: "fc-recovery",
          callId: "call-recovery",
          name: "exec_command",
          arguments: '{"cmd":"printf \'LIVE-EVENT-TEST recovery-complete\\\\n\'"}',
        ),
        _toolOutput(
          callId: "call-recovery",
          output: _processOutput(
            chunkId: "recovery",
            exitCode: 0,
            output: "LIVE-EVENT-TEST recovery-complete\n",
          ),
        ),
      ];
      final encodedRecords = records.map(jsonEncode).toList();
      final finalRecord = encodedRecords.removeLast();
      final finalRecordSplit = finalRecord.length ~/ 2;
      rollout.writeAsStringSync(
        "${encodedRecords.join("\n")}\n"
        "${finalRecord.substring(0, finalRecordSplit)}",
        mode: FileMode.append,
      );

      fake.pushNotification("turn/completed", {
        "threadId": sessionId,
        "turn": {"id": "u-live"},
      });
      // Complete the final output after turn/completed has observed its partial
      // suffix. The terminal drain must still deliver it before session.idle.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      rollout.writeAsStringSync(
        "${finalRecord.substring(finalRecordSplit)}\n",
        mode: FileMode.append,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final finalLiveParts = <String, PluginMessagePart>{};
      for (final event in events.whereType<BridgeSseMessagePartUpdated>()) {
        final part = event.part;
        if (part.type == PluginMessagePartType.tool) {
          finalLiveParts[part.messageID] = part;
        }
      }
      final history = await plugin.getSessionMessages(sessionId);

      expect(finalLiveParts.keys, {
        "call-immediate",
        "call-exec-1",
        "call-wait-1",
        "call-exec-2",
        "call-wait-2",
        "call-failed",
        "call-recovery",
      });
      expect(history, hasLength(finalLiveParts.length));
      for (final message in history) {
        final historicalPart = message.parts.single;
        final livePart = finalLiveParts[message.info.id];
        expect(livePart, isNotNull, reason: message.info.id);
        expect(livePart?.id, historicalPart.id);
        expect(livePart?.tool, historicalPart.tool);
        expect(livePart?.state?.title, historicalPart.state?.title);
        expect(livePart?.state?.status, historicalPart.state?.status);
        expect(livePart?.state?.output, historicalPart.state?.output);
        expect(livePart?.state?.error, historicalPart.state?.error);
      }
      expect(
        finalLiveParts["call-immediate"]?.state?.title,
        r"printf 'LIVE-EVENT-TEST immediate-complete\n'",
      );
      expect(finalLiveParts["call-exec-1"]?.state?.title, "sleep 5");
      expect(
        finalLiveParts["call-failed"]?.state?.status,
        PluginToolStatus.error,
      );
      expect(
        finalLiveParts["call-failed"]?.state?.output,
        contains("Process exited with code 1"),
      );
      expect(
        events.lastIndexWhere((event) => event is BridgeSseMessagePartUpdated),
        lessThan(events.lastIndexWhere((event) => event is BridgeSseSessionIdle)),
      );

      await subscription.cancel();
    });

    test("keepalive sends periodic model/list RPCs while connected, stops on dispose", () async {
      final kaFake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      final kaPlugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => kaFake.channel,
        ),
        keepaliveInterval: const Duration(milliseconds: 20),
      );
      // Only `initialize` is canned; keepalive model/list calls get an error
      // response, which the plugin swallows — exactly the production behaviour.
      kaFake.respondInOrder([const _Response(result: _initOk)]);

      await kaPlugin.healthCheck(); // connect → starts keepalive
      await Future<void>.delayed(const Duration(milliseconds: 90));

      final firedWhileConnected = kaFake.sentMethods.where((m) => m == "model/list").length;
      expect(firedWhileConnected, greaterThanOrEqualTo(2));

      await kaPlugin.dispose();
      final afterDispose = kaFake.sentMethods.where((m) => m == "model/list").length;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // No further keepalives once disposed.
      expect(
        kaFake.sentMethods.where((m) => m == "model/list").length,
        equals(afterDispose),
      );
    });

    test("getProviders returns codex's full model/list catalog (hidden excluded)", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {
                "id": "gpt-5.5",
                "displayName": "GPT-5.5",
                "hidden": false,
                "isDefault": true,
                "defaultReasoningEffort": "medium",
                "supportedReasoningEfforts": [
                  {"reasoningEffort": "low", "description": "Fast"},
                  {"reasoningEffort": "medium", "description": "Balanced"},
                  {"reasoningEffort": "high", "description": "Deep"},
                  {"reasoningEffort": "xhigh", "description": "Deepest"},
                ],
              },
              {"id": "gpt-5.4-mini", "displayName": "GPT-5.4 mini", "hidden": false, "isDefault": false},
              {"id": "internal", "displayName": "Internal", "hidden": true, "isDefault": false},
            ],
          },
        ),
      ]);

      await plugin.healthCheck(); // connect so model/list can be called
      final result = await plugin.getProviders(projectId: "/work/sample");

      expect(result.providers, hasLength(1));
      final provider = result.providers.single;
      expect(
        provider.models.map((m) => m.id).toList(),
        equals(["gpt-5.5", "gpt-5.4-mini"]),
      );
      expect(provider.models.first.name, equals("GPT-5.5"));
      expect(provider.defaultModelID, equals("gpt-5.5"));
      // Reasoning efforts surface as variants, default ("medium") moved first so
      // the mobile picker's auto-first-on-switch lands on codex's own default.
      expect(
        provider.models.first.variants,
        equals(["medium", "low", "high", "xhigh"]),
      );
      // A model without supportedReasoningEfforts exposes no variants.
      expect(provider.models[1].variants, isEmpty);
      expect(fake.sentMethods, contains("model/list"));
    });

    test("getProviders preselects the project's own latest rollout model over codex's live default", () async {
      // The selected project's newest rollout used gpt-5.4-mini, while codex's
      // live catalog marks gpt-5.5 as the global default — the project-scoped
      // model must win the picker preselection.
      final rollout = File(
        p.join(
          codexHome.path,
          "sessions/2026/06/01/rollout-2026-06-01T10-00-00-019a0000-1111-2222-3333-dddddddddddd.jsonl",
        ),
      )..createSync(recursive: true);
      rollout.writeAsStringSync(
        "${jsonEncode({
          "type": "session_meta",
          "payload": {
            "id": "019a0000-1111-2222-3333-dddddddddddd",
            "timestamp": "2026-06-01T10:00:00Z",
            "cwd": "/work/sample",
            "model_provider": "openai",
          },
        })}\n"
        "${jsonEncode({
          "type": "turn_context",
          "payload": {"model": "gpt-5.4-mini"},
        })}\n",
      );
      final scopedFake = _FakeAppServer();
      const serverUrl = "ws://127.0.0.1:0";
      final scopedPlugin = createInjectedCodexPlugin(
        serverUrl: serverUrl,
        environment: {"CODEX_HOME": codexHome.path},
        projectCwd: "/work/sample",
        clientFactory: () => CodexAppServerClient(
          serverUrl: serverUrl,
          channelFactory: (_) => scopedFake.channel,
        ),
        keepaliveInterval: const Duration(seconds: 30),
      );
      addTearDown(scopedPlugin.dispose);
      scopedFake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "data": [
              {"id": "gpt-5.5", "displayName": "GPT-5.5", "hidden": false, "isDefault": true},
              {"id": "gpt-5.4-mini", "displayName": "GPT-5.4 mini", "hidden": false, "isDefault": false},
            ],
          },
        ),
      ]);

      await scopedPlugin.healthCheck(); // connect so model/list can be called
      final result = await scopedPlugin.getProviders(projectId: "/work/sample");

      expect(result.providers.single.defaultModelID, equals("gpt-5.4-mini"));
    });

    test("sendPrompt forwards the selected variant in Plan mode settings", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "modelProvider": "openai",
            "thread": {"id": "t-effort"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-effort",
        parts: const [PluginPromptPart.text(text: "think hard")],
        variant: const PluginSessionVariant(id: "high"),
        agent: "Plan",
        model: null,
      );

      final params = fake.sentParamsFor("turn/start");
      expect(params.containsKey("effort"), isFalse);
      expect(params["collaborationMode"], {
        "mode": "plan",
        "settings": {
          "model": "gpt-5.5",
          "reasoning_effort": "high",
          "developer_instructions": null,
        },
      });
    });

    test("sendPrompt without a variant sends no effort (codex uses its default)", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-default"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-default",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start").containsKey("effort"), isFalse);
    });

    test("legacy codex agent selects Default mode on the first turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "model": "gpt-5.5",
            "thread": {"id": "t-new"},
          },
        ),
        const _Response(result: {"turnId": "u-1"}),
      ]);

      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "start low")],
        variant: const PluginSessionVariant(id: "low"),
        agent: "codex",
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentParamsFor("turn/start")["collaborationMode"], {
        "mode": "default",
        "settings": {
          "model": "gpt-5.5",
          "reasoning_effort": "low",
          "developer_instructions": null,
        },
      });
    });
  });
}

const Map<String, dynamic> _initOk = {
  "userAgent": "codex-cli/0.121.0",
  "codexHome": "/Users/test/.codex",
  "platformOs": "macos",
  "platformFamily": "unix",
};

class _Response {
  // ignore: unused_element_parameter
  const _Response({this.result, this.error, this.respond = true});
  final Object? result;
  final Map<String, dynamic>? error;
  final bool respond;
}

Map<String, Object?> _toolCall({
  required String id,
  required String callId,
  required String name,
  required String arguments,
}) => {
  "timestamp": "2026-07-23T08:00:01Z",
  "type": "response_item",
  "payload": {
    "type": "function_call",
    "id": id,
    "call_id": callId,
    "name": name,
    "arguments": arguments,
  },
};

Map<String, Object?> _customToolCall({
  required String id,
  required String callId,
  required String input,
}) => {
  "timestamp": "2026-07-23T08:00:01Z",
  "type": "response_item",
  "payload": {
    "type": "custom_tool_call",
    "id": id,
    "call_id": callId,
    "name": "exec",
    "input": input,
  },
};

Map<String, Object?> _toolOutput({
  required String callId,
  required String output,
}) => {
  "timestamp": "2026-07-23T08:00:02Z",
  "type": "response_item",
  "payload": {
    "type": "function_call_output",
    "call_id": callId,
    "output": output,
  },
};

Map<String, Object?> _customToolOutput({
  required String callId,
  required String output,
}) => {
  "timestamp": "2026-07-23T08:00:02Z",
  "type": "response_item",
  "payload": {
    "type": "custom_tool_call_output",
    "call_id": callId,
    "output": [
      {"type": "input_text", "text": output},
    ],
  },
};

String _processOutput({
  required String chunkId,
  required int exitCode,
  required String output,
}) =>
    "Chunk ID: $chunkId\n"
    "Wall time: 0.01 seconds\n"
    "Process exited with code $exitCode\n"
    "Original token count: 3\n"
    "Final output:\n"
    "$output";

/// Fake app-server that records every method/params it received and
/// replies in the order [respondInOrder] queued. Lets us push
/// server-originated notifications via [pushNotification].
class _FakeAppServer {
  _FakeAppServer() {
    _clientToServer = StreamController<Object?>.broadcast();
    _serverToClient = StreamController<Object?>.broadcast();
    channel = _StubChannel(
      stream: _serverToClient.stream,
      sink: _SinkAdapter(_clientToServer),
    );
    _clientToServer.stream.listen(_onClientFrame);
  }

  late final StreamController<Object?> _clientToServer;
  late final StreamController<Object?> _serverToClient;
  late final WebSocketChannel channel;

  final List<_SentFrame> _sent = [];
  final List<_Response> _pending = [];

  /// Invoked with each request method BEFORE the canned response is sent —
  /// lets a test emit server notifications mid-request (e.g. codex pushing
  /// `thread/name/updated` while `turn/start` is still in flight).
  void Function(String method)? onRequest;

  List<String> get sentMethods => _sent.map((f) => f.method).toList(growable: false);

  Map<String, dynamic> sentParamsFor(String method) {
    final frame = _sent.firstWhere((f) => f.method == method);
    return frame.params ?? const {};
  }

  void respondInOrder(List<_Response> responses) {
    _pending
      ..clear()
      ..addAll(responses);
  }

  void pushNotification(String method, Map<String, dynamic> params) {
    _serverToClient.add(
      jsonEncode({"jsonrpc": "2.0", "method": method, "params": params}),
    );
  }

  void _onClientFrame(Object? frame) {
    final raw = frame as String;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _sent.add(
      _SentFrame(
        method: decoded["method"] as String,
        params: (decoded["params"] as Map?)?.cast<String, dynamic>(),
      ),
    );
    onRequest?.call(decoded["method"] as String);
    final id = decoded["id"];
    if (id == null) return; // notification from client (none today)
    if (_pending.isEmpty) {
      _serverToClient.add(
        jsonEncode({
          "jsonrpc": "2.0",
          "id": id,
          "error": {
            "code": -32603,
            "message": "no canned response for ${decoded["method"]}",
          },
        }),
      );
      return;
    }
    final response = _pending.removeAt(0);
    if (!response.respond) return;
    final envelope = <String, dynamic>{"jsonrpc": "2.0", "id": id};
    if (response.error != null) {
      envelope["error"] = response.error;
    } else {
      envelope["result"] = response.result;
    }
    _serverToClient.add(jsonEncode(envelope));
  }
}

class _SentFrame {
  _SentFrame({required this.method, required this.params});
  final String method;
  final Map<String, dynamic>? params;
}

class _StubChannel implements WebSocketChannel {
  _StubChannel({required this.stream, required this.sink});

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink;

  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SinkAdapter implements WebSocketSink {
  _SinkAdapter(this._controller);
  final StreamController<Object?> _controller;

  @override
  void add(Object? data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Object?> stream) async {
    await for (final item in stream) {
      _controller.add(item);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> get done => _controller.done;
}
