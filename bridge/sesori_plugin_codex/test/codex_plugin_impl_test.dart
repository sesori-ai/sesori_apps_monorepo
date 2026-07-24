// Tests for the Phase 1/2 codex plugin. Each helper that fires-and-forgets a
// response to the client's first request is intentionally not awaited — the
// pattern of "subscribe to the next outgoing frame, then push a reply" is
// what gives the test its determinism, and awaiting it would deadlock.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable, prefer_foreach

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
  group("CodexPlugin", () {
    test("id returns codex", () {
      final plugin = CodexPlugin(serverUrl: "ws://127.0.0.1:0");
      expect(plugin.id, equals("codex"));
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
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
          keepaliveInterval: const Duration(seconds: 30),
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
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
          keepaliveInterval: const Duration(seconds: 30),
        );
        expect(await plugin.getSessions("/repo/example"), isEmpty);
        expect(await plugin.getSessionMessages("s-1"), isEmpty);
        expect(await plugin.getSessionStatuses(), isEmpty);
        expect(plugin.getActiveSessionsSummary(), isEmpty);
        // With no config, rollout history, or live connection, Codex exposes
        // only Default because Plan requires a resolved model.
        final agents = await plugin.getAgents(projectId: "/repo/example");
        expect(agents.map((agent) => agent.name), equals(["Default"]));
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
          clientFactory: () => CodexAppServerClient(serverUrl: serverUrl),
          keepaliveInterval: const Duration(seconds: 30),
        );

        final agents = await plugin.getAgents(projectId: "/repo/example");
        expect(agents.map((agent) => agent.name), equals(["Default", "Plan"]));
        final agent = agents.first;
        expect(agent.name, equals("Default"));
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

    test("healthCheck returns true after a successful initialize handshake", () async {
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
        ),
        keepaliveInterval: const Duration(seconds: 30),
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

      expect(await plugin.healthCheck(), isTrue);
      await plugin.dispose();
    });

    test("healthCheck returns false when handshake errors", () async {
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
        ),
        keepaliveInterval: const Duration(seconds: 30),
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

      expect(await plugin.healthCheck(), isFalse);
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
      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:${server.port}",
        projectCwd: "/repo/example",
        keepaliveInterval: const Duration(seconds: 30),
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

      expect(await plugin.healthCheck(), isTrue);
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

      final completed = plugin.events.where((event) => event is BridgeSseSessionIdle).cast<BridgeSseSessionIdle>().first;
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

      final disconnected = plugin.events.where((event) => event is BridgeSseSessionIdle).cast<BridgeSseSessionIdle>().first;
      await socket.close(WebSocketStatus.goingAway);

      expect(
        (await disconnected.timeout(const Duration(seconds: 2))).sessionID,
        "t-running",
      );
      expect(plugin.getActiveSessionsSummary(), isEmpty);
      expect(
        await plugin.getPendingPermissions(sessionId: "t-running"),
        isEmpty,
      );
    });

    test("dispose closes event buffer without error", () async {
      final plugin = CodexPlugin(serverUrl: "ws://127.0.0.1:0");
      await expectLater(plugin.dispose(), completes);
    });
  });

  group("CodexAppServerClient", () {
    test("request demultiplexes responses by id", () async {
      final fake = _FakeWebSocket();
      final client = CodexAppServerClient(
        serverUrl: "ws://127.0.0.1:0",
        channelFactory: (_) => fake.channel,
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
        client.request(method: "thread/list"),
        client.request(method: "skills/list"),
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

/// Minimal bidirectional channel for in-memory WebSocket testing.
///
/// Mirrors the surface used by [CodexAppServerClient]:
///   - `channel.stream`   → frames sent from server to client.
///   - `channel.sink.add` → frames sent from client to server.
///
/// Tests can subscribe to [outgoing] to see what the client sent and respond
/// on [serverSink].
class _FakeWebSocket {
  _FakeWebSocket() {
    _clientToServer = StreamController<Object?>.broadcast();
    _serverToClient = StreamController<Object?>.broadcast();
    channel = _StubChannel(
      stream: _serverToClient.stream,
      sink: _SinkAdapter(_clientToServer),
    );
  }

  late final StreamController<Object?> _clientToServer;
  late final StreamController<Object?> _serverToClient;
  late final WebSocketChannel channel;

  Stream<Object?> get outgoing => _clientToServer.stream;
  Sink<Object?> get serverSink => _SinkAdapter(_serverToClient);
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

  // The class implements WebSocketChannel which mixes in StreamChannelMixin;
  // none of those helper methods are exercised by our tests so we satisfy
  // the analyzer by routing them through noSuchMethod.
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
