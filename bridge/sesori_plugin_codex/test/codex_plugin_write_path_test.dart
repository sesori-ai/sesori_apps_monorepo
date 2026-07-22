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
      expect(plugin.currentWorkState, PluginWorkState.busy);
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
      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("sendCommand marks an accepted turn busy before notifications arrive", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-command"},
          },
        ),
        const _Response(result: {"turnId": "u-command"}),
      ]);

      await plugin.sendCommand(
        sessionId: "t-command",
        command: "review",
        arguments: "recent changes",
        variant: null,
        agent: null,
        model: null,
      );

      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    test("turn/start rejection does not mark the plugin busy", () async {
      fake.respondInOrder([const _Response(result: _initOk)]);
      await plugin.initialize();
      expect(plugin.currentWorkState, PluginWorkState.idle);
      fake.respondInOrder([
        const _Response(
          result: {
            "thread": {"id": "t-rejected"},
          },
        ),
        const _Response(error: {"code": -32000, "message": "turn rejected"}),
      ]);

      await expectLater(
        plugin.sendPrompt(
          sessionId: "t-rejected",
          parts: const [PluginPromptPart.text(text: "go on")],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<CodexRpcException>()),
      );

      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("accepted turn remains busy through delayed start and clears on completion", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-delayed"},
          },
        ),
        const _Response(result: {"turnId": "u-delayed"}),
      ]);

      await plugin.sendPrompt(
        sessionId: "t-delayed",
        parts: const [PluginPromptPart.text(text: "go on")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);

      fake.pushNotification("turn/started", {
        "threadId": "t-delayed",
        "turn": {"id": "u-delayed"},
      });
      await Future<void>.delayed(Duration.zero);
      expect(plugin.currentWorkState, PluginWorkState.busy);

      final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
      fake.pushNotification("turn/completed", {"threadId": "t-delayed"});
      await idle.timeout(const Duration(seconds: 1));
      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("completion received before turn/start response prevents stale provisional busy", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-early-complete"},
          },
        ),
        const _Response(result: {"turnId": "u-early-complete"}),
      ]);
      fake.onRequest = (method) {
        if (method == "turn/start") {
          fake.pushNotification("turn/completed", {"threadId": "t-early-complete"});
        }
      };

      await plugin.sendPrompt(
        sessionId: "t-early-complete",
        parts: const [PluginPromptPart.text(text: "quick task")],
        variant: null,
        agent: null,
        model: null,
      );
      await Future<void>.delayed(Duration.zero);

      expect(plugin.currentWorkState, PluginWorkState.idle);
    });

    test("delete invalidates an in-flight turn response until the backend recreates the thread", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
            "thread": {"id": "t-deleted"},
          },
        ),
      ]);
      fake.holdNextResponse("turn/start");
      final turnStarted = Completer<void>();
      fake.onRequest = (method) {
        if (method == "turn/start" && !turnStarted.isCompleted) {
          turnStarted.complete();
        }
      };

      final send = plugin.sendPrompt(
        sessionId: "t-deleted",
        parts: const [PluginPromptPart.text(text: "quick task")],
        variant: null,
        agent: null,
        model: null,
      );
      await turnStarted.future;
      await plugin.deleteSession("t-deleted");

      fake.respondToHeld("turn/start", const _Response(result: {"turnId": "u-deleted"}));
      await send;
      expect(plugin.currentWorkState, PluginWorkState.idle);

      fake.respondInOrder([
        const _Response(
          result: {
            "thread": {"id": "t-deleted"},
          },
        ),
        const _Response(result: {"turnId": "u-recreated"}),
      ]);
      await plugin.createSession(
        directory: "/work/sample",
        parentSessionId: null,
        parts: const [PluginPromptPart.text(text: "new lifecycle")],
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.currentWorkState, PluginWorkState.busy);
    });

    for (final terminalNotification in ["error", "thread/status/changed"]) {
      test("$terminalNotification clears provisional busy", () async {
        fake.respondInOrder([
          const _Response(result: _initOk),
          const _Response(
            result: {
              "thread": {"id": "t-terminal"},
            },
          ),
          const _Response(result: {"turnId": "u-terminal"}),
        ]);

        await plugin.sendPrompt(
          sessionId: "t-terminal",
          parts: const [PluginPromptPart.text(text: "go on")],
          variant: null,
          agent: null,
          model: null,
        );
        expect(plugin.currentWorkState, PluginWorkState.busy);

        final idle = plugin.workState.firstWhere((state) => state == PluginWorkState.idle);
        fake.pushNotification(
          terminalNotification,
          terminalNotification == "error"
              ? {
                  "threadId": "t-terminal",
                  "error": {"message": "turn failed"},
                }
              : {
                  "threadId": "t-terminal",
                  "status": {"type": "idle"},
                },
        );

        await idle.timeout(const Duration(seconds: 1));
        expect(plugin.currentWorkState, PluginWorkState.idle);
      });
    }

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
      final subscription = plugin.events.listen(events.add);

      // Trigger _ensureConnected.
      await plugin.healthCheck();

      fake.pushNotification("turn/started", {
        "threadId": "t-1",
        "turn": {"id": "u-1"},
      });
      fake.pushNotification("item/agentMessage/delta", {
        "threadId": "t-1",
        "turnId": "u-1",
        "itemId": "i-1",
        "delta": "Hi",
      });
      fake.pushNotification("turn/completed", {"threadId": "t-1"});

      // Drain microtasks so all notification handlers run.
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(
        events.map((e) => e.runtimeType.toString()).toList(),
        containsAllInOrder([
          "BridgeSseSessionStatus",
          "BridgeSseMessagePartDelta",
          "BridgeSseSessionIdle",
        ]),
      );

      // Active session status is tracked from the notifications.
      final statuses = await plugin.getSessionStatuses();
      expect(statuses["t-1"], isA<PluginSessionStatusIdle>());
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

    test("sendPrompt forwards the selected variant as the turn/start effort", () async {
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
        agent: null,
        model: null,
      );

      expect(fake.sentParamsFor("turn/start")["effort"], equals("high"));
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

    test("createSession applies the variant on the first turn", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(
          result: {
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
        agent: null,
        model: null,
      );

      expect(fake.sentMethods, equals(["initialize", "thread/start", "turn/start"]));
      expect(fake.sentParamsFor("turn/start")["effort"], equals("low"));
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
  const _Response({this.result, this.error});
  final Object? result;
  final Map<String, dynamic>? error;
}

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
  final Set<String> _responsesToHold = {};
  final Map<String, Object> _heldRequestIds = {};

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

  void holdNextResponse(String method) {
    _responsesToHold.add(method);
  }

  void respondToHeld(String method, _Response response) {
    final id = _heldRequestIds.remove(method);
    if (id == null) throw StateError("no held request for $method");
    _sendResponse(id, response);
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
    final id = decoded["id"] as Object?;
    if (id == null) return; // notification from client (none today)
    final method = decoded["method"] as String;
    if (_responsesToHold.remove(method)) {
      _heldRequestIds[method] = id;
      return;
    }
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
    _sendResponse(id, response);
  }

  void _sendResponse(Object id, _Response response) {
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
