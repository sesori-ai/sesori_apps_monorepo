import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "11111111-2222-4333-8444-555555555555";
const _timestamp = "2026-09-25T10:00:00Z";

/// A short synthetic envelope in the CLI's shape.
String _envelope({required String toolUseId}) =>
    "<task-notification>\n<task-id>task-1</task-id>\n<tool-use-id>$toolUseId</tool-use-id>\n"
    "<status>completed</status>\n<summary>Synthetic task finished</summary>\n"
    "<result>Synthetic result</result>\n</task-notification>";

/// A command queued mid-turn is persisted as a `queued_command` attachment but
/// shown live as a replayed user frame; both must map to the same message.
void main() {
  late Directory temp;
  late ClaudeEventDispatcher live;
  late ClaudeTranscriptCatalogRepository transcripts;
  const history = ClaudeHistoryMapper(content: ClaudeContentMapper());

  setUp(() {
    temp = Directory.systemTemp.createTempSync("claude-queued-command-");
    transcripts = ClaudeTranscriptCatalogRepository(
      transcriptApi: ClaudeTranscriptApi(environment: {"CLAUDE_CONFIG_DIR": temp.path}),
    );
    live = ClaudeEventDispatcher(
      content: const ClaudeContentMapper(),
      tools: ClaudeToolTracker(),
      catalogModelId: ({required apiModel}) => null,
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Every message the live path shows for [frames], in first-seen order.
  List<PluginMessageWithParts> mapLive({required List<Map<String, Object?>> frames}) {
    final infos = <String, PluginMessage>{};
    final parts = <String, Map<String, PluginMessagePart>>{};
    for (final frame in frames) {
      for (final event in live.map(message: ClaudeStreamMessage.parse(frame))) {
        if (event case BridgeSseMessageUpdated(:final info)) infos[info.id] = info;
        if (event case BridgeSseMessagePartUpdated(:final part)) (parts[part.messageID] ??= {})[part.id] = part;
      }
    }
    return [
      for (final info in infos.values) PluginMessageWithParts(info: info, parts: [...?parts[info.id]?.values]),
    ];
  }

  Future<List<PluginMessageWithParts>> replay({required List<Map<String, Object?>> records}) async {
    final project = Directory(p.join(temp.path, "projects", "fixture"))..createSync(recursive: true);
    File(p.join(project.path, "$_sessionId.jsonl")).writeAsStringSync(records.map(jsonEncode).join("\n"));
    return history.map(
      sessionId: _sessionId,
      agentId: null,
      records: await transcripts.readTranscriptRecordsInIsolate(sessionId: _sessionId),
      residentTaskToolUseIds: const {},
      catalogModelId: null,
    );
  }

  /// A turn whose Bash step is still running when [queued] arrives.
  List<Map<String, Object?>> turn({required Map<String, Object?> queued}) => [
    _user(uuid: "prompt", content: "Synthetic prompt"),
    _assistant(
      id: "msg-bash",
      content: [
        {
          "type": "tool_use",
          "id": "toolu-bash",
          "name": "Bash",
          "input": {"command": "sleep 1"},
        },
      ],
    ),
    _toolResult(toolUseId: "toolu-bash", launched: null),
    queued,
    _assistant(
      id: "msg-final",
      content: [
        {"type": "text", "text": "Synthetic answer"},
      ],
    ),
  ];

  /// The queued command [id] is the same message, at the same place, live and
  /// after replay.
  Future<PluginMessageWithParts> expectParity({
    required Map<String, Object?> echo,
    required Map<String, Object?> attachment,
    required String id,
  }) async {
    final shown = mapLive(frames: turn(queued: echo));
    final stored = await replay(records: turn(queued: attachment));
    expect(stored.map((message) => message.info.id), ["prompt", "msg-bash", id, "msg-final"]);
    expect(shown.map((message) => message.info.id), ["prompt", "msg-bash", id, "msg-final"]);
    final liveMessage = shown[2];
    final storedMessage = stored[2];
    expect(storedMessage.info.toJson(), liveMessage.info.toJson());
    expect(storedMessage.parts, liveMessage.parts);
    return storedMessage;
  }

  test("a follow-up sent mid-turn keeps its live id, text and place", () async {
    const text = "Synthetic follow-up";
    final stored = await expectParity(
      echo: _echo(uuid: "source", content: text, origin: null),
      attachment: _queued(
        uuid: "attachment",
        sourceUuid: "source",
        prompt: text,
        commandMode: "prompt",
        origin: null,
        isMeta: null,
        isSidechain: false,
      ),
      id: "source",
    );
    expect(stored.info, isA<PluginMessageUser>());
    expect(stored.parts.single.text, text);
  });

  test("an older CLI's follow-up without a source id keeps the record id", () async {
    const content = [
      {"type": "text", "text": "Synthetic follow-up"},
      {
        "type": "image",
        "source": {"type": "base64", "media_type": "image/png", "data": "AA=="},
      },
    ];
    final stored = await expectParity(
      echo: _echo(uuid: "attachment", content: content, origin: null),
      attachment: _queued(
        uuid: "attachment",
        sourceUuid: null,
        prompt: content,
        commandMode: "prompt",
        origin: null,
        isMeta: null,
        isSidechain: false,
      ),
      id: "attachment",
    );
    expect(stored.info, isA<PluginMessageUser>());
    expect(stored.parts.map((part) => part.type), [PluginMessagePartType.text, PluginMessagePartType.file]);
  });

  test("a queued peer message stays Automation", () async {
    const text = "Another Claude session sent a message:\nSynthetic report.";
    const origin = {"kind": "peer", "from": "unknown"};
    final stored = await expectParity(
      echo: _echo(uuid: "source", content: text, origin: origin),
      attachment: _queued(
        uuid: "attachment",
        sourceUuid: "source",
        prompt: text,
        commandMode: "prompt",
        origin: origin,
        isMeta: true,
        isSidechain: false,
      ),
      id: "source",
    );
    expect((stored.info as PluginMessageAssistant).sender, PluginMessageSender.system);
    expect(stored.parts.single.text, text);
  });

  test("a queued task outcome without origin becomes the same Automation step", () async {
    final envelope = _envelope(toolUseId: "toolu-unknown");
    final stored = await expectParity(
      // The live frame carries an origin; the attachment only its command mode.
      echo: _echo(uuid: "source", content: envelope, origin: {"kind": "task-notification"}),
      attachment: _queued(
        uuid: "attachment",
        sourceUuid: "source",
        prompt: envelope,
        commandMode: "task-notification",
        origin: null,
        isMeta: null,
        isSidechain: false,
      ),
      id: "source",
    );
    expect((stored.info as PluginMessageAssistant).sender, PluginMessageSender.system);
    expect((stored.parts.single as PluginMessagePartTool).state.output, "Synthetic result");
    final queued = transcripts
        .readTranscriptRecords(sessionId: _sessionId)
        .whereType<ClaudeTranscriptQueuedCommandRecord>();
    expect(queued.single.originKind, ClaudeMessageOriginKind.taskNotification);
  });

  test("a queued task outcome folds into its known task", () async {
    List<Map<String, Object?>> frames({required Map<String, Object?> queued}) => [
      _user(uuid: "prompt", content: "Synthetic prompt"),
      _assistant(
        id: "msg-agent",
        content: [
          {
            "type": "tool_use",
            "id": "toolu-agent",
            "name": "Agent",
            "input": {"description": "Synthetic", "prompt": "Synthetic task", "subagent_type": "general-purpose"},
          },
        ],
      ),
      _toolResult(
        toolUseId: "toolu-agent",
        launched: const {"isAsync": true, "status": "async_launched", "agentId": "task-1"},
      ),
      queued,
    ];
    final envelope = _envelope(toolUseId: "toolu-agent");
    final shown = mapLive(
      frames: frames(
        queued: _echo(uuid: "source", content: envelope, origin: {"kind": "task-notification"}),
      ),
    );
    final stored = await replay(
      records: frames(
        queued: _queued(
          uuid: "attachment",
          sourceUuid: "source",
          prompt: envelope,
          commandMode: "task-notification",
          origin: null,
          isMeta: null,
          isSidechain: false,
        ),
      ),
    );
    expect(stored.map((message) => message.info.id), ["prompt", "msg-agent"]);
    expect(shown.map((message) => message.info.id), ["prompt", "msg-agent"]);
    final liveTask = shown[1].parts.single as PluginMessagePartSubtask;
    final storedTask = stored[1].parts.single as PluginMessagePartSubtask;
    expect(storedTask.taskState?.status, PluginToolStatus.completed);
    expect(storedTask.taskState?.status, liveTask.taskState?.status);
    expect(storedTask.taskState?.output, liveTask.taskState?.output);
  });

  test("coordinator, sidechain and other sessions' queued commands stay hidden", () async {
    Map<String, Object?> queued({required String uuid, required Object? origin, required bool isSidechain}) => _queued(
      uuid: uuid,
      sourceUuid: null,
      prompt: "Synthetic instruction",
      commandMode: origin == null ? "prompt" : null,
      origin: origin,
      isMeta: origin == null ? null : true,
      isSidechain: isSidechain,
    );
    final stored = await replay(
      records: [
        queued(uuid: "coordinator", origin: {"kind": "coordinator"}, isSidechain: false),
        queued(uuid: "sidechain", origin: null, isSidechain: true),
        {...queued(uuid: "other-session", origin: null, isSidechain: false), "sessionId": "different-session"},
      ],
    );
    expect(stored, isEmpty);
  });
}

/// A user frame that doubles as its transcript record.
Map<String, Object?> _user({required String uuid, required String content}) => {
  "type": "user",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": uuid,
  "timestamp": _timestamp,
  "message": {"role": "user", "content": content},
};

Map<String, Object?> _assistant({required String id, required List<Map<String, Object?>> content}) => {
  "type": "assistant",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "record-$id",
  "timestamp": _timestamp,
  "message": {"id": id, "model": "claude-opus-5", "content": content},
};

/// A tool result carrying [launched] as an async agent's typed result under
/// both the stream's and the transcript's key.
Map<String, Object?> _toolResult({required String toolUseId, required Map<String, Object?>? launched}) => {
  "type": "user",
  "session_id": _sessionId,
  "sessionId": _sessionId,
  "uuid": "result-$toolUseId",
  "timestamp": _timestamp,
  "message": {
    "role": "user",
    "content": [
      {"type": "tool_result", "tool_use_id": toolUseId, "content": "Synthetic output"},
    ],
  },
  "tool_use_result": ?launched,
  "toolUseResult": ?launched,
};

/// The replayed user frame the live stream shows for a queued command.
Map<String, Object?> _echo({required String uuid, required Object? content, required Object? origin}) => {
  "type": "user",
  "session_id": _sessionId,
  "uuid": uuid,
  "timestamp": _timestamp,
  "isReplay": true,
  "origin": origin,
  "message": {"role": "user", "content": content},
};

/// The `queued_command` attachment Claude persists for that command.
Map<String, Object?> _queued({
  required String uuid,
  required String? sourceUuid,
  required Object? prompt,
  required String? commandMode,
  required Object? origin,
  required bool? isMeta,
  required bool isSidechain,
}) => {
  "type": "attachment",
  "sessionId": _sessionId,
  "uuid": uuid,
  "timestamp": _timestamp,
  "isSidechain": isSidechain,
  "attachment": {
    "type": "queued_command",
    "prompt": prompt,
    "commandMode": ?commandMode,
    "source_uuid": ?sourceUuid,
    "origin": ?origin,
    "isMeta": ?isMeta,
    "timestamp": _timestamp,
  },
};
