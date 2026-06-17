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

    test("sendPrompt does not re-resume a thread created in this run", () async {
      // createSession (no parts) loads the thread; a follow-up turn must reuse
      // it without a redundant resume round-trip.
      fake.respondInOrder([
        const _Response(result: _initOk),
        const _Response(result: {"thread": {"id": "t-fresh"}}),
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
        const _Response(result: {"thread": {"id": "t-dropped"}}),
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
        const _Response(result: {"thread": {"id": "t-1"}}),
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
      final kaPlugin = CodexPlugin(
        serverUrl: "ws://127.0.0.1:0",
        clientFactory: () => CodexAppServerClient(
          serverUrl: "ws://127.0.0.1:0",
          channelFactory: (_) => kaFake.channel,
        ),
        rolloutReader: SessionRolloutReader(
          environment: {"CODEX_HOME": codexHome.path},
        ),
        projectCwd: "/work/sample",
        keepaliveInterval: const Duration(milliseconds: 20),
      );
      // Only `initialize` is canned; keepalive model/list calls get an error
      // response, which the plugin swallows — exactly the production behaviour.
      kaFake.respondInOrder([const _Response(result: _initOk)]);

      await kaPlugin.healthCheck(); // connect → starts keepalive
      await Future<void>.delayed(const Duration(milliseconds: 90));

      final firedWhileConnected =
          kaFake.sentMethods.where((m) => m == "model/list").length;
      expect(firedWhileConnected, greaterThanOrEqualTo(2));

      await kaPlugin.dispose();
      final afterDispose =
          kaFake.sentMethods.where((m) => m == "model/list").length;
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
        const _Response(result: {"thread": {"id": "t-default"}}),
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
        const _Response(result: {"thread": {"id": "t-new"}}),
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
