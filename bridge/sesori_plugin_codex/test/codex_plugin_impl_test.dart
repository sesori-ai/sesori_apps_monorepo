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
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("CodexPlugin", () {
    test("id returns codex", () {
      final plugin = CodexPlugin(serverUrl: "ws://127.0.0.1:0");
      expect(plugin.id, equals("codex"));
    });

    test("getProjects derives a project per distinct session cwd plus launch cwd", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-proj-");
      try {
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-a00000000001",
          cwd: "/work/alpha",
          timestamp: "2026-05-01T10:00:00Z",
        );
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-a00000000002",
          cwd: "/work/alpha",
          timestamp: "2026-05-03T12:00:00Z",
        );
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-b00000000001",
          cwd: "/work/beta",
          timestamp: "2026-05-02T10:00:00Z",
        );

        final plugin = _hermeticPlugin(home: tempHome, projectCwd: "/launch/dir");
        final projects = await plugin.getProjects();
        final byId = {for (final pr in projects) pr.id: pr};
        expect(
          byId.keys,
          containsAll(<String>["/work/alpha", "/work/beta", "/launch/dir"]),
        );
        expect(byId["/work/alpha"]!.name, equals("alpha"));
        expect(byId["/work/beta"]!.name, equals("beta"));
        // Most-recent session activity sorts first; the session-less launch dir
        // (time 0/0) sorts last.
        expect(projects.first.id, equals("/work/alpha"));
        expect(projects.last.id, equals("/launch/dir"));
        expect(
          byId["/work/alpha"]!.time?.updated,
          equals(DateTime.parse("2026-05-03T12:00:00Z").millisecondsSinceEpoch),
        );
        await plugin.dispose();
      } finally {
        _rmTree(tempHome);
      }
    });

    test("getSessions groups sessions by their own cwd with the correct projectID", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-grp-");
      try {
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-a00000000001",
          cwd: "/work/alpha",
          timestamp: "2026-05-01T10:00:00Z",
        );
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-b00000000001",
          cwd: "/work/beta",
          timestamp: "2026-05-02T10:00:00Z",
        );

        final plugin = _hermeticPlugin(home: tempHome, projectCwd: "/launch/dir");
        final alpha = await plugin.getSessions("/work/alpha");
        expect(
          alpha.map((s) => s.id).toList(),
          equals(["019a0000-1111-2222-3333-a00000000001"]),
        );
        expect(alpha.single.projectID, equals("/work/alpha"));
        expect(alpha.single.directory, equals("/work/alpha"));

        final beta = await plugin.getSessions("/work/beta");
        expect(
          beta.map((s) => s.id).toList(),
          equals(["019a0000-1111-2222-3333-b00000000001"]),
        );
        expect(beta.single.projectID, equals("/work/beta"));
        await plugin.dispose();
      } finally {
        _rmTree(tempHome);
      }
    });

    test("a session cwd and a trailing-slash launch cwd dedupe to one project", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-dup-");
      try {
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-d00000000001",
          cwd: "/work/dup",
          timestamp: "2026-05-05T10:00:00Z",
        );
        // Launch CWD carries a trailing separator; the session CWD does not.
        final plugin = _hermeticPlugin(home: tempHome, projectCwd: "/work/dup/");
        final ids = (await plugin.getProjects()).map((pr) => pr.id).toList();
        // They collapse to a single project whose id is the session cwd verbatim
        // (so getSessions' exact filter keeps matching).
        expect(
          ids.where((id) => id == "/work/dup" || id == "/work/dup/").toList(),
          equals(["/work/dup"]),
        );
        await plugin.dispose();
      } finally {
        _rmTree(tempHome);
      }
    });

    test("sessions under merged trailing-slash spellings stay reachable from the one project", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-reach-");
      try {
        // Same directory recorded two ways — with and without a trailing slash.
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-e00000000001",
          cwd: "/work/dup",
          timestamp: "2026-05-07T10:00:00Z",
        );
        _writeMetaRollout(
          tempHome,
          sessionId: "019a0000-1111-2222-3333-e00000000002",
          cwd: "/work/dup/",
          timestamp: "2026-05-07T11:00:00Z",
        );

        final plugin = _hermeticPlugin(home: tempHome, projectCwd: "/launch/dir");
        final dupProjects = (await plugin.getProjects())
            .where((pr) => pr.id == "/work/dup" || pr.id == "/work/dup/")
            .toList();
        // The two spellings collapse to a single project…
        expect(dupProjects, hasLength(1));
        // …and getSessions on that project's id returns BOTH sessions, not just
        // the one whose cwd spelling matched verbatim.
        final sessions = await plugin.getSessions(dupProjects.single.id);
        expect(
          sessions.map((s) => s.id).toSet(),
          equals({
            "019a0000-1111-2222-3333-e00000000001",
            "019a0000-1111-2222-3333-e00000000002",
          }),
        );
        await plugin.dispose();
      } finally {
        _rmTree(tempHome);
      }
    });

    test("getProject registers and persists an opened directory with no sessions", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-open-");
      try {
        final plugin = _hermeticPlugin(home: tempHome, projectCwd: "/launch/dir");
        final opened = await plugin.getProject("/work/new-folder");
        expect(opened.id, equals("/work/new-folder"));
        expect(opened.name, equals("new-folder"));
        // Appears in the list right away…
        expect(
          (await plugin.getProjects()).map((pr) => pr.id),
          contains("/work/new-folder"),
        );
        await plugin.dispose();

        // …and survives a fresh plugin instance (persisted under CODEX_HOME).
        final restarted = _hermeticPlugin(
          home: tempHome,
          projectCwd: "/launch/dir",
        );
        expect(
          (await restarted.getProjects()).map((pr) => pr.id),
          contains("/work/new-folder"),
        );
        await restarted.dispose();
      } finally {
        _rmTree(tempHome);
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
          // Hermetic config/skill readers so the user's real ~/.codex/
          // doesn't leak into this test.
          configReader: CodexConfigReader(
            environment: {"CODEX_HOME": tempHome.path},
          ),
          skillReader: CodexSkillReader(
            environment: {"CODEX_HOME": tempHome.path},
            projectCwd: tempHome.path,
          ),
          projectCwd: "/repo/example",
        );
        expect(await plugin.getSessions("/repo/example"), isEmpty);
        expect(await plugin.getCommands(projectId: "/repo/example"), isEmpty);
        expect(await plugin.getSessionMessages("s-1"), isEmpty);
        expect(await plugin.getSessionStatuses(), isEmpty);
        expect(plugin.getActiveSessionsSummary(), isEmpty);
        // With no config or rollout history, codex still surfaces its single
        // agent (the harness identity) but with no resolvable model, and no
        // providers.
        final agents = await plugin.getAgents(projectId: "/repo/example");
        expect(agents.single.name, equals("codex"));
        expect(agents.single.model, isNull);
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

    test("getAgents/getProviders synthesise from config + latest rollout", () async {
      final tempHome = Directory.systemTemp.createTempSync("codex-home-syn-");
      try {
        File(p.join(tempHome.path, "config.toml"))
            .writeAsStringSync('model = "gpt-5.5"\nmodel_provider = "openai"\n');
        // A rollout whose turn_context model differs from the global config
        // default — the per-session model must win.
        final rollout = File(p.join(
          tempHome.path,
          "sessions/2026/05/27/rollout-2026-05-27T10-00-00-019a0000-1111-2222-3333-bbbbbbbbbbbb.jsonl",
        ))..createSync(recursive: true);
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

        final plugin = CodexPlugin(
          serverUrl: "ws://127.0.0.1:0",
          rolloutReader: SessionRolloutReader(
            environment: {"CODEX_HOME": tempHome.path},
          ),
          configReader: CodexConfigReader(
            environment: {"CODEX_HOME": tempHome.path},
          ),
          skillReader: CodexSkillReader(
            environment: {"CODEX_HOME": tempHome.path},
            projectCwd: tempHome.path,
          ),
          projectCwd: "/repo/example",
        );

        final agent = (await plugin.getAgents(projectId: "/repo/example")).single;
        expect(agent.name, equals("codex"));
        expect(agent.model?.modelID, equals("gpt-5.4-codex"));
        expect(agent.model?.providerID, equals("openai"));

        final providers =
            (await plugin.getProviders(projectId: "/repo/example")).providers;
        expect(providers.single.id, equals("openai"));
        expect(providers.single.defaultModelID, equals("gpt-5.4-codex"));
        await plugin.dispose();
      } finally {
        try {
          tempHome.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test(
      "renameProject persists a display-name override that survives a refresh",
      () async {
        final tempHome = Directory.systemTemp.createTempSync("codex-home-rn-");
        try {
          final plugin = _hermeticPlugin(
            home: tempHome,
            projectCwd: "/repo/example",
          );
          final renamed =
              await plugin.renameProject(projectId: "/repo/example", name: "X");
          expect(renamed.id, equals("/repo/example"));
          expect(renamed.name, equals("X"));
          await plugin.dispose();

          // The override is persisted, so a fresh plugin still lists the name.
          final restarted = _hermeticPlugin(
            home: tempHome,
            projectCwd: "/repo/example",
          );
          final project = (await restarted.getProjects())
              .firstWhere((pr) => pr.id == "/repo/example");
          expect(project.name, equals("X"));
          await restarted.dispose();
        } finally {
          _rmTree(tempHome);
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

/// Builds a fully-hermetic CodexPlugin: every reader and the project store are
/// pinned to a temp CODEX_HOME so a test never touches the user's real history.
CodexPlugin _hermeticPlugin({
  required Directory home,
  required String projectCwd,
}) {
  final env = {"CODEX_HOME": home.path};
  return CodexPlugin(
    serverUrl: "ws://127.0.0.1:0",
    rolloutReader: SessionRolloutReader(environment: env),
    configReader: CodexConfigReader(environment: env),
    skillReader: CodexSkillReader(environment: env, projectCwd: projectCwd),
    projectStorage: CodexProjectStorage(environment: env),
    projectCwd: projectCwd,
  );
}

/// Writes a minimal rollout carrying only the `session_meta` header (id, cwd,
/// timestamp) under a date-derived `sessions/YYYY/MM/DD/` path.
void _writeMetaRollout(
  Directory codexHome, {
  required String sessionId,
  required String cwd,
  required String timestamp,
}) {
  final date = DateTime.parse(timestamp).toUtc();
  String two(int v) => v.toString().padLeft(2, "0");
  final dateDir = "${date.year}/${two(date.month)}/${two(date.day)}";
  final fileName =
      "rollout-${date.year}-${two(date.month)}-${two(date.day)}T00-00-00-$sessionId.jsonl";
  final full = p.join(codexHome.path, "sessions", dateDir, fileName);
  Directory(p.dirname(full)).createSync(recursive: true);
  final line = jsonEncode({
    "timestamp": timestamp,
    "type": "session_meta",
    "payload": {
      "id": sessionId,
      "timestamp": timestamp,
      "cwd": cwd,
      "cli_version": "0.142.0",
      "model_provider": "openai",
    },
  });
  File(full).writeAsStringSync("$line\n");
}

void _rmTree(Directory dir) {
  try {
    dir.deleteSync(recursive: true);
  } catch (_) {
    // Best-effort cleanup.
  }
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
