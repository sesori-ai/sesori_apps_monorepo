import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";
import "support/fake_sesori_mcp_access.dart";

/// The 0.167.2 rollouts of `codex_revert_fork_history_test.dart`: the source
/// thread answered "one", "two", "three", was reverted before "three" and
/// answered "four", so its current history is "one", "two", "four".
const _fixtureDay = "test/fixtures/codex_revert_fork/sessions/2026/11/15";
const _sourceId = "01a1e0e9-81f9-7b81-81c6-a835c1d98756";
const _originalRollout = "rollout-2026-11-15T12-32-41-$_sourceId.jsonl";
const _userItemTwo = "01a1e0e9-8709-7a71-b289-6b15d15c677c";
const _turnOne = "01a1e0e9-8256-7362-a741-a53243e4d744";
const _turnTwo = "01a1e0e9-8704-78f0-9883-d16895f63c89";
const _replyOne = "msg_05d1ece2878d9bf5016afa16eb144087d0821be1548ac63907";
const _forkId = "01a1e0f0-0000-7000-8000-0000000000f0";

void main() {
  test("the descriptor declares rewind and fork and the plugin implements them", () {
    expect(
      const CodexPluginDescriptor(desktopAppCliCandidates: null).sessionBranching,
      {PluginSessionBranching.rewind, PluginSessionBranching.fork},
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
    expect(plugin, isA<SessionForkPluginApi>());
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

  group("fork", () {
    test("forks through the turn the message ends, leaving the source alone", () async {
      final server = await _AppServer.start(revertError: null);

      final fork = await server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _replyOne);

      expect(fork.id, _forkId);
      expect(fork.directory, "/workspace/demo");
      expect(fork.title, isNull);
      expect(server.methods, isNot(contains("thread/resume")));
      expect(server.paramsOf("thread/fork"), {
        "threadId": _sourceId,
        "lastTurnId": _turnOne,
        "developerInstructions": isA<String>(),
        "excludeTurns": true,
      });
      expect(await server.texts(sessionId: _forkId), ["Reply with exactly the word: one", "one"]);
      expect(await server.texts(sessionId: _sourceId), hasLength(6));
      final listed = await server.plugin.listAllSessions(knownDirectories: const {"/workspace/demo"});
      expect(listed.where((session) => session.id == _forkId), hasLength(1));
    });

    test("gives the fork its own Sesori MCP server, bound to the fork", () async {
      final sesoriMcp = FakeSesoriMcpAccess(enabled: true);
      final server = await _AppServer.start(revertError: null, sesoriMcp: sesoriMcp);

      await server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _replyOne);

      expect(server.paramsOf("thread/fork")?["config"], {
        "mcp_servers.sesori_bridge.url": "http://127.0.0.1:4100/mcp",
        "mcp_servers.sesori_bridge.http_headers": {"Authorization": "Bearer token-1"},
        "mcp_servers.sesori_bridge.default_tools_approval_mode": "approve",
      });
      expect(sesoriMcp.bound.single.backendSessionId, _forkId);
    });

    test("deleting the source archives the rollouts its forks keep, which still read", () async {
      final server = await _AppServer.start(revertError: null);
      await server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _replyOne);

      await server.plugin.deleteSession(_sourceId);

      expect(server.paramsOf("thread/archive"), {"threadId": _sourceId});
      expect(await server.texts(sessionId: _forkId), ["Reply with exactly the word: one", "one"]);
    });

    test("deleting a thread no fork builds on archives nothing", () async {
      final server = await _AppServer.start(revertError: null);

      // The recorded fork of the fixture source.
      await server.plugin.deleteSession("01a1e0e9-9887-72f3-a66b-5dc982bcbbd9");

      expect(server.methods, isNot(contains("thread/archive")));
    });

    test("a user message maps to its own turn", () async {
      final server = await _AppServer.start(revertError: null);

      await server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _userItemTwo);

      expect(server.paramsOf("thread/fork")?["lastTurnId"], _turnTwo);
    });

    test("an unknown message or session is refused before anything is created", () async {
      final server = await _AppServer.start(revertError: null);

      await expectLater(
        server.plugin.forkSession(sessionId: _sourceId, throughMessageId: "m-3"),
        throwsA(_refusal(reason: "Codex can't find this message to fork from it.")),
      );
      await expectLater(
        server.plugin.forkSession(sessionId: _steeredId, throughMessageId: "m-3"),
        throwsA(_refusal(reason: "Codex no longer has this session.")),
      );
      expect(server.methods, isNot(contains("thread/fork")));
    });

    test("a turn that went on after a steered follow-up is refused at the earlier reply", () async {
      final server = await _AppServer.start(revertError: null, steeredRollout: true);

      await expectLater(
        server.plugin.forkSession(sessionId: _steeredId, throughMessageId: "msg_reply_user-opening"),
        throwsA(
          _refusal(
            reason: "Codex can only fork at the end of a turn, and this turn went on after a later message.",
          ),
        ),
      );
      expect(server.methods, isNot(contains("thread/fork")));

      await server.plugin.forkSession(sessionId: _steeredId, throughMessageId: "msg_reply_user-steered");
      expect(server.paramsOf("thread/fork")?["lastTurnId"], "turn-2");
    });

    test("a runtime that ignores lastTurnId is refused without a request", () async {
      final server = await _AppServer.start(revertError: null, userAgent: "codex-cli/0.142.0 (Mac OS 15.0; arm64)");

      await expectLater(
        server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _replyOne),
        throwsA(_refusal(reason: "Update Codex to fork sessions.")),
      );
      expect(server.methods, isNot(contains("thread/fork")));
    });

    test("an old runtime is the reason even for a message the turn lookup can't place", () async {
      // 0.139.0 rollouts keep no item ids, so replay names its messages
      // `m-N`, which no turn holds.
      final server = await _AppServer.start(revertError: null, userAgent: "codex-cli/0.139.0 (Mac OS 15.0; arm64)");

      await expectLater(
        server.plugin.forkSession(sessionId: _sourceId, throughMessageId: "m-3"),
        throwsA(_refusal(reason: "Update Codex to fork sessions.")),
      );
      expect(server.methods, isNot(contains("thread/fork")));
    });

    for (final (:message, :reason) in const [
      (
        message: "lastTurnId '$_turnOne' identifies an in-progress turn",
        reason: "Codex can't fork from a turn that is still running.",
      ),
      (message: "turn not found: $_turnOne", reason: "Codex can't find this message to fork from it."),
      (message: "no rollout found for thread id $_sourceId", reason: "Codex no longer has this session."),
    ]) {
      test("thread/fork answering '$message' is refused", () async {
        final server = await _AppServer.start(revertError: null, forkError: (code: -32600, message: message));

        await expectLater(
          server.plugin.forkSession(sessionId: _sourceId, throughMessageId: _replyOne),
          throwsA(_refusal(reason: reason)),
        );
      });
    }
  });
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

  Future<List<String>> texts({required String sessionId}) async => [
    for (final message in await plugin.getSessionMessages(sessionId))
      for (final part in message.parts)
        if (part case PluginMessagePartText(:final text)) text,
  ];

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
    ({int code, String message})? forkError,
    String userAgent = "codex-cli/0.167.2",
    bool steeredRollout = false,
    SesoriMcpAccess? sesoriMcp,
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
        final error = switch (method) {
          "thread/revert" => revertError,
          "thread/fork" => forkError,
          _ => null,
        };
        if (error != null) {
          webSocket.add(
            jsonEncode({
              "jsonrpc": "2.0",
              "id": decoded["id"],
              "error": {"code": error.code, "message": error.message},
            }),
          );
          return;
        }
        if (method == "thread/fork" && requestParams["lastTurnId"] == _turnOne) {
          _writeForkRollout(sessionDay: sessionDay);
        }
        if (method == "thread/revert" && requestParams["threadId"] == _sourceId) {
          _writeRevertRollout(sessionDay: sessionDay);
        }
        final Object result = switch (method) {
          "initialize" => {"userAgent": userAgent},
          "config/read" => const {"config": <String, Object?>{}},
          "thread/resume" => {
            "thread": {"id": requestParams["threadId"], "cwd": "/workspace/demo", "turns": const <Object>[]},
          },
          "thread/fork" => const {
            "thread": {"id": _forkId, "cwd": "/workspace/demo", "turns": <Object>[]},
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
      sesoriMcp: sesoriMcp,
    );
    addTearDown(plugin.dispose);
    await plugin.initialize();
    return _AppServer(plugin: plugin, methods: methods, params: params);
  }

  /// Keeps the original rollout's first turn, as `thread/revert {beforeTurnId:
  /// two}` does: a new rollout whose `history_base` is that turn's bytes.
  static void _writeRevertRollout({required Directory sessionDay}) => _writeTurnOneRollout(
    sessionDay: sessionDay,
    id: _sourceId,
    fileName: "rollout-2026-11-15T12-40-00-${_sourceId}_01a1e0f0-0000-7000-8000-00000000000a.jsonl",
  );

  /// The rollout `thread/fork {lastTurnId: one}` writes: a new thread whose
  /// `history_base` is the source's first turn.
  static void _writeForkRollout({required Directory sessionDay}) => _writeTurnOneRollout(
    sessionDay: sessionDay,
    id: _forkId,
    fileName: "rollout-2026-11-15T12-50-00-$_forkId.jsonl",
  );

  static void _writeTurnOneRollout({required Directory sessionDay, required String id, required String fileName}) {
    final lines = File(p.join(sessionDay.path, _originalRollout)).readAsLinesSync();
    final kept = lines.takeWhile((line) => !(line.contains('"task_started"') && line.contains(_turnTwo))).toList();
    final meta = {
      "timestamp": "2026-11-15T20:40:00.000Z",
      "type": "session_meta",
      "payload": {
        "id": id,
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
    File(p.join(sessionDay.path, fileName)).writeAsStringSync("${jsonEncode(meta)}\n");
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
