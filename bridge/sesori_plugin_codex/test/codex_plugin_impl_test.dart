// Tests for the Phase 1/2 codex plugin. Each helper that fires-and-forgets a
// response to the client's first request is intentionally not awaited — the
// pattern of "subscribe to the next outgoing frame, then push a reply" is
// what gives the test its determinism, and awaiting it would deadlock.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable, prefer_foreach

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("CodexPlugin", () {
    test("id returns codex", () {
      final plugin = CodexPlugin(serverUrl: "ws://127.0.0.1:0");
      expect(plugin.id, equals("codex"));
    });

    test("getProjects synthesises a single project from launch CWD", () async {
      // Phase 3: a single PluginProject is returned for the launch CWD.
      // Pin both CODEX_HOME (away from the user's real history) and
      // projectCwd so the test is hermetic.
      final tempHome = Directory.systemTemp.createTempSync("codex-home-stub-");
      try {
        final plugin = CodexPlugin(
          serverUrl: "ws://127.0.0.1:0",
          rolloutReader: SessionRolloutReader(
            environment: {"CODEX_HOME": tempHome.path},
          ),
          projectCwd: "/repo/example",
        );
        final projects = await plugin.getProjects();
        expect(projects, hasLength(1));
        expect(projects.single.id, equals("/repo/example"));
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
        final plugin = CodexPlugin(
          serverUrl: "ws://127.0.0.1:0",
          rolloutReader: SessionRolloutReader(
            environment: {"CODEX_HOME": tempHome.path},
          ),
          // Hermetic skill reader so the user's real ~/.codex/skills/
          // doesn't leak into this test.
          skillReader: CodexSkillReader(
            environment: {"CODEX_HOME": tempHome.path},
            projectCwd: tempHome.path,
          ),
          projectCwd: "/repo/example",
        );
        expect(await plugin.getSessions("/repo/example"), isEmpty);
        expect(await plugin.getCommands(projectId: "/repo/example"), isEmpty);
        expect(await plugin.getAgents(), isEmpty);
        expect(await plugin.getSessionMessages("s-1"), isEmpty);
        expect(await plugin.getSessionStatuses(), isEmpty);
        expect(plugin.getActiveSessionsSummary(), isEmpty);
        await plugin.dispose();
      } finally {
        try {
          tempHome.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test(
      "renameProject returns the synthesised project with the new name",
      () async {
        // Phase 6 dropped the last UnimplementedError. renameProject is a
        // no-op against codex (single-project model) but echoes the new
        // name so any caller's local cache stays consistent.
        final tempHome = Directory.systemTemp.createTempSync("codex-home-rn-");
        try {
          final plugin = CodexPlugin(
            serverUrl: "ws://127.0.0.1:0",
            rolloutReader: SessionRolloutReader(
              environment: {"CODEX_HOME": tempHome.path},
            ),
            skillReader: CodexSkillReader(
              environment: {"CODEX_HOME": tempHome.path},
              projectCwd: tempHome.path,
            ),
            projectCwd: "/repo/example",
          );
          final renamed =
              await plugin.renameProject(projectId: "/repo/example", name: "X");
          expect(renamed.id, equals("/repo/example"));
          expect(renamed.name, equals("X"));
          await plugin.dispose();
        } finally {
          try {
            tempHome.deleteSync(recursive: true);
          } catch (_) {}
        }
      },
    );

    test("healthCheck returns true after a successful initialize handshake", () async {
      final fake = _FakeWebSocket();
      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => fake.channel,
        ),
      );

      // Auto-respond to the first request with a valid initialize response.
      fake.outgoing.first.then((Object? frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        expect(decoded["method"], equals("initialize"));
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
      final plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => fake.channel,
        ),
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
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

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
