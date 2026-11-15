import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

/// The 0.167.2 rollouts of `codex_revert_fork_history_test.dart`: the source
/// thread answered "one", "two", "three", was reverted before "three" and
/// answered "four", so its current history is "one", "two", "four".
const _fixtureDay = "test/fixtures/codex_revert_fork/sessions/2026/11/15";
const _sourceId = "01a1e0e9-81f9-7b81-81c6-a835c1d98756";
const _originalRollout = "rollout-2026-11-15T12-32-41-$_sourceId.jsonl";
const _userItemTwo = "01a1e0e9-8709-7a71-b289-6b15d15c677c";
const _turnTwo = "01a1e0e9-8704-78f0-9883-d16895f63c89";

void main() {
  test("the descriptor declares rewind and the plugin implements it", () {
    expect(
      const CodexPluginDescriptor(desktopAppCliCandidates: null).sessionBranching,
      {PluginSessionBranching.rewind},
    );
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
    expect(plugin, isA<SessionRewindPluginApi>());
  });

  test("a rewind loads the thread, reverts before the message's turn, then starts the turn", () async {
    final server = await _AppServer.start(revertError: null);

    await server.rewind(sessionId: _sourceId, beforeMessageId: _userItemTwo, parts: _text);

    expect(server.methods, containsAllInOrder(["thread/resume", "thread/revert", "turn/start"]));
    expect(server.paramsOf("thread/revert"), {"threadId": _sourceId, "beforeTurnId": _turnTwo});
    expect(server.paramsOf("turn/start")?["clientUserMessageId"], "prompt-1");
  });

  test("history follows the reverted rollout at once", () async {
    final server = await _AppServer.start(revertError: null);

    await server.rewind(sessionId: _sourceId, beforeMessageId: _userItemTwo, parts: _text);

    final texts = [
      for (final message in await server.plugin.getSessionMessages(_sourceId))
        if (message.info is PluginMessageUser)
          for (final part in message.parts)
            if (part case PluginMessagePartText(:final text)) text,
    ];
    expect(texts, ["Reply with exactly the word: one"]);
  });

  test("a follow-up steered into its turn is refused before anything changes", () async {
    final server = await _AppServer.start(revertError: null, steeredRollout: true);

    await expectLater(
      server.rewind(sessionId: _steeredId, beforeMessageId: "user-steered", parts: _text),
      throwsA(_refusal(reason: "A message sent while the agent was working can't be edited.")),
    );
    expect(server.methods, isNot(contains("thread/revert")));

    await server.rewind(sessionId: _steeredId, beforeMessageId: "user-opening", parts: _text);
    expect(server.paramsOf("thread/revert"), {"threadId": _steeredId, "beforeTurnId": "turn-2"});
  });

  test("an unknown message is refused before anything changes", () async {
    final server = await _AppServer.start(revertError: null);

    await expectLater(
      server.rewind(sessionId: _sourceId, beforeMessageId: "m-3", parts: _text),
      throwsA(_refusal(reason: "Codex can't find this message to edit it.")),
    );
    expect(server.methods, isNot(contains("thread/revert")));
  });

  test("an attachment turn/start would refuse is refused before the revert", () async {
    final server = await _AppServer.start(revertError: null);

    await expectLater(
      server.rewind(
        sessionId: _sourceId,
        beforeMessageId: _userItemTwo,
        parts: const [PluginPromptPart.fileData(mime: "application/pdf", base64: "AAAA", filename: "a.pdf")],
      ),
      throwsA(isNot(isA<PluginBranchPointUnavailableException>())),
    );
    expect(server.methods, isNot(contains("thread/revert")));
  });

  for (final (:code, :message, :reason) in const [
    (
      code: -32600,
      message: "Invalid request: unknown variant `thread/revert`, expected one of `initialize`",
      reason: "Update Codex to edit messages.",
    ),
    (
      code: -32600,
      message: "thread/revert only supports paginated threads",
      reason: "Codex can't edit messages in sessions from older Codex versions.",
    ),
    (
      code: -32600,
      message: "ephemeral threads do not support thread/revert",
      reason: "Codex can't edit messages in a temporary session.",
    ),
  ]) {
    test("thread/revert answering '$message' is refused without a turn", () async {
      final server = await _AppServer.start(revertError: (code: code, message: message));

      await expectLater(
        server.rewind(sessionId: _sourceId, beforeMessageId: _userItemTwo, parts: _text),
        throwsA(_refusal(reason: reason)),
      );
      expect(server.methods, isNot(contains("turn/start")));
    });
  }
}

const _text = [PluginPromptPart.text(text: "edited")];

const _steeredId = "01a1e0f0-0000-7000-8000-000000000001";

Matcher _refusal({required String reason}) => isA<PluginBranchPointUnavailableException>().having(
  (error) => error.userFacingReason,
  "userFacingReason",
  reason,
);

