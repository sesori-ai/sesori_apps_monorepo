// Phase 4 write-path integration tests: createSession, sendPrompt,
// abortSession round-trip against an in-memory fake WS, plus the
// notification → BridgeSseEvent pipeline.
// ignore_for_file: unawaited_futures, cast_nullable_to_non_nullable, prefer_foreach, avoid_dynamic_calls

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  group("CodexPlugin write path", () {
    late Directory codexHome;
    late _FakeAppServer fake;
    late CodexPlugin plugin;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-write-");
      fake = _FakeAppServer();
      plugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => fake.channel,
        ),
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample",
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

    test("sendPrompt sends a turn/start on the existing thread", () async {
      fake.respondInOrder([
        const _Response(result: _initOk),
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
      expect(methods, equals(["initialize", "turn/start"]));
      final params = fake.sentParamsFor("turn/start");
      expect(params["threadId"], equals("t-existing"));
    });

    test("abortSession calls turn/interrupt on the active turn", () async {
      // First the connection + a sendPrompt that triggers turn/started
      // notification, so the plugin knows the turn id to abort.
      fake.respondInOrder([
        const _Response(result: _initOk),
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

  List<String> get sentMethods =>
      _sent.map((f) => f.method).toList(growable: false);

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
