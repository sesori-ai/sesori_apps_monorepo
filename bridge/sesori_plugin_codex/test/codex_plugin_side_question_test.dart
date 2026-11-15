import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  test("the descriptor declares side questions and the plugin answers them", () {
    expect(const CodexPluginDescriptor(desktopAppCliCandidates: null).supportsSideQuestions, isTrue);
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:0",
      environment: const {},
      projectCwd: "/repo/example",
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
      toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
      runtimeExit: runningCodexRuntime,
    );
    addTearDown(plugin.dispose);
    expect(plugin, isA<SideQuestionPluginApi>());
  });

  test("an ask during a running turn samples that turn without listing turns", () async {
    final server = await _AppServer.start(resumedTurnStatus: "completed");
    await server.startTurn(threadId: "t-1", turnId: "turn-running");

    final answer = await server.plugin.askSideQuestion(sessionId: "t-1", question: "Why?", history: const []);

    expect(answer, isA<PluginSideAnswered>().having((answer) => answer.text, "text", "Side answer."));
    expect(server.methods, isNot(contains("thread/turns/list")));
    expect(server.sampleParams?["expectedTurnId"], "turn-running");
    expect(server.sampleParams?["allowInProgressTurn"], isTrue);
  });

  test("an ask on an idle thread loads it, then samples its latest turn", () async {
    final server = await _AppServer.start(resumedTurnStatus: "completed");

    await server.plugin.askSideQuestion(sessionId: "t-1", question: "Why?", history: const []);

    expect(server.methods, containsAllInOrder(["thread/resume", "thread/turns/list", "thread/sample"]));
    expect(server.sampleParams?["expectedTurnId"], "turn-latest");
  });

  test("a load that finds a turn still running samples that turn and shows the session busy", () async {
    final server = await _AppServer.start(resumedTurnStatus: "inProgress");

    await server.plugin.askSideQuestion(sessionId: "t-1", question: "Why?", history: const []);

    expect(server.methods, isNot(contains("thread/turns/list")));
    expect(server.sampleParams?["expectedTurnId"], "turn-resumed");
    expect((await server.plugin.getSessionStatuses())["t-1"], isA<PluginSessionStatusBusy>());
  });
}

/// A loopback app-server that answers what a side question needs.
class _AppServer({
  required final CodexPlugin plugin,
  required final Future<WebSocket> _socket,
  required final List<String> methods,
  required final Map<String, Object?>? Function() _sampleParams,
}) {
  Map<String, Object?>? get sampleParams => _sampleParams();

  static Future<_AppServer> start({required String resumedTurnStatus}) async {
    final codexHome = Directory.systemTemp.createTempSync("codex-home-side-question-");
    addTearDown(() => codexHome.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final socket = Completer<WebSocket>();
    final methods = <String>[];
    Map<String, Object?>? sampleParams;
    server.listen((request) async {
      final webSocket = await WebSocketTransformer.upgrade(request);
      socket.complete(webSocket);
      webSocket.listen((frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        final method = decoded["method"] as String;
        methods.add(method);
        final params = (decoded["params"] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        if (method == "thread/sample") sampleParams = params;
        final Object result = switch (method) {
          "initialize" => const {"userAgent": "codex-cli/0.169.0"},
          "config/read" => const {"config": <String, Object?>{}},
          "thread/resume" => {
            "thread": {
              "id": params["threadId"],
              "cwd": "/repo/example",
              "turns": [
                {"id": "turn-resumed", "status": resumedTurnStatus},
              ],
            },
          },
          "thread/turns/list" => const {
            "data": [
              {"id": "turn-latest", "status": "completed"},
            ],
          },
          "thread/sample" => const {"sourceTurnId": "turn-latest", "responseId": "resp", "text": "Side answer."},
          _ => const <String, Object?>{},
        };
        webSocket.add(jsonEncode({"jsonrpc": "2.0", "id": decoded["id"], "result": result}));
      });
    });
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:${server.port}",
      environment: {"CODEX_HOME": codexHome.path},
      projectCwd: "/repo/example",
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
      toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
      runtimeExit: runningCodexRuntime,
    );
    addTearDown(plugin.dispose);
    await plugin.initialize();
    return _AppServer(plugin: plugin, socket: socket.future, methods: methods, sampleParams: () => sampleParams);
  }

  /// Announces a running turn on [threadId] and waits until the plugin shows it.
  Future<void> startTurn({required String threadId, required String turnId}) async {
    final busy = plugin.events.firstWhere((event) => event is BridgeSseSessionStatus);
    (await _socket).add(
      jsonEncode({
        "jsonrpc": "2.0",
        "method": "turn/started",
        "params": {
          "threadId": threadId,
          "turn": {"id": turnId},
        },
      }),
    );
    await busy.timeout(const Duration(seconds: 2));
  }
}