/// A loopback app-server over a CODEX_HOME holding the fixture rollouts. Its
/// `thread/revert` writes the kept history as a new rollout the way Codex
/// does, or answers [revertError].
class _AppServer({
  required final CodexPlugin plugin,
  required final List<String> methods,
  required final Map<String, Map<String, dynamic>> _params,
}) {
  Map<String, dynamic>? paramsOf(String method) => _params[method];

  Future<void> rewind({
    required String sessionId,
    required String beforeMessageId,
    required List<PluginPromptPart> parts,
  }) => plugin.rewindAndSendPrompt(
    sessionId: sessionId,
    beforeMessageId: beforeMessageId,
    promptId: "prompt-1",
    parts: parts,
    variant: null,
    fastMode: false,
    agent: null,
    model: null,
  );

  static Future<_AppServer> start({
    required ({int code, String message})? revertError,
    bool steeredRollout = false,
  }) async {
    final codexHome = Directory.systemTemp.createTempSync("codex-home-rewind-");
    addTearDown(() => codexHome.delete(recursive: true));
    final sessionDay = Directory(p.join(codexHome.path, "sessions", "2026", "11", "15"))..createSync(recursive: true);
    for (final file in Directory(_fixtureDay).listSync().whereType<File>()) {
      file.copySync(p.join(sessionDay.path, p.basename(file.path)));
    }
    if (steeredRollout) {
      File(p.join(sessionDay.path, "rollout-2026-11-15T13-00-00-$_steeredId.jsonl")).writeAsStringSync(_steeredLines);
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final methods = <String>[];
    final params = <String, Map<String, dynamic>>{};
    server.listen((request) async {
      final webSocket = await WebSocketTransformer.upgrade(request);
      webSocket.listen((frame) {
        final decoded = jsonDecode(frame as String) as Map<String, dynamic>;
        final method = decoded["method"] as String;
        methods.add(method);
        final requestParams = (decoded["params"] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        params[method] = requestParams;
        if (method == "thread/revert" && revertError != null) {
          webSocket.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": decoded["id"],
              "error": {"code": revertError.code, "message": revertError.message},
            }),
          );
          return;
        }
        if (method == "thread/revert" && requestParams["threadId"] == _sourceId) {
          _writeRevertRollout(sessionDay: sessionDay);
        }
        final Object result = switch (method) {
          "initialize" => const {"userAgent": "codex-cli/0.167.2"},
          "config/read" => const {"config": <String, Object?>{}},
          "thread/resume" => {
            "thread": {"id": requestParams["threadId"], "cwd": "/workspace/demo", "turns": const <Object>[]},
          },
          "turn/start" => const {
            "turn": {"id": "turn-edited"},
          },
          _ => const <String, Object?>{},
        };
        webSocket.add(jsonEncode({"jsonrpc": "2.0", "id": decoded["id"], "result": result}));
      });
    });
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:${server.port}",
      environment: {"CODEX_HOME": codexHome.path},
      projectCwd: "/workspace/demo",
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
      toolOutcomeRepository: createMemoryCodexToolOutcomeRepository(),
      runtimeExit: runningCodexRuntime,
    );
    addTearDown(plugin.dispose);
    await plugin.initialize();
    return _AppServer(plugin: plugin, methods: methods, params: params);
  }

  /// Keeps the original rollout's first turn, as `thread/revert {beforeTurnId:
  /// two}` does: a new rollout whose `history_base` is that turn's bytes.
  static void _writeRevertRollout({required Directory sessionDay}) {
    final lines = File(p.join(sessionDay.path, _originalRollout)).readAsLinesSync();
    final kept = lines.takeWhile((line) => !(line.contains('"task_started"') && line.contains(_turnTwo))).toList();
    final meta = {
      "timestamp": "2026-11-15T20:40:00.000Z",
      "type": "session_meta",
      "payload": {
        "id": _sourceId,
        "timestamp": "2026-11-15T20:40:00.000Z",
        "cwd": "/workspace/demo",
        "history_mode": "paginated",
        "history_base": {
          "thread_id": _sourceId,
          "end_ordinal_exclusive": kept.length,
          "end_byte_offset": utf8.encode(kept.map((line) => "$line\n").join()).length,
        },
      },
    };
    File(
      p.join(sessionDay.path, "rollout-2026-11-15T12-40-00-${_sourceId}_01a1e0f0-0000-7000-8000-00000000000a.jsonl"),
    ).writeAsStringSync("${jsonEncode(meta)}\n");
  }
}

/// A thread whose second turn opens with "user-opening" and has
/// "user-steered" steered in after commentary.
final String _steeredLines = [
  {
    "timestamp": "2026-11-15T21:00:00.000Z",
    "type": "session_meta",
    "payload": {"id": _steeredId, "timestamp": "2026-11-15T21:00:00.000Z", "cwd": "/workspace/demo"},
  },
  ..._turn(turnId: "turn-1", userItems: ["user-first"]),
  ..._turn(turnId: "turn-2", userItems: ["user-opening", "user-steered"]),
].map((line) => "${jsonEncode(line)}\n").join();

List<Map<String, Object?>> _turn({required String turnId, required List<String> userItems}) => [
  {
    "timestamp": "2026-11-15T21:00:01.000Z",
    "type": "event_msg",
    "payload": {"type": "task_started", "turn_id": turnId},
  },
  for (final id in userItems) ...[
    {
      "timestamp": "2026-11-15T21:00:02.000Z",
      "type": "response_item",
      "payload": {
        "type": "message",
        "id": "msg_$id",
        "role": "user",
        "content": [
          {"type": "input_text", "text": "prompt $id"},
        ],
      },
    },
    {
      "timestamp": "2026-11-15T21:00:02.000Z",
      "type": "event_msg",
      "payload": {
        "type": "item_completed",
        "thread_id": _steeredId,
        "turn_id": turnId,
        "item": {"type": "UserMessage", "id": id},
        "started_at_ms": null,
        "completed_at_ms": null,
      },
    },
    {
      "timestamp": "2026-11-15T21:00:03.000Z",
      "type": "response_item",
      "payload": {
        "type": "message",
        "id": "msg_reply_$id",
        "role": "assistant",
        "content": [
          {"type": "output_text", "text": "commentary"},
        ],
      },
    },
  ],
  {
    "timestamp": "2026-11-15T21:00:04.000Z",
    "type": "event_msg",
    "payload": {"type": "task_complete", "turn_id": turnId, "error": null},
  },
];
